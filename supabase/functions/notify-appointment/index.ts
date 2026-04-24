// ============================================================
// Outfitly Edge Function — notify-appointment
// ------------------------------------------------------------
// Fans out a push notification to every device token registered
// for the parties affected by a tailor_appointments status
// change. Invoked from a Supabase Database Webhook wired to the
// `tailor_appointments` table (INSERT and UPDATE) — the webhook
// payload hands us old_record + record + event type and we
// decide who to ping and what to say.
//
// Who gets pinged, by event:
//
//   * INSERT (status='pending') — a new dispatch request —
//     every ONLINE tailor (app='tailor') in `device_tokens`.
//     Customer doesn't get a push yet; they see the "Finding a
//     tailor" card on the visit tracking screen.
//
//   * UPDATE status: 'pending' -> 'accepted' — the customer's
//     tokens (app='customer', user_id=row.user_id). Copy: "Your
//     tailor is on the way." (wording depends on the actual
//     transition; see _copyFor below.)
//
//   * UPDATE status: 'accepted' -> 'en_route' / 'en_route' ->
//     'arrived' / 'arrived' -> 'completed' — the customer's
//     tokens. Wording tracks the state so the screen and push
//     read as a single narrative.
//
//   * UPDATE status: 'pending' -> 'cancelled' — the single
//     accepted tailor's tokens (they need to stop heading over).
//
// This is a SCAFFOLD. The FCM call at the bottom is commented
// out because we need a `FCM_SERVER_KEY` secret set on the
// project before we can deliver — until then the function logs
// the intended send and returns 200 so the webhook doesn't
// retry.
//
// To go live:
//   1. Create a Firebase project + Cloud Messaging API key.
//   2. supabase secrets set FCM_SERVER_KEY=<key>
//   3. supabase functions deploy notify-appointment
//   4. Wire a Database Webhook on tailor_appointments → this fn.
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
  platform: 'ios' | 'android' | 'web';
}

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const fcmServerKey = Deno.env.get('FCM_SERVER_KEY') ?? '';

const supabase = createClient(supabaseUrl, serviceRoleKey);

serve(async (req) => {
  const payload = (await req.json()) as WebhookPayload;

  if (payload.table !== 'tailor_appointments') {
    return new Response('ignored', { status: 200 });
  }

  const record = payload.record as unknown as AppointmentRow;
  const oldRecord = payload.old_record as unknown as AppointmentRow | null;

  // Decide audience + copy from the transition.
  const plan = resolvePushPlan(payload.type, record, oldRecord);
  if (!plan) {
    return new Response('no push for this transition', { status: 200 });
  }

  // Look up the tokens.
  const tokens = await fetchTokens(plan.audience);
  if (tokens.length === 0) {
    console.log(`[notify] no tokens for audience: ${JSON.stringify(plan.audience)}`);
    return new Response('no tokens', { status: 200 });
  }

  console.log(`[notify] firing ${tokens.length} push(es): ${plan.title}`);

  // Real delivery — gated on the FCM server key being set. Until
  // the secret is configured we log-and-noop so the webhook chain
  // stays healthy.
  if (!fcmServerKey) {
    console.log('[notify] FCM_SERVER_KEY not set — scaffold no-op');
    return new Response('scaffold no-op', { status: 200 });
  }

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
          notification: {
            title: plan.title,
            body: plan.body,
          },
          data: {
            appointment_id: record.id,
            status: record.status,
          },
        }),
      });
      if (!res.ok) {
        console.warn(`[notify] FCM ${res.status}: ${await res.text()}`);
      }
    } catch (e) {
      console.error('[notify] FCM call failed', e);
    }
  }

  return new Response('ok', { status: 200 });
});

// ────────────────────────────────────────────────────────────
// Transition → (audience, title, body)
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
  if (event === 'INSERT' && record.status === 'pending') {
    // Broadcast to every online tailor — we represent "broadcast
    // across an app" by audience.userId === null, which
    // fetchTokens reads as "no user_id filter".
    return {
      audience: { userId: null, app: 'tailor' },
      title: 'New dispatch request',
      body: `Tailoring visit at ${record.address}`,
    };
  }

  if (event !== 'UPDATE' || oldRecord === null) return null;
  if (oldRecord.status === record.status) return null;

  // Customer-directed transitions.
  switch (record.status) {
    case 'accepted':
      return {
        audience: { userId: record.user_id, app: 'customer' },
        title: 'Your tailor accepted',
        body: 'They\'ll head out to you shortly.',
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
      // Only ping the tailor if this was an accepted visit they
      // were driving to — a pending cancellation has nobody to
      // notify on the Partner side.
      if (oldRecord.status === 'pending') return null;
      return {
        audience: {
          userId: record.tailor_id,
          app: 'tailor',
        },
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
    .select('token, platform')
    .eq('app', audience.app);

  if (audience.userId !== null) {
    q = q.eq('user_id', audience.userId);
  }

  const { data, error } = await q;
  if (error) {
    console.error('[notify] token fetch failed', error);
    return [];
  }
  return (data ?? []) as DeviceTokenRow[];
}
