// ============================================================
// Outfitly Edge Function — notify-borrow
// ------------------------------------------------------------
// Fan-out a push notification to the right party when a row in
// `borrow_requests` is INSERTed or its status UPDATEs.
//
// Audience by event:
//
//   * INSERT (status='pending') — borrower asked owner to lend.
//     Push the OWNER ("New borrow request").
//   * UPDATE pending → approved — push BORROWER.
//   * UPDATE pending → denied — push BORROWER.
//   * UPDATE pending → cancelled — push OWNER (request withdrawn).
//   * UPDATE approved → returned — push BOTH parties (we don't
//     track who marked it). Collapse-id dedupes on the receiving
//     side.
//   * UPDATE → active — purely advisory, no push.
//
// Auth: FCM HTTP v1 via service-account JWT. See
// supabase/functions/_shared/fcm.ts for the helper. Set
// FCM_SERVICE_ACCOUNT in Supabase secrets to go live; without
// it the function logs and returns 200 (scaffold mode).
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
}

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
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

  // In-app feed: one row per push plan. We record these BEFORE
  // the FCM fan-out so the badge is already bumped by the time
  // the OS banner arrives. Recording is idempotent on the helper
  // side (dedupes by user+title) so a duplicate plan won't
  // double-stamp the inbox.
  const recordResult = await recordNotifications(
    supabase,
    plans.map((p) => ({
      userId: p.targetUserId,
      title: p.title,
      body: p.body,
      type: 'borrow',
      route: '/borrow-requests',
      data: {
        borrow_request_id: record.id,
        status: record.status,
        wardrobe_item_id: record.wardrobe_item_id,
      },
    })),
  );
  console.log(
    `[notify-borrow] feed rows inserted=${recordResult.inserted} failed=${recordResult.failed}`,
  );

  const sa = readServiceAccount();
  if (!sa) {
    console.log('[notify-borrow] FCM_SERVICE_ACCOUNT not set — scaffold no-op');
    return new Response('scaffold no-op', { status: 200 });
  }

  const accessToken = await mintAccessToken(sa);
  if (!accessToken) {
    return new Response('could not mint FCM token', { status: 200 });
  }

  let okCount = 0;
  let failCount = 0;

  for (const plan of plans) {
    const tokens = await fetchTokens(plan.targetUserId);
    if (tokens.length === 0) {
      console.log(`[notify-borrow] no tokens for ${plan.targetUserId}`);
      continue;
    }
    console.log(
      `[notify-borrow] ${tokens.length} push(es) → ${plan.targetUserId}: ${plan.title}`,
    );

    for (const t of tokens) {
      const r = await sendFcmMessage(sa, accessToken, {
        token: t.token,
        notification: { title: plan.title, body: plan.body },
        data: {
          borrow_request_id: record.id,
          status: record.status,
          wardrobe_item_id: record.wardrobe_item_id,
          // Borrow rows live on the borrow-requests dashboard
          // (the swap-arrows icon next to Loop). Sending the user
          // there feels right whether they're owner or borrower —
          // the screen has both Incoming + Outgoing tabs.
          route: '/borrow-requests',
        },
        collapseKey: `borrow:${record.id}`,
      });
      if (r.ok) okCount++;
      else {
        failCount++;
        console.warn(
          `[notify-borrow] FCM ${r.status} for token ${t.token.slice(0, 12)}…: ${r.body}`,
        );
      }
    }
  }

  console.log(
    `[notify-borrow] done. delivered=${okCount} failed=${failCount}`,
  );
  return new Response(
    JSON.stringify({
      delivered: okCount,
      failed: failCount,
      feed_rows: recordResult.inserted,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});

// ────────────────────────────────────────────────────────────
// Transition → list of push plans
// Returns a list because 'returned' pings BOTH parties (we
// don't track who tapped Mark Returned).
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
  if (event === 'INSERT' && record.status === 'pending') {
    return [
      {
        targetUserId: record.owner_id,
        title: 'New borrow request',
        body: record.note?.trim()
          ? `"${truncate(record.note.trim(), 120)}"`
          : 'A friend wants to borrow an item from your closet.',
      },
    ];
  }

  if (event !== 'UPDATE' || oldRecord === null) return [];
  if (oldRecord.status === record.status) return [];

  switch (record.status) {
    case 'approved':
      return [
        {
          targetUserId: record.borrower_id,
          title: 'Your borrow request was approved',
          body: 'Coordinate the handoff with your friend.',
        },
      ];
    case 'denied':
      return [
        {
          targetUserId: record.borrower_id,
          title: 'Your borrow request was declined',
          body: 'No worries — try a different piece next time.',
        },
      ];
    case 'cancelled':
      return [
        {
          targetUserId: record.owner_id,
          title: 'Borrow request withdrawn',
          body: 'A pending request was cancelled.',
        },
      ];
    case 'returned':
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
      // Computed client-side; nothing to push.
      return [];
  }

  return [];
}

async function fetchTokens(userId: string): Promise<DeviceTokenRow[]> {
  const { data, error } = await supabase
    .from('device_tokens')
    .select('token')
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
