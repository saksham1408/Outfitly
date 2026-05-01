-- ============================================================
-- 037_tailor_reviews.sql
-- Customer-written reviews of completed tailor visits.
--
-- One row per (customer × appointment) — UNIQUE on appointment_id
-- so a single visit can't be re-rated to game the average. Each
-- review carries 1–5 stars and an optional 500-char text body.
--
-- The aggregated `rating` (mean) and `total_reviews` (count)
-- columns on `tailor_profiles` (added in migration 028) are
-- recomputed automatically by a trigger on this table — meaning
-- the marketplace selection screen, the tailor's own profile,
-- and any future review-list view all read live values without
-- an extra round-trip.
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- 1. Table
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tailor_reviews (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id  uuid        NOT NULL UNIQUE
                    REFERENCES public.tailor_appointments(id)
                    ON DELETE CASCADE,
  -- We denormalise tailor_id so the customer-facing list view can
  -- filter by tailor without re-joining `tailor_appointments`.
  -- The INSERT policy enforces that this matches the appointment
  -- row's tailor_id, so it can never drift.
  tailor_id       uuid        NOT NULL
                    REFERENCES auth.users(id) ON DELETE CASCADE,
  reviewer_id     uuid        NOT NULL DEFAULT auth.uid()
                    REFERENCES auth.users(id) ON DELETE CASCADE,
  rating          smallint    NOT NULL CHECK (rating BETWEEN 1 AND 5),
  -- Optional comment. 500-char ceiling matches the rest of our
  -- text inputs (note on borrow_request, etc.) and keeps the
  -- review list readable at a glance.
  review_text     text        CHECK (review_text IS NULL OR length(review_text) <= 500),
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Hot paths:
--   * Marketplace card subtitle ("⭐ 4.9 · 132 reviews"): served
--     by the precomputed `tailor_profiles.rating` /
--     `total_reviews` columns — no read against this table.
--   * Tailor's own profile review-list ("read all reviews"):
--     SELECT … WHERE tailor_id = :id ORDER BY created_at DESC.
CREATE INDEX IF NOT EXISTS tailor_reviews_tailor_idx
  ON public.tailor_reviews (tailor_id, created_at DESC);

CREATE INDEX IF NOT EXISTS tailor_reviews_reviewer_idx
  ON public.tailor_reviews (reviewer_id, created_at DESC);

COMMENT ON TABLE public.tailor_reviews IS
  'Customer ratings of completed tailor visits. One row per appointment; aggregated into tailor_profiles.rating/total_reviews via the recompute trigger.';

-- ──────────────────────────────────────────────────────────
-- 2. Aggregate-recompute function + trigger
-- ──────────────────────────────────────────────────────────
-- SECURITY DEFINER so the function can UPDATE tailor_profiles even
-- though the calling customer has no RLS-blessed UPDATE on that
-- table. We confine the body to a single recompute SELECT + a
-- targeted UPDATE so the surface area stays tiny.

CREATE OR REPLACE FUNCTION public.recompute_tailor_rating(p_tailor_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_avg   numeric(3,2);
  v_count integer;
BEGIN
  SELECT
    COALESCE(AVG(rating), 0)::numeric(3,2),
    COUNT(*)
  INTO v_avg, v_count
  FROM public.tailor_reviews
  WHERE tailor_id = p_tailor_id;

  UPDATE public.tailor_profiles
  SET rating = v_avg,
      total_reviews = v_count
  WHERE id = p_tailor_id;
END;
$$;

REVOKE ALL ON FUNCTION public.recompute_tailor_rating(uuid) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.tailor_reviews_recompute_trg()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.recompute_tailor_rating(OLD.tailor_id);
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' AND NEW.tailor_id <> OLD.tailor_id THEN
    -- Defensive: a tailor_id swap shouldn't happen (the row's FK
    -- + our INSERT policy lock it down), but if some tooling
    -- somehow rotates it, recompute BOTH the old and new tailor.
    PERFORM public.recompute_tailor_rating(OLD.tailor_id);
    PERFORM public.recompute_tailor_rating(NEW.tailor_id);
    RETURN NEW;
  ELSE
    PERFORM public.recompute_tailor_rating(NEW.tailor_id);
    RETURN NEW;
  END IF;
END;
$$;

DROP TRIGGER IF EXISTS tailor_reviews_recompute
  ON public.tailor_reviews;

CREATE TRIGGER tailor_reviews_recompute
AFTER INSERT OR UPDATE OR DELETE ON public.tailor_reviews
FOR EACH ROW
EXECUTE FUNCTION public.tailor_reviews_recompute_trg();

-- ──────────────────────────────────────────────────────────
-- 3. Row-Level Security
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.tailor_reviews ENABLE ROW LEVEL SECURITY;

-- INSERT: only the customer who owned the appointment can review
-- it, and only after it's been completed. We re-assert
-- `tailor_id` matches the appointment's so the customer can't
-- INSERT a review pointing at a different tailor.
DROP POLICY IF EXISTS "Customers insert own reviews"
  ON public.tailor_reviews;

CREATE POLICY "Customers insert own reviews"
  ON public.tailor_reviews
  FOR INSERT
  WITH CHECK (
    auth.uid() = reviewer_id
    AND EXISTS (
      SELECT 1
      FROM public.tailor_appointments ta
      WHERE ta.id        = appointment_id
        AND ta.user_id   = auth.uid()
        AND ta.tailor_id = tailor_reviews.tailor_id
        AND ta.status    = 'completed'
    )
  );

-- SELECT: any authenticated user can read every review. Drives
-- the "read reviews" list on the tailor profile + marketplace
-- card. We deliberately don't anonymise the reviewer here; the
-- client picks what to render (initials + rating, vs. full
-- name) so we keep policy logic minimal.
DROP POLICY IF EXISTS "Anyone can read reviews"
  ON public.tailor_reviews;

CREATE POLICY "Anyone can read reviews"
  ON public.tailor_reviews
  FOR SELECT
  TO authenticated
  USING (true);

-- UPDATE: reviewer can fix typos within 24h. Beyond that the
-- review crystallises so an old rating can't be retroactively
-- weaponised. WITH CHECK pins reviewer_id so the column can't
-- be re-pointed in the same statement.
DROP POLICY IF EXISTS "Customers update own recent reviews"
  ON public.tailor_reviews;

CREATE POLICY "Customers update own recent reviews"
  ON public.tailor_reviews
  FOR UPDATE
  USING (
    auth.uid() = reviewer_id
    AND created_at > now() - interval '24 hours'
  )
  WITH CHECK (
    auth.uid() = reviewer_id
  );

-- DELETE: same 24h grace — for a customer who realises they
-- meant to leave 5 stars instead of 1.
DROP POLICY IF EXISTS "Customers delete own recent reviews"
  ON public.tailor_reviews;

CREATE POLICY "Customers delete own recent reviews"
  ON public.tailor_reviews
  FOR DELETE
  USING (
    auth.uid() = reviewer_id
    AND created_at > now() - interval '24 hours'
  );
