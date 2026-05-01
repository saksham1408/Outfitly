-- ============================================================
-- 036_tailor_marketplace.sql
-- Marketplace shift for the home-tailor-visit flow:
--   * Customers now PICK a specific tailor at booking time, so
--     a new appointment row already carries `tailor_id` and a
--     dedicated `pending_tailor_approval` status — distinct from
--     the legacy `pending` (broadcast-to-everyone) state which
--     stays in place for backward compatibility.
--   * Tailors should now only see rows directed at them
--     (auth.uid() = tailor_id), unless we're still in the legacy
--     broadcast mode (status='pending' AND tailor_id IS NULL).
--   * Customers browsing the marketplace need a permissive
--     SELECT on `tailor_profiles` so they can compare ratings +
--     specialties before committing. The existing policy from
--     migration 025 only fires AFTER an appointment exists.
--
-- Three changes:
--   1. Extend the `status` CHECK to include the new value plus
--      every value migration 026 added (pending, accepted,
--      en_route, arrived, completed, cancelled,
--      pending_tailor_approval).
--   2. Replace the customer INSERT policy with one that accepts
--      the new status alongside the legacy 'pending'.
--   3. Replace the tailor SELECT policy so broadcast queues only
--      include the legacy null-tailor-id rows; assigned rows
--      stay scoped to the assigned tailor.
--   4. Add a marketplace SELECT policy on `tailor_profiles` so
--      any authenticated customer can browse rating + specialties
--      to pick a tailor. The client is responsible for selecting
--      only the public-safe columns (`id, full_name,
--      experience_years, rating, total_reviews, specialties,
--      is_verified`); we don't punch out a column-level RLS, but
--      the Customer app never asks for `phone` or
--      `total_earnings`.
-- ============================================================

-- ── 1. Extend status CHECK ────────────────────────────────────
ALTER TABLE public.tailor_appointments
  DROP CONSTRAINT IF EXISTS tailor_appointments_status_check;

ALTER TABLE public.tailor_appointments
  ADD CONSTRAINT tailor_appointments_status_check
  CHECK (status IN (
    'pending',
    'pending_tailor_approval',
    'accepted',
    'en_route',
    'arrived',
    'completed',
    'cancelled'
  ));

-- ── 2. Customer INSERT policy now allows the marketplace state ─
DROP POLICY IF EXISTS "Customers insert own appointments"
  ON public.tailor_appointments;

CREATE POLICY "Customers insert own appointments"
  ON public.tailor_appointments
  FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND status IN ('pending', 'pending_tailor_approval')
  );

-- ── 3. Tailor SELECT policy: scope assigned rows to that tailor
-- The legacy `status='pending' OR auth.uid() = tailor_id` would
-- let a chosen tailor's pending_tailor_approval row leak to every
-- other tailor (because the OR matches them via the broadcast
-- branch). New version: broadcast only when no tailor is
-- assigned (the legacy auto-dispatch path), otherwise the row is
-- private to the assigned tailor.
DROP POLICY IF EXISTS "Tailors read dispatch queue"
  ON public.tailor_appointments;

CREATE POLICY "Tailors read dispatch queue"
  ON public.tailor_appointments
  FOR SELECT
  USING (
    (status = 'pending' AND tailor_id IS NULL)
    OR auth.uid() = tailor_id
  );

-- ── 4. Marketplace SELECT on tailor_profiles ──────────────────
-- Any authenticated user can read tailor profiles for the
-- selection screen. Sensitive columns (phone, total_earnings)
-- are kept out of the client query — see TailorRepository.
DROP POLICY IF EXISTS "Customers browse tailor marketplace"
  ON public.tailor_profiles;

CREATE POLICY "Customers browse tailor marketplace"
  ON public.tailor_profiles
  FOR SELECT
  TO authenticated
  USING (true);
