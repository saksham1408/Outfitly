-- ============================================================
-- 042_promo_offer_category_sale.sql
-- Adds the third hero-carousel slide variant: section-scoped
-- "category sale" rows. These are softer/airier than the dark
-- flash-sale slides and read more as a curated browse-prompt
-- ("Sherwanis · Up to 25% Off · Shop Now") than as urgency.
--
-- Two changes:
--   1. Extend the `offer_type` CHECK with `category_sale`.
--   2. Add a `category_label` column so the slide renders the
--      section name (e.g. "Wedding Wear", "Sarees") without us
--      having to parse it out of the marketing title.
--
-- Idempotent — re-runnable. Existing rows keep their values.
-- ============================================================

-- ── 1. Widen the offer_type check ───────────────────────────
-- Postgres doesn't let you "add" to an existing CHECK constraint
-- in place; you drop and recreate. We re-derive the constraint
-- name `promo_offers_offer_type_check` from the migration 041
-- naming pattern. If it doesn't exist (e.g., custom name on a
-- forked DB) the DROP is a no-op and the new constraint still
-- attaches cleanly.
ALTER TABLE public.promo_offers
  DROP CONSTRAINT IF EXISTS promo_offers_offer_type_check;

ALTER TABLE public.promo_offers
  ADD CONSTRAINT promo_offers_offer_type_check
  CHECK (offer_type IN ('sale', 'bank_offer', 'category_sale'));

-- ── 2. New column: category_label ────────────────────────────
ALTER TABLE public.promo_offers
  ADD COLUMN IF NOT EXISTS category_label text
    CHECK (category_label IS NULL OR length(category_label) <= 48);

COMMENT ON COLUMN public.promo_offers.category_label IS
  'Section label rendered on category-sale slides ("Wedding Wear", "Sarees", ...). Ignored when offer_type != ''category_sale''.';

-- ── 3. Seed examples ─────────────────────────────────────────
-- Five distinct section-scoped offers so the carousel has
-- visible variety on first launch. Each row links to a sensible
-- target_route — adjust subcategory ids to your own catalog
-- once those subcategory pages exist.

INSERT INTO public.promo_offers
  (title, description, discount_percentage, end_date, target_route,
   promo_code, offer_type, category_label)
SELECT
  'Wedding Wear Edit',
  'Hand-picked sherwanis, achkans, and bandhgalas — limited drop.',
  25,
  now() + interval '14 days',
  '/catalog',
  'WEDDING25',
  'category_sale',
  'Wedding Wear'
WHERE NOT EXISTS (
  SELECT 1 FROM public.promo_offers WHERE title = 'Wedding Wear Edit'
);

INSERT INTO public.promo_offers
  (title, description, discount_percentage, end_date, target_route,
   promo_code, offer_type, category_label)
SELECT
  'Festive Saree Drop',
  'Banarasi, brocade, and silk sarees — woven for the festive feast.',
  30,
  now() + interval '10 days',
  '/catalog',
  'SAREE30',
  'category_sale',
  'Sarees'
WHERE NOT EXISTS (
  SELECT 1 FROM public.promo_offers WHERE title = 'Festive Saree Drop'
);

INSERT INTO public.promo_offers
  (title, description, discount_percentage, end_date, target_route,
   promo_code, offer_type, category_label)
SELECT
  'Indo-Western Suits',
  'Modern bandhgalas + Nehru jackets — the contemporary capsule.',
  15,
  now() + interval '21 days',
  '/catalog',
  'INDOWEST15',
  'category_sale',
  'Indo-Western'
WHERE NOT EXISTS (
  SELECT 1 FROM public.promo_offers WHERE title = 'Indo-Western Suits'
);

INSERT INTO public.promo_offers
  (title, description, discount_percentage, end_date, target_route,
   promo_code, offer_type, category_label)
SELECT
  'Kidswear Capsule',
  'Mini sherwanis + lehenga sets — same bespoke craft, half the size.',
  20,
  now() + interval '7 days',
  '/catalog',
  'KIDS20',
  'category_sale',
  'Kidswear'
WHERE NOT EXISTS (
  SELECT 1 FROM public.promo_offers WHERE title = 'Kidswear Capsule'
);

INSERT INTO public.promo_offers
  (title, description, discount_percentage, end_date, target_route,
   promo_code, offer_type, category_label)
SELECT
  'Bridal Lehenga Collection',
  'Couture lehengas with hand-zardozi — the once-in-a-lifetime drop.',
  35,
  now() + interval '5 days',
  '/catalog',
  'BRIDAL35',
  'category_sale',
  'Bridal Lehenga'
WHERE NOT EXISTS (
  SELECT 1 FROM public.promo_offers WHERE title = 'Bridal Lehenga Collection'
);
