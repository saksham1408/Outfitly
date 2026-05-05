-- ============================================================
-- 038_promo_offers.sql
-- Marketing & Promotions engine — backs the new "Active Offers
-- & Sales" dashboard that surfaces sitewide promotions
-- (Diwali, EOSS, etc.) and the FCM push that announces each
-- one going live.
--
-- One row per active campaign. The customer app pulls the
-- `is_active = true AND end_date > now()` set sorted by
-- end_date ascending (so the most-urgent offer leads). When a
-- new row lands, the marketing dashboard drops a push to every
-- registered customer device — `notify-promo` edge function
-- (TODO follow-up) wires that handoff.
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- 1. Table
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.promo_offers (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Display fields. The cap on `description` keeps the banner
  -- card readable; longer copy belongs on a future Offer Detail
  -- screen.
  title               text        NOT NULL,
  description         text        CHECK (description IS NULL OR length(description) <= 500),
  -- 1-99. Stored as smallint so we never accidentally render a
  -- "0% OFF" or "150% OFF" card.
  discount_percentage smallint    NOT NULL
                        CHECK (discount_percentage BETWEEN 1 AND 99),
  banner_image_url    text,
  -- When the offer expires. Stored UTC; the client formats in
  -- the user's local zone for the countdown timer.
  end_date            timestamptz NOT NULL,
  -- A soft delete + scheduling switch in one. The marketing
  -- team flips this to false to retire an offer; the customer
  -- query filters on it before any other condition.
  is_active           boolean     NOT NULL DEFAULT true,
  -- Optional deep-link target so the "Shop now" tap from the
  -- offer card can route to a category / subcategory / search.
  -- Free-form text so we don't have to ship a migration every
  -- time a new route is added.
  target_route        text,
  -- Optional promo code that the design studio can pre-apply
  -- on entry from this card.
  promo_code          text        CHECK (promo_code IS NULL OR length(promo_code) <= 32),
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

-- Hot path: customer dashboard reads
--   WHERE is_active = true AND end_date > now()
--   ORDER BY end_date ASC
-- A composite index covers the predicate + the ordering in one
-- index seek.
CREATE INDEX IF NOT EXISTS promo_offers_active_idx
  ON public.promo_offers (is_active, end_date)
  WHERE is_active = true;

COMMENT ON TABLE public.promo_offers IS
  'Active marketing campaigns surfaced on the customer "Active Offers & Sales" dashboard and announced via FCM push when a new row lands.';

-- ──────────────────────────────────────────────────────────
-- 2. updated_at touch trigger
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.promo_offers_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS promo_offers_touch_updated_at ON public.promo_offers;
CREATE TRIGGER promo_offers_touch_updated_at
BEFORE UPDATE ON public.promo_offers
FOR EACH ROW EXECUTE FUNCTION public.promo_offers_touch_updated_at();

-- ──────────────────────────────────────────────────────────
-- 3. Row-Level Security
-- ──────────────────────────────────────────────────────────
-- Customers can read every row, including inactive / expired
-- ones — the client filters in the `select()` query, so an
-- admin who marks a row inactive immediately de-lists it from
-- the dashboard without needing a separate "soft-deleted"
-- predicate baked into RLS.
--
-- Writes (INSERT/UPDATE/DELETE) go through the Directus admin
-- panel using the service role, which bypasses RLS. We don't
-- expose any client-side write surface for promotions.
ALTER TABLE public.promo_offers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read promo offers" ON public.promo_offers;
CREATE POLICY "Anyone can read promo offers"
  ON public.promo_offers
  FOR SELECT
  TO authenticated
  USING (true);

-- ──────────────────────────────────────────────────────────
-- 4. Realtime
-- ──────────────────────────────────────────────────────────
-- Customers should see fresh offers the moment they're
-- published — without needing to pull-to-refresh. Adding the
-- table to the publication enables `.stream()` on the client.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'promo_offers'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime
             ADD TABLE public.promo_offers';
  END IF;
END $$;

-- ──────────────────────────────────────────────────────────
-- 5. Seed — one example offer so the dashboard renders
-- something on first launch in dev. Safe to re-run.
-- Remove or update via the Directus admin panel.
-- ──────────────────────────────────────────────────────────
INSERT INTO public.promo_offers (
  title,
  description,
  discount_percentage,
  banner_image_url,
  end_date,
  target_route,
  promo_code
)
SELECT
  'Diwali Sale',
  'Festive savings across the entire bespoke catalog — limited time only.',
  20,
  NULL,
  now() + interval '7 days',
  '/catalog',
  'DIWALI20'
WHERE NOT EXISTS (
  SELECT 1 FROM public.promo_offers WHERE title = 'Diwali Sale'
);
