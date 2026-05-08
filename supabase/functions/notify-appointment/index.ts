// ============================================================
// Outfitly Edge Function — notify-appointment
// ------------------------------------------------------------
// Fan-out a push to the right party when a row in
// `tailor_appointments` lands or transitions.
//
// Audience by event:
//
//   * INSERT status='pending' (legacy broadcast booking) →
//     every ONLINE tailor (app='tailor', user_id IS NULL filter
//     in fetchTokens means "all rows that match the app").
//   * INSERT status='pending_tailor_approval' (marketplace
//     direct request) → only the chosen tailor (record.tailor_id).
//   * UPDATE pending → accepted → push CUSTOMER.
//   * UPDATE → en_route, arrived, completed → push CUSTOMER.
//   * UPDATE accepted → cancelled → push the assigned TAILOR
//     (so they stop heading over). pending → cancelled has no
//     audience (broadcast was never claimed).
//
// Auth: FCM HTTP v1 via service-account JWT. See
// supabase/functions/_shared/fcm.ts. FCM_SERVICE_ACCOUNT must
// be set as a Supabase secret to deliver; without it the
// function logs and returns 200 (scaffold mode).
// ============================================================

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

import {
  mintAccessToken,
  readServiceAccount,
  sendFcmMessage,
} from '../_shared/fcm.ts';
import { recordNotifications } from '../_shared/notifications.ts';

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  table: string;
  record: Record<string, unknown>;
  old_record: Record<string, unknown> | null;
  schema: string;
}

interface AppointmentRow {
  id: string;
  user_id: string;
  tailor_id: string | null;
  status: string;
  address: string;
  scheduled_time: string;
}

interface DeviceTokenRow {
  token: string;
}

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(supabaseUrl, serviceRoleKey);

serve(async (req) => {
  const payload = (await req.json()) as WebhookPayload;
  if (payload.table !== 'tailor_appointments') {
    return new Response('ignored', { status: 200 });
  }

  const record = payload.record as unknown as AppointmentRow;
  const oldRecord = payload.old_record as unknown as AppointmentRow | null;

  const plan = resolvePushPlan(payload.type, record, oldRecord);
  if (!plan) {
    return new Response('no push for this transition', { status: 200 });
  }

  const tokens = await fetchTokens(plan.audience);
  if (tokens.length === 0) {
    console.log(
      `[notify-appointment] no tokens for ${JSON.stringify(plan.audience)}`,
    );
    return new Response('no tokens', { status: 200 });
  }

  // In-app feed: only the customer app has a notifications
  // table today (migration 043 + the bell icon). Tailor-side
  // pushes still send via FCM but get NO feed row — the Partner
  // app doesn't have a feed surface to render them yet.
  let feedInserted = 0;
  if (plan.audience.app === 'customer' && plan.audience.userId !== null) {
    const result = await recordNotifications(supabase, [
      {
        userId: plan.audience.userId,
        title: plan.title,
        body: plan.body,
        type: 'appointment',
        route: `/tailor-visit/${record.id}`,
        data: {
          appointment_id: record.id,
          status: record.status,
        },
      },
    ]);
    feedInserted = result.inserted;
    console.log(
      `[notify-appointment] feed rows inserted=${result.inserted} failed=${result.failed}`,
    );
  }

  console.log(
    `[notify-appointment] ${tokens.length} push(es) → app=${plan.audience.app} user=${plan.audience.userId ?? 'broadcast'}: ${plan.title}`,
  );

  const sa = readServiceAccount();
  if (!sa) {
    console.log(
      '[notify-appointment] FCM_SERVICE_ACCOUNT not set — scaffold no-op',
    );
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
      notification: { title: plan.title, body: plan.body },
      data: {
        appointment_id: record.id,
        status: record.status,
        // Customer-directed pushes deep-link into the live
        // tracker; tailor-directed pushes drop the route so
        // the Partner app stays on its radar/active job
        // surface (it has its own router and doesn't share
        // /tailor-visit/:id with the customer app anyway).
        ...(plan.audience.app === 'customer'
          ? { route: `/tailor-visit/${record.id}` }
          : {}),
      },
      collapseKey: `appt:${record.id}`,
    });
    if (r.ok) okCount++;
    else {
      failCount++;
      console.warn(
        `[notify-appointment] FCM ${r.status} for token ${t.token.slice(0, 12)}…: ${r.body}`,
      );
    }
  }

  console.log(
    `[notify-appointment] done. delivered=${okCount} failed=${failCount}`,
  );
  return new Response(
    JSON.stringify({
      delivered: okCount,
      failed: failCount,
      feed_rows: feedInserted,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});

// ────────────────────────────────────────────────────────────
// Transition → audience + copy
// ────────────────────────────────────────────────────────────
interface PushPlan {
  audience: { userId: string | null; app: 'customer' | 'tailor' };
  title: string;
  body: string;
}

function resolvePushPlan(
  event: WebhookPayload['type'],
  record: AppointmentRow,
  oldRecord: AppointmentRow | null,
): PushPlan | null {
  // INSERT branches — two booking modes:
  if (event === 'INSERT') {
    // Legacy broadcast — fan out to every online tailor.
    if (record.status === 'pending' && record.tailor_id === null) {
      return {
        audience: { userId: null, app: 'tailor' },
        title: 'New dispatch request',
        body: `Tailoring visit at ${record.address}`,
      };
    }
    // Marketplace direct — only the chosen tailor sees this.
    if (
      record.status === 'pending_tailor_approval' &&
      record.tailor_id !== null
    ) {
      return {
        audience: { userId: record.tailor_id, app: 'tailor' },
        title: 'You\'ve been selected',
        body: `A customer hand-picked you for a visit at ${record.address}.`,
      };
    }
    return null;
  }

  if (event !== 'UPDATE' || oldRecord === null) return null;
  if (oldRecord.status === record.status) return null;

  // Customer-directed transitions.
  switch (record.status) {
    case 'accepted':
      return {
        audience: { userId: record.user_id, app: 'customer' },
        title: 'Your tailor accepted',
        body: "They'll head out to you shortly.",
      };
    case 'en_route':
      return {
        audience: { userId: record.user_id, app: 'customer' },
        title: 'Your tailor is on the way',
        body: 'Keep an eye on the tracking screen.',
      };
    case 'arrived':
      return {
        audience: { userId: record.user_id, app: 'customer' },
        title: 'Your tailor is at the door',
        body: 'Ready whenever you are.',
      };
    case 'completed':
      return {
        audience: { userId: record.user_id, app: 'customer' },
        title: 'Measurements complete',
        body: 'Saved to your profile.',
      };
    case 'cancelled':
      // pending → cancelled has nobody to notify on the
      // Partner side (broadcast was never claimed). Same for
      // pending_tailor_approval if we never accepted. Only
      // ping the tailor if they were already in motion.
      if (
        oldRecord.status === 'pending' ||
        oldRecord.status === 'pending_tailor_approval'
      ) {
        return null;
      }
      return {
        audience: { userId: record.tailor_id, app: 'tailor' },
        title: 'Visit cancelled',
        body: 'The customer cancelled — you can head back.',
      };
  }

  return null;
}

async function fetchTokens(
  audience: PushPlan['audience'],
): Promise<DeviceTokenRow[]> {
  let q = supabase
    .from('device_tokens')
    .select('token')
    .eq('app', audience.app);

  if (audience.userId !== null) {
    q = q.eq('user_id', audience.userId);
  }

  const { data, error } = await q;
  if (error) {
    console.error('[notify-appointment] token fetch failed', error);
    return [];
  }
  return (data ?? []) as DeviceTokenRow[];
}
