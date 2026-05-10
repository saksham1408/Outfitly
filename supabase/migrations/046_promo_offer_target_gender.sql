-- ============================================================
-- 046_promo_offer_target_gender.sql
-- Adds a `target_gender` discriminator to `public.promo_offers`
-- so the Home hero carousel can filter to the section the
-- customer is currently looking at.
--
-- The home tabs are MEN / WOMEN / KIDS. When a customer is on
-- KIDS, the carousel should surface only kids-relevant offers
-- (and any sitewide offer flagged `all`/null). Same for MEN
-- and WOMEN.
--
-- Values:
--   * 'men'   — only shown on the MEN tab
--   * 'women' — only shown on the WOMEN tab
--   * 'kids'  — only shown on the KIDS tab
--   * 'all'   — sitewide; shown on every tab
--   * NULL    — same as 'all' (forward-compat / unset rows)
--
-- Existing rows are retrofitted to the most likely target so
-- the carousel doesn't render the wrong offer to a section.
-- New men- and kids-specific offers are seeded so each section
-- has visible variety on first launch.
-- ============================================================

-- ── 1. New column ───────────────────────────────────────────
ALTER TABLE public.promo_offers
  ADD COLUMN IF NOT EXISTS target_gender text
    CHECK (
      target_gender IS NULL
      OR target_gender IN ('men', 'women', 'kids', 'all')
    );

COMMENT ON COLUMN public.promo_offers.target_gender IS
  'Section-targeting discriminator on the Home hero carousel — men / women / kids / all (or NULL = sitewide).';

-- ── 2. Retrofit existing rows ───────────────────────────────
-- Each title we seeded in earlier migrations gets its
-- best-fit gender so a customer on, say, the KIDS tab doesn''t
-- see "Bridal Lehenga Collection" on the carousel.

-- Sitewide / bank / cross-gender offers.
UPDATE public.promo_offers
   SET target_gender = 'all'
 WHERE target_gender IS NULL
   AND title IN (
     'Diwali Sale',
     'End of Season Sale',
     'HDFC Card Offer',
     'SBI Card Offer',
     'Indo-Western Suits',
     'Wedding Wear Edit'
   );

-- Women-only.
UPDATE public.promo_offers
   SET target_gender = 'women'
 WHERE target_gender IS NULL
   AND title IN (
     'Festive Saree Drop',
     'Bridal Lehenga Collection'
   );

-- Kids-only.
UPDATE public.promo_offers
   SET target_gender = 'kids'
 WHERE target_gender IS NULL
   AND title = 'Kidswear Capsule';

-- Anything still NULL (custom rows the marketing team may have
-- added since) stays NULL — the client treats NULL as sitewide.

-- ── 3. New men-targeted seeds ──────────────────────────────
INSERT INTO public.promo_offers (
  title, description, discount_percentage, end_date, target_route,
  promo_code, offer_type, category_label, target_gender
)
SELECT
  'Men''s Sherwani Edit',
  'Bandhgalas, achkans, and silk kurtas — the Men''s wedding capsule.',
  25,
  now() + interval '14 days',
  '/catalog',
  'MENS25',
  'category_sale',
  'Men''s Wedding',
  'men'
WHERE NOT EXISTS (
  SELECT 1 FROM public.promo_offers WHERE title = 'Men''s Sherwani Edit'
);

INSERT INTO public.promo_offers (
  title, description, discount_percentage, end_date, target_route,
  promo_code, offer_type, category_label, target_gender
)
SELECT
  'Modern Indo-Western',
  'Nehru jackets + bandhgalas — the contemporary Men''s capsule.',
  20,
  now() + interval '21 days',
  '/catalog',
  'INDOMEN20',
  'category_sale',
  'Men''s Indo-Western',
  'men'
WHERE NOT EXISTS (
  SELECT 1 FROM public.promo_offers WHERE title = 'Modern Indo-Western'
);

-- ── 4. Extra kids seed so the KIDS tab is not just one card ──
INSERT INTO public.promo_offers (
  title, description, discount_percentage, end_date, target_route,
  promo_code, offer_type, category_label, target_gender
)
SELECT
  'Mini Sherwani Drop',
  'Bespoke wedding-day kurtas + sherwanis for boys 2–14.',
  20,
  now() + interval '10 days',
  '/catalog',
  'MINI20',
  'category_sale',
  'Boys',
  'kids'
WHERE NOT EXISTS (
  SELECT 1 FROM public.promo_offers WHERE title = 'Mini Sherwani Drop'
);

INSERT INTO public.promo_offers (
  title, description, discount_percentage, end_date, target_route,
  promo_code, offer_type, category_label, target_gender
)
SELECT
  'Little Lehengas',
  'Hand-block-printed lehengas for girls 4–12 — festival-ready.',
  25,
  now() + interval '10 days',
  '/catalog',
  'LITTLE25',
  'category_sale',
  'Girls',
  'kids'
WHERE NOT EXISTS (
  SELECT 1 FROM public.promo_offers WHERE title = 'Little Lehengas'
);
