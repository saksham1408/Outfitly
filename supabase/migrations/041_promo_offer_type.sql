-- ============================================================
-- 041_promo_offer_type.sql
-- Adds an `offer_type` discriminator to `public.promo_offers`
-- so the new Home hero carousel can render two distinct slide
-- designs:
--   * `sale`       — flash-sale slide with banner image + countdown
--   * `bank_offer` — credit-card-style slide with copy-code button
--
-- Also adds `bank_name` (nullable) so the bank-offer slide can
-- watermark a specific issuer (HDFC, SBI, ...) without parsing
-- the title text. Both columns default to safe values so every
-- existing row keeps rendering as a flash-sale slide unchanged.
-- ============================================================

-- ── 1. New columns ───────────────────────────────────────────
ALTER TABLE public.promo_offers
  ADD COLUMN IF NOT EXISTS offer_type text NOT NULL
    DEFAULT 'sale'
    CHECK (offer_type IN ('sale', 'bank_offer'));

ALTER TABLE public.promo_offers
  ADD COLUMN IF NOT EXISTS bank_name text
    CHECK (bank_name IS NULL OR length(bank_name) <= 32);

COMMENT ON COLUMN public.promo_offers.offer_type IS
  'Slide design discriminator on the Home hero carousel — sale (image + countdown) vs bank_offer (credit-card-style + copy-code).';

COMMENT ON COLUMN public.promo_offers.bank_name IS
  'Issuer label rendered on bank-offer slides (HDFC, SBI, ...). Ignored when offer_type = ''sale''.';

-- ── 2. Seed examples ─────────────────────────────────────────
-- One bank offer + one flash sale so the carousel renders both
-- designs on first launch. Idempotent — uses the title as the
-- conflict key.

-- Flash sale (already seeded by migration 038's "Diwali Sale";
-- nothing to add here for the sale variant).

-- Bank offer example.
INSERT INTO public.promo_offers (
  title,
  description,
  discount_percentage,
  banner_image_url,
  end_date,
  target_route,
  promo_code,
  offer_type,
  bank_name
)
SELECT
  'HDFC Card Offer',
  'Instant 10% Off on HDFC Bank Credit Cards — applied at checkout.',
  10,
  NULL,
  now() + interval '30 days',
  '/catalog',
  'HDFC10',
  'bank_offer',
  'HDFC'
WHERE NOT EXISTS (
  SELECT 1 FROM public.promo_offers WHERE title = 'HDFC Card Offer'
);

INSERT INTO public.promo_offers (
  title,
  description,
  discount_percentage,
  banner_image_url,
  end_date,
  target_route,
  promo_code,
  offer_type,
  bank_name
)
SELECT
  'SBI Card Offer',
  '5% Cashback on SBI Credit Cards — credited within 7 working days.',
  5,
  NULL,
  now() + interval '30 days',
  '/catalog',
  'SBI5',
  'bank_offer',
  'SBI'
WHERE NOT EXISTS (
  SELECT 1 FROM public.promo_offers WHERE title = 'SBI Card Offer'
);

-- A second flash-sale row so the carousel has at least three
-- slides even before the marketing team publishes more.
INSERT INTO public.promo_offers (
  title,
  description,
  discount_percentage,
  banner_image_url,
  end_date,
  target_route,
  promo_code,
  offer_type
)
SELECT
  'End of Season Sale',
  'Up to 40% off on bespoke silhouettes — closing this weekend.',
  40,
  NULL,
  now() + interval '3 days',
  '/catalog',
  'EOSS40',
  'sale'
WHERE NOT EXISTS (
  SELECT 1 FROM public.promo_offers WHERE title = 'End of Season Sale'
);
