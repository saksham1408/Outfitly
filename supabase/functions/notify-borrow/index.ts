// ============================================================
// Outfitly Edge Function — notify-borrow
// ------------------------------------------------------------
// Fans out a push notification to the right party when a row in
// `borrow_requests` is INSERTed or its status UPDATEs. Mirrors
// the structure of `notify-appointment` so a single FCM-key
// rollout flips both production live.
//
// Audience by event:
//
//   * INSERT (status='pending') — borrower asked owner to lend.
//     Push the OWNER (audience: customer app, user_id = owner_id).
//
//   * UPDATE 'pending' → 'approved' — owner said yes.
//     Push the BORROWER.
//
//   * UPDATE 'pending' → 'denied' — owner said no.
//     Push the BORROWER.
//
//   * UPDATE 'approved' → 'returned' — garment came back.
//     Push the OPPOSITE party from whoever marked it.
//     Without an audit column ("who marked it") we can't tell
//     definitively, so we ping both — same row, deduped on the
//     receiving end via the apns-collapse-id / fcm collapse_key.
//
//   * UPDATE 'pending' → 'cancelled' — borrower withdrew.
//     Push the OWNER (so they know the request went away).
//
// SCAFFOLD: real delivery is gated on FCM_SERVER_KEY. Without it
// we log and return 200 so the webhook stays healthy; once you
// set the secret, the same fetch path goes live.
//
// To go live:
//   1. Same Firebase Cloud Messaging key as notify-appointment
//      (one project, one server key).
//   2. supabase secrets set FCM_SERVER_KEY=<key>     (already
//      done if notify-appointment is live)
//   3. supabase functions deploy notify-borrow
//   4. Wire a Database Webhook on borrow_requests → this fn,
//      events: INSERT + UPDATE.
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

interface BorrowRow {
  id: string;
  borrower_id: string;
  owner_id: string;
  wardrobe_item_id: string;
  status: string;
  borrow_start: string;
  borrow_end: string;
  note: string | null;
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

  if (payload.table !== 'borrow_requests') {
    return new Response('ignored', { status: 200 });
  }

  const record = payload.record as unknown as BorrowRow;
  const oldRecord = payload.old_record as unknown as BorrowRow | null;

  const plans = resolvePushPlans(payload.type, record, oldRecord);
  if (plans.length === 0) {
    return new Response('no push for this transition', { status: 200 });
  }

  for (const plan of plans) {
    const tokens = await fetchTokens(plan.targetUserId);
    if (tokens.length === 0) {
      console.log(`[notify-borrow] no tokens for ${plan.targetUserId}`);
      continue;
    }
    console.log(
      `[notify-borrow] firing ${tokens.length} push(es) to ${plan.targetUserId}: ${plan.title}`,
    );

    if (!fcmServerKey) {
      console.log('[notify-borrow] FCM_SERVER_KEY not set — scaffold no-op');
      continue;
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
              borrow_request_id: record.id,
              status: record.status,
              wardrobe_item_id: record.wardrobe_item_id,
            },
            // Collapse same-row repeats so a quick approve→return
            // pair doesn't spam two banners on top of each other.
            collapse_key: `borrow:${record.id}`,
          }),
        });
        if (!res.ok) {
          console.warn(
            `[notify-borrow] FCM ${res.status}: ${await res.text()}`,
          );
        }
      } catch (e) {
        console.error('[notify-borrow] FCM call failed', e);
      }
    }
  }

  return new Response('ok', { status: 200 });
});

// ────────────────────────────────────────────────────────────
// Transition → list of push plans
// We return a list because the 'returned' transition pings BOTH
// parties (we don't know which side tapped Mark Returned without
// an audit column).
// ────────────────────────────────────────────────────────────
interface PushPlan {
  targetUserId: string;
  title: string;
  body: string;
}

function resolvePushPlans(
  event: WebhookPayload['type'],
  record: BorrowRow,
  oldRecord: BorrowRow | null,
): PushPlan[] {
  // INSERT — owner gets pinged, borrower already knows.
  if (event === 'INSERT' && record.status === 'pending') {
    return [{
      targetUserId: record.owner_id,
      title: 'New borrow request',
      body: record.note?.trim()
        ? `"${truncate(record.note.trim(), 120)}"`
        : 'A friend wants to borrow an item from your closet.',
    }];
  }

  if (event !== 'UPDATE' || oldRecord === null) return [];
  if (oldRecord.status === record.status) return [];

  switch (record.status) {
    case 'approved':
      return [{
        targetUserId: record.borrower_id,
        title: 'Your borrow request was approved',
        body: 'Coordinate the handoff with your friend.',
      }];
    case 'denied':
      return [{
        targetUserId: record.borrower_id,
        title: 'Your borrow request was declined',
        body: 'No worries — try a different piece next time.',
      }];
    case 'cancelled':
      // Borrower withdrew. Tell the owner so it disappears from
      // their inbox.
      return [{
        targetUserId: record.owner_id,
        title: 'Borrow request withdrawn',
        body: 'A pending request was cancelled.',
      }];
    case 'returned':
      // Either party may have marked it. Ping the OTHER side; the
      // marker already saw the local update.
      return [
        {
          targetUserId: record.owner_id,
          title: 'Item marked as returned',
          body: 'The borrow is closed.',
        },
        {
          targetUserId: record.borrower_id,
          title: 'Item marked as returned',
          body: 'The borrow is closed.',
        },
      ];
    case 'active':
      // 'active' is purely advisory and computed on the client —
      // we don't push it; the borrower already triggered it.
      return [];
  }

  return [];
}

async function fetchTokens(userId: string): Promise<DeviceTokenRow[]> {
  const { data, error } = await supabase
    .from('device_tokens')
    .select('token, platform')
    .eq('app', 'customer')
    .eq('user_id', userId);
  if (error) {
    console.warn('[notify-borrow] token fetch failed', error.message);
    return [];
  }
  return (data ?? []) as DeviceTokenRow[];
}

function truncate(s: string, max: number): string {
  if (s.length <= max) return s;
  return `${s.substring(0, max - 1)}…`;
}
