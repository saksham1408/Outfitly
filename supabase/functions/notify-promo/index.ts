// ============================================================
// Outfitly Edge Function — notify-promo
// ------------------------------------------------------------
// Marketing fan-out: when a `promo_offers` row lands as
// `is_active = true`, push every customer device.
//
// Trigger: Database Webhook on `public.promo_offers` (INSERT +
// UPDATE). Skips deactivate / edit / expire transitions; only
// fires on a fresh launch (false→true or new INSERT with
// is_active=true).
//
// Audience: every row in `device_tokens` where `app='customer'`
// — marketing pushes broadcast to all signed-in customers.
//
// Deep link: `data.route = '/offers'` so the customer app's
// PushNotificationService routes to the Active Offers
// dashboard on tap.
//
// Auth: FCM HTTP v1 via service-account JWT. See
// supabase/functions/_shared/fcm.ts for the helper.
// FCM_SERVICE_ACCOUNT must be set as a Supabase secret; if
// not, function logs and returns 200 (scaffold mode).
// ============================================================

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

import {
  mintAccessToken,
  readServiceAccount,
  sendFcmMessage,
} from '../_shared/fcm.ts';

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
}

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(supabaseUrl, serviceRoleKey);

serve(async (req) => {
  const payload = (await req.json()) as WebhookPayload;
  if (payload.table !== 'promo_offers') {
    return new Response('ignored', { status: 200 });
  }

  const record = payload.record as unknown as PromoRow;
  const oldRecord = payload.old_record as unknown as PromoRow | null;

  // Only fire on launches: fresh INSERT with is_active=true OR
  // UPDATE that flips false→true.
  const wasActive = oldRecord?.is_active === true;
  const isActive = record.is_active === true;
  const isLaunch =
    payload.type === 'INSERT'
      ? isActive
      : payload.type === 'UPDATE' && !wasActive && isActive;

  if (!isLaunch) {
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

  console.log(`[notify-promo] dispatching ${tokens.length} push(es): ${title}`);

  const sa = readServiceAccount();
  if (!sa) {
    console.log('[notify-promo] FCM_SERVICE_ACCOUNT not set — scaffold no-op');
    return new Response('scaffold no-op', { status: 200 });
  }

  const accessToken = await mintAccessToken(sa);
  if (!accessToken) {
    return new Response('could not mint FCM token', { status: 200 });
  }

  let okCount = 0;
  let failCount = 0;
  for (const t of tokens) {
    const r = await sendFcmMessage(sa, accessToken, {
      token: t.token,
      notification: { title, body },
      data: {
        promo_id: record.id,
        promo_code: record.promo_code ?? '',
        route: '/offers',
      },
      collapseKey: `promo:${record.id}`,
    });
    if (r.ok) okCount++;
    else {
      failCount++;
      console.warn(
        `[notify-promo] FCM ${r.status} for token ${t.token.slice(0, 12)}…: ${r.body}`,
      );
    }
  }

  console.log(
    `[notify-promo] done. delivered=${okCount} failed=${failCount}`,
  );
  return new Response(
    JSON.stringify({ delivered: okCount, failed: failCount }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});

async function fetchAllCustomerTokens(): Promise<DeviceTokenRow[]> {
  const { data, error } = await supabase
    .from('device_tokens')
    .select('token')
    .eq('app', 'customer');
  if (error) {
    console.warn('[notify-promo] token fetch failed', error.message);
    return [];
  }
  return (data ?? []) as DeviceTokenRow[];
}
