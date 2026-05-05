// ============================================================
// Outfitly Edge Function — notify-promo
// ------------------------------------------------------------
// Fan-out a marketing push to every customer device whenever a
// new promo_offers row lands as `is_active = true`. Mirrors the
// pattern from notify-appointment / notify-borrow so a single
// FCM_SERVER_KEY rollout flips all three live.
//
// Trigger: a Supabase Database Webhook on `public.promo_offers`
// for INSERT and UPDATE events. The function decides whether the
// transition warrants a push (newly-active and not yet expired)
// and bails on the rest.
//
// Audience: every row in `device_tokens` where `app = 'customer'`.
// Marketing pushes are deliberately broadcast to ALL customers,
// not scoped to a user — every signed-in customer should get the
// chance to act on a sale.
//
// Deep link: the FCM `data` payload carries `route: '/offers'`,
// which the customer app's PushNotificationService routes to the
// Offers dashboard on tap (cold start, background, or foreground
// — all three flows share the same routing decision).
//
// SCAFFOLD: real delivery is gated on FCM_SERVER_KEY. Without it
// we log the audience size + return 200 so the webhook stays
// healthy; the moment you set the secret, the same fetch path
// goes live with no code change.
//
// To go live:
//   1. Create a Firebase project (or reuse an existing one).
//   2. Cloud Messaging API key →
//      `supabase secrets set FCM_SERVER_KEY=<key>`
//   3. `supabase functions deploy notify-promo`
//   4. Wire a Database Webhook on promo_offers (INSERT + UPDATE)
//      → this function.
// ============================================================

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

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

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const fcmServerKey = Deno.env.get('FCM_SERVER_KEY') ?? '';

const supabase = createClient(supabaseUrl, serviceRoleKey);

serve(async (req) => {
  const payload = (await req.json()) as WebhookPayload;

  if (payload.table !== 'promo_offers') {
    return new Response('ignored', { status: 200 });
  }

  const record = payload.record as unknown as PromoRow;
  const oldRecord = payload.old_record as unknown as PromoRow | null;

  // We only push on rows that have just become live: a fresh
  // INSERT with is_active=true, or an UPDATE that flips the
  // is_active flag from false → true. Anything else (deactivate,
  // edit-while-active, expire) silently skips.
  const wasActive = oldRecord?.is_active === true;
  const isActive = record.is_active === true;
  const isNewlyActive =
    payload.type === 'INSERT'
      ? isActive
      : payload.type === 'UPDATE' && !wasActive && isActive;

  if (!isNewlyActive) {
    return new Response('not a launch event', { status: 200 });
  }

  // Defend against pushing an already-expired campaign — guard
  // because the marketing team might publish a row whose
  // end_date is in the past while testing.
  if (new Date(record.end_date) < new Date()) {
    return new Response('end_date already passed', { status: 200 });
  }

  // Pull every customer device token. We don't filter by user
  // here — marketing pushes go to everyone with the customer
  // app installed.
  const tokens = await fetchAllCustomerTokens();
  if (tokens.length === 0) {
    console.log('[notify-promo] no device tokens — nothing to send');
    return new Response('no tokens', { status: 200 });
  }

  const title = `${record.discount_percentage}% off — ${record.title}`;
  const body = record.description?.trim() ||
    'Tap to see today\'s active offers.';
  const collapseKey = `promo:${record.id}`;

  console.log(
    `[notify-promo] firing ${tokens.length} push(es): ${title}`,
  );

  if (!fcmServerKey) {
    console.log('[notify-promo] FCM_SERVER_KEY not set — scaffold no-op');
    return new Response('scaffold no-op', { status: 200 });
  }

  // FCM accepts up to 1000 registration tokens per multicast,
  // but the legacy /fcm/send endpoint only takes one token at a
  // time. We loop here for simplicity; fan-out cardinality at
  // launch is tiny so the latency is fine. When we move to FCM
  // HTTP v1, switch to the multicast send.
  for (const t of tokens) {
    try {
      const res = await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          'Authorization': `key=${fcmServerKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          to: t.token,
          notification: { title, body },
          data: {
            promo_id: record.id,
            promo_code: record.promo_code ?? '',
            // The customer-app push handler reads `route` and
            // pushes via GoRouter — '/offers' lands the user on
            // the Active Offers dashboard with the new row at
            // the top of the list.
            route: '/offers',
          },
          // Same-row repeats collapse so a quick edit doesn't
          // spam two banners on top of each other.
          collapse_key: collapseKey,
        }),
      });
      if (!res.ok) {
        console.warn(
          `[notify-promo] FCM ${res.status}: ${await res.text()}`,
        );
      }
    } catch (e) {
      console.error('[notify-promo] FCM call failed', e);
    }
  }

  return new Response('ok', { status: 200 });
});

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
