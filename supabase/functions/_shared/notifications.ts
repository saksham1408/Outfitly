// ============================================================
// Shared in-app notifications helper — used by every notify-*
// edge function so a single INSERT path lives in one place.
//
// Each push that goes out to a user device should also land as a
// row in `public.notifications` so the customer's bell-icon feed
// (migration 043) mirrors the OS-level banners. The customer
// browses the feed at `/notifications`; the bell badge tracks
// unread rows here in real time.
//
// Notes:
//   * Edge functions run with the service role, which bypasses
//     RLS on `notifications` — that's fine because each row's
//     `user_id` is set explicitly by the caller, not derived from
//     auth.uid() (which would be NULL in a webhook context).
//   * INSERT errors are logged but never thrown — pushes are
//     best-effort and shouldn't take the function down. The
//     return value lets the caller log a per-call tally if it
//     wants.
// ============================================================

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

export interface NotificationInsert {
  userId: string;
  title: string;
  body: string;
  /// Source category — drives the icon + accent on the feed
  /// card. See `lib/features/notifications/models/app_notification.dart`
  /// (`NotificationKind`) for the canonical list.
  /// Common values: 'promo', 'borrow', 'appointment', 'pickup', 'system'.
  type: string;
  /// Deep-link route the feed card pushes on tap. Mirrors
  /// `data.route` on the FCM message so a tap from the in-app
  /// feed lands on the same surface as a tap from the system
  /// banner.
  route?: string;
  /// Free-form payload — surfaced as `data` on the row, retained
  /// for future extensions (thumbnail urls, CTA labels, etc.).
  data?: Record<string, unknown>;
}

export interface NotificationRecordResult {
  inserted: number;
  failed: number;
}

/// Bulk-insert one row per recipient. Returns `{inserted, failed}`
/// so the caller can log against its FCM tally.
export async function recordNotifications(
  supabase: SupabaseClient,
  rows: NotificationInsert[],
): Promise<NotificationRecordResult> {
  if (rows.length === 0) return { inserted: 0, failed: 0 };

  // Dedupe by userId+title — if a single transition somehow asks
  // us to record duplicate rows for the same user, collapse them.
  // Mirrors the FCM-side `collapseKey` philosophy.
  const seen = new Set<string>();
  const unique: NotificationInsert[] = [];
  for (const row of rows) {
    const key = `${row.userId}|${row.title}`;
    if (seen.has(key)) continue;
    seen.add(key);
    unique.push(row);
  }

  const payload = unique.map((r) => ({
    user_id: r.userId,
    title: r.title,
    body: r.body,
    type: r.type,
    route: r.route ?? null,
    data: r.data ?? {},
  }));

  const { error } = await supabase.from('notifications').insert(payload);
  if (error) {
    console.warn('[notifications] insert failed', error.message);
    return { inserted: 0, failed: unique.length };
  }
  return { inserted: unique.length, failed: 0 };
}
