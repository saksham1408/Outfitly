// ============================================================
// Outfitly Edge Function — notify-promo
// ------------------------------------------------------------
// Fan-out a marketing push to every customer device whenever a
// new `promo_offers` row lands as `is_active = true`.
//
// Trigger: Database Webhook on `public.promo_offers` for INSERT
// and UPDATE events. The function bails on transitions that
// aren't a fresh launch (deactivate, edit-while-active, expire).
//
// Auth model: FCM HTTP v1 (the legacy `/fcm/send` endpoint was
// shut down June 2024). We sign a JWT with the Firebase service
// account JSON, exchange it for an OAuth access token at
// oauth2.googleapis.com/token, and POST to
// fcm.googleapis.com/v1/projects/<id>/messages:send with that
// token in the Authorization header.
//
// Required Supabase secrets:
//   * FCM_SERVICE_ACCOUNT — the entire service-account JSON
//     downloaded from Firebase Console → Project Settings →
//     Service Accounts → Generate new private key. Paste the
//     full JSON (one-line or pretty-printed both work).
//
// SCAFFOLD fallback: if FCM_SERVICE_ACCOUNT is unset, the
// function logs the would-be audience size and returns 200 so
// the webhook stays healthy until the secret is wired.
//
// Audience: every row in `device_tokens` where `app = 'customer'`.
// Marketing pushes broadcast to all signed-in customers.
//
// Deep link: `data.route = '/offers'` — the customer app's
// PushNotificationService routes to the Active Offers dashboard
// on tap (cold start, background, or foreground).
// ============================================================

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import {
  SignJWT,
  importPKCS8,
} from 'https://deno.land/x/jose@v5.9.6/index.ts';

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  table: string;
  record: Record<string, unknown>;
  old_record: Record<string, unknown> | null;
  schema: string;
}

interface PromoRow {
  id: string;
  title: string;
  description: string | null;
  discount_percentage: number;
  end_date: string;
  is_active: boolean;
  promo_code: string | null;
}

interface DeviceTokenRow {
  token: string;
  platform: 'ios' | 'android' | 'web';
}

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(supabaseUrl, serviceRoleKey);

// Cache the OAuth access token for the lifetime of the warm
// container — Google issues 1-hour tokens and re-minting on every
// invocation costs an extra round-trip we don't need. We refresh
// 5 minutes before expiry to defend against clock drift.
let cachedToken: { value: string; expiresAt: number } | null = null;

serve(async (req) => {
  const payload = (await req.json()) as WebhookPayload;

  if (payload.table !== 'promo_offers') {
    return new Response('ignored', { status: 200 });
  }

  const record = payload.record as unknown as PromoRow;
  const oldRecord = payload.old_record as unknown as PromoRow | null;

  // Push only on a fresh launch — INSERT with is_active=true, or
  // UPDATE that flips false→true. Everything else (deactivate,
  // edit, expire) silently skips.
  const wasActive = oldRecord?.is_active === true;
  const isActive = record.is_active === true;
  const isNewlyActive =
    payload.type === 'INSERT'
      ? isActive
      : payload.type === 'UPDATE' && !wasActive && isActive;

  if (!isNewlyActive) {
    return new Response('not a launch event', { status: 200 });
  }

  if (new Date(record.end_date) < new Date()) {
    return new Response('end_date already passed', { status: 200 });
  }

  const tokens = await fetchAllCustomerTokens();
  if (tokens.length === 0) {
    console.log('[notify-promo] no device tokens — nothing to send');
    return new Response('no tokens', { status: 200 });
  }

  const title = `${record.discount_percentage}% off — ${record.title}`;
  const body =
    record.description?.trim() || "Tap to see today's active offers.";

  console.log(
    `[notify-promo] dispatching ${tokens.length} push(es): ${title}`,
  );

  // Pull the service account once. If it's missing we log the
  // would-be audience and bail with 200 so the webhook stays
  // healthy.
  const serviceAccountRaw = Deno.env.get('FCM_SERVICE_ACCOUNT');
  if (!serviceAccountRaw) {
    console.log(
      '[notify-promo] FCM_SERVICE_ACCOUNT not set — scaffold no-op',
    );
    return new Response('scaffold no-op', { status: 200 });
  }

  let serviceAccount: ServiceAccount;
  try {
    serviceAccount = JSON.parse(serviceAccountRaw);
  } catch (e) {
    console.error('[notify-promo] FCM_SERVICE_ACCOUNT is not valid JSON', e);
    return new Response('bad service account secret', { status: 200 });
  }

  const accessToken = await mintAccessToken(serviceAccount);
  if (!accessToken) {
    return new Response('could not mint FCM token', { status: 200 });
  }

  const fcmEndpoint =
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

  // FCM v1 doesn't have a multicast endpoint at this URL — we
  // POST per-token. Cardinality is small at MVP scale and the
  // for-loop keeps error handling per-message simple.
  let okCount = 0;
  let failCount = 0;
  for (const t of tokens) {
    try {
      const res = await fetch(fcmEndpoint, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: t.token,
            notification: { title, body },
            data: {
              promo_id: record.id,
              promo_code: record.promo_code ?? '',
              // Customer app's PushNotificationService reads
              // `data.route` and pushes via GoRouter on tap.
              route: '/offers',
            },
            // Same-row repeats collapse so a quick edit doesn't
            // spam two banners.
            android: {
              collapse_key: `promo:${record.id}`,
            },
            apns: {
              headers: {
                'apns-collapse-id': `promo:${record.id}`,
              },
            },
          },
        }),
      });

      if (res.ok) {
        okCount++;
      } else {
        failCount++;
        const errBody = await res.text();
        console.warn(
          `[notify-promo] FCM ${res.status} for token ${t.token.slice(0, 12)}…: ${errBody}`,
        );
      }
    } catch (e) {
      failCount++;
      console.error('[notify-promo] FCM call failed', e);
    }
  }

  console.log(
    `[notify-promo] done. delivered=${okCount} failed=${failCount}`,
  );

  return new Response(
    JSON.stringify({ delivered: okCount, failed: failCount }),
    {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    },
  );
});

// ────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────

async function fetchAllCustomerTokens(): Promise<DeviceTokenRow[]> {
  const { data, error } = await supabase
    .from('device_tokens')
    .select('token, platform')
    .eq('app', 'customer');
  if (error) {
    console.warn('[notify-promo] token fetch failed', error.message);
    return [];
  }
  return (data ?? []) as DeviceTokenRow[];
}

/// Mint a FCM-scoped OAuth access token from the service account.
/// We sign a JWT with the SA's private key, then POST it to
/// Google's token endpoint per the standard "two-legged OAuth"
/// flow. The issued access token is valid for 1 hour; we cache
/// for 55 minutes to leave a margin for clock drift.
async function mintAccessToken(
  sa: ServiceAccount,
): Promise<string | null> {
  const now = Date.now();
  if (cachedToken && cachedToken.expiresAt > now + 60_000) {
    return cachedToken.value;
  }

  try {
    const privateKey = await importPKCS8(sa.private_key, 'RS256');
    const jwt = await new SignJWT({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
    })
      .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
      .setIssuedAt()
      .setExpirationTime('1h')
      .sign(privateKey);

    const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    });

    if (!tokenRes.ok) {
      const errBody = await tokenRes.text();
      console.error(
        `[notify-promo] OAuth token mint failed (${tokenRes.status}): ${errBody}`,
      );
      return null;
    }

    const data = (await tokenRes.json()) as {
      access_token: string;
      expires_in: number;
    };

    cachedToken = {
      value: data.access_token,
      expiresAt: now + data.expires_in * 1000 - 5 * 60 * 1000,
    };

    return data.access_token;
  } catch (e) {
    console.error('[notify-promo] mintAccessToken failed', e);
    return null;
  }
}
