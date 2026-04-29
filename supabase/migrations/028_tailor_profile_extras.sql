-- ============================================================
-- Outfitly: tailor profile rich-credentials + portfolio gallery
-- ------------------------------------------------------------
-- Backs the "Supply-Side Trust & Retention Ecosystem" surfaces
-- in the Tailor Partner app: a verification badge, ratings &
-- specialties on the profile screen, and a portfolio gallery
-- of past work.
--
-- Three changes:
--   1. New columns on `tailor_profiles` for the credibility row
--      (rating, review count, verified flag, lifetime earnings)
--      plus the `specialties` text[] that drives the chips
--      section.
--   2. A new `tailor_portfolios` table — one row per uploaded
--      garment photo, owned by the tailor.
--   3. A public Storage bucket `tailor_portfolios` for the
--      actual image bytes, with RLS so tailors can only write
--      under their own folder.
-- ============================================================


-- ──────────────────────────────────────────────────────────
-- 1. Extend tailor_profiles
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.tailor_profiles
  ADD COLUMN IF NOT EXISTS rating          numeric(3,2) NOT NULL DEFAULT 0
    CHECK (rating >= 0 AND rating <= 5),
  ADD COLUMN IF NOT EXISTS total_reviews   integer       NOT NULL DEFAULT 0
    CHECK (total_reviews >= 0),
  ADD COLUMN IF NOT EXISTS specialties     text[]        NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS is_verified     boolean       NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS total_earnings  numeric(12,2) NOT NULL DEFAULT 0
    CHECK (total_earnings >= 0);

-- A GIN index makes the eventual customer-side "find tailors
-- who specialize in Sherwanis" search cheap.
CREATE INDEX IF NOT EXISTS tailor_profiles_specialties_idx
  ON public.tailor_profiles USING GIN (specialties);


-- ──────────────────────────────────────────────────────────
-- 2. tailor_portfolios table
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tailor_portfolios (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tailor_id   uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  image_url   text        NOT NULL,
  description text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS tailor_portfolios_tailor_id_idx
  ON public.tailor_portfolios (tailor_id, created_at DESC);

ALTER TABLE public.tailor_portfolios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Tailors read own portfolio"   ON public.tailor_portfolios;
DROP POLICY IF EXISTS "Tailors insert own portfolio" ON public.tailor_portfolios;
DROP POLICY IF EXISTS "Tailors delete own portfolio" ON public.tailor_portfolios;
DROP POLICY IF EXISTS "Anyone can view portfolios"   ON public.tailor_portfolios;

-- Tailors can fully manage their own rows.
CREATE POLICY "Tailors read own portfolio"
  ON public.tailor_portfolios
  FOR SELECT
  USING (auth.uid() = tailor_id);

CREATE POLICY "Tailors insert own portfolio"
  ON public.tailor_portfolios
  FOR INSERT
  WITH CHECK (auth.uid() = tailor_id);

CREATE POLICY "Tailors delete own portfolio"
  ON public.tailor_portfolios
  FOR DELETE
  USING (auth.uid() = tailor_id);

-- Customers (any authenticated user) need to see portfolios on
-- the customer-facing tailor card. We don't restrict reads to
-- "tailors assigned to my appointments" because portfolios are
-- a discovery surface — they pre-date any appointment.
CREATE POLICY "Anyone can view portfolios"
  ON public.tailor_portfolios
  FOR SELECT
  TO authenticated
  USING (true);


-- ──────────────────────────────────────────────────────────
-- 3. Storage bucket for portfolio image bytes
-- ──────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('tailor_portfolios', 'tailor_portfolios', true)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: scope writes to `{uid}/...` paths so a tailor
-- can never overwrite another tailor's images even if they
-- guess the path.
DROP POLICY IF EXISTS "Tailors upload own portfolio images"
  ON storage.objects;
DROP POLICY IF EXISTS "Tailors delete own portfolio images"
  ON storage.objects;
DROP POLICY IF EXISTS "Anyone can read portfolio images"
  ON storage.objects;

CREATE POLICY "Tailors upload own portfolio images"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'tailor_portfolios'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Tailors delete own portfolio images"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'tailor_portfolios'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Anyone can read portfolio images"
  ON storage.objects
  FOR SELECT
  USING (bucket_id = 'tailor_portfolios');
