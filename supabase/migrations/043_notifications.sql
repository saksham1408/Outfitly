-- ============================================================
-- 043_notifications.sql
-- In-app notifications feed.
--
-- Backs the bell-icon screen on the customer app: every time the
-- atelier sends a sale push / borrow ping / appointment update
-- via the notify-* edge functions, a row also lands here so the
-- user has a persistent feed they can scroll through (vs. just
-- a fleeting OS-level banner).
--
-- The bell-icon badge in the home AppBar reads the unread count
-- off this table via a Realtime stream, so newly-inserted rows
-- bump the badge without a refresh.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.notifications (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Auth.uid()-defaulted so client INSERTs (today: only the seed
  -- below; long-term: the notify-* edge functions running with
  -- service-role) don't have to thread the uid manually.
  user_id       uuid        NOT NULL DEFAULT auth.uid()
                            REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Display fields. `body` capped to keep the feed cards readable.
  title         text        NOT NULL,
  body          text        CHECK (body IS NULL OR length(body) <= 500),
  -- Source/category — drives the icon + accent colour shown on
  -- each row. Free-text + soft client-side catalog so a future
  -- engineer adding a new push type doesn't need a migration.
  -- Common values: 'promo', 'borrow', 'appointment', 'pickup',
  -- 'system'.
  type          text        NOT NULL DEFAULT 'system',
  -- Optional deep-link route the row taps into. Mirrors the
  -- `data.route` field on the FCM message so a tap from the
  -- in-app feed lands on the same surface as a tap from the
  -- system push banner.
  route         text,
  -- Free-form JSON for future extensions (e.g. a thumbnail image
  -- url, a CTA button label). Stored as jsonb so we can index /
  -- query inside it later without a schema migration.
  data          jsonb       DEFAULT '{}'::jsonb,
  -- NULL until the user opens the notification (or "Mark all as
  -- read"). The bell badge counts WHERE read_at IS NULL.
  read_at       timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- Hot path: `WHERE user_id = auth.uid() ORDER BY created_at DESC`.
-- Composite index covers the predicate + the ordering in one seek.
CREATE INDEX IF NOT EXISTS notifications_user_idx
  ON public.notifications (user_id, created_at DESC);

-- Unread-count badge: `WHERE user_id = auth.uid() AND read_at IS NULL`.
-- Partial index keeps it tiny because most older notifications are
-- read.
CREATE INDEX IF NOT EXISTS notifications_unread_idx
  ON public.notifications (user_id)
  WHERE read_at IS NULL;

COMMENT ON TABLE public.notifications IS
  'In-app notifications feed. One row per push the user received; the bell-icon badge counts WHERE read_at IS NULL.';

-- ── Row-Level Security ─────────────────────────────────────
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_owner_select"
  ON public.notifications;
CREATE POLICY "notifications_owner_select"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

-- Customers can mark their own rows read (UPDATE read_at). They
-- can also delete their own rows for a "swipe to dismiss"
-- gesture. Inserts go through the service role from the notify-*
-- edge functions; we don't expose a client-side INSERT surface.
DROP POLICY IF EXISTS "notifications_owner_update"
  ON public.notifications;
CREATE POLICY "notifications_owner_update"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "notifications_owner_delete"
  ON public.notifications;
CREATE POLICY "notifications_owner_delete"
  ON public.notifications FOR DELETE
  USING (auth.uid() = user_id);

-- For development convenience, also grant authenticated users
-- INSERT on their own rows so the seed-from-SQL-Editor flow works
-- without service-role gymnastics. Production deployments should
-- prefer service-role insertion via the notify-* edge functions.
DROP POLICY IF EXISTS "notifications_owner_insert"
  ON public.notifications;
CREATE POLICY "notifications_owner_insert"
  ON public.notifications FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ── Realtime ───────────────────────────────────────────────
-- Bell-icon badge subscribes to this table — a fresh row pushes
-- the unread count up automatically.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notifications'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime
             ADD TABLE public.notifications';
  END IF;
END $$;

-- ── Seed ───────────────────────────────────────────────────
-- Three example notifications for the currently-signed-in user
-- so the feed renders something on first launch in dev. Safe to
-- re-run; the WHERE NOT EXISTS clauses keep it idempotent.
INSERT INTO public.notifications (user_id, title, body, type, route)
SELECT
  auth.uid(),
  'Welcome to Outfitly',
  'Browse the catalog, build a combo, or book a doorstep tailor — all from the home screen.',
  'system',
  '/catalog'
WHERE auth.uid() IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.notifications
    WHERE user_id = auth.uid() AND title = 'Welcome to Outfitly'
  );

INSERT INTO public.notifications (user_id, title, body, type, route)
SELECT
  auth.uid(),
  'Diwali Sale is live',
  '20% off across the bespoke catalog. Hurry — closes this weekend.',
  'promo',
  '/catalog'
WHERE auth.uid() IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.notifications
    WHERE user_id = auth.uid() AND title = 'Diwali Sale is live'
  );

INSERT INTO public.notifications (user_id, title, body, type, route)
SELECT
  auth.uid(),
  'New Bank Offer',
  'Instant 10% off on HDFC Credit Cards — code HDFC10.',
  'promo',
  '/catalog'
WHERE auth.uid() IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.notifications
    WHERE user_id = auth.uid() AND title = 'New Bank Offer'
  );
