-- ============================================================
-- Outfitly: customer-read policy on tailor_profiles
-- ------------------------------------------------------------
-- A deliberately narrow second SELECT policy on tailor_profiles.
--
-- Migration 024 locked every row behind `auth.uid() = id` — a
-- tailor can only see their own profile. That's correct for the
-- Partner app but leaves a gap for the customer app: once a
-- tailor accepts a visit request, the customer should see the
-- tailor's name and years-of-experience on the order-tracking
-- screen. Without a policy, the customer's SELECT would return
-- zero rows under RLS.
--
-- This policy unlocks EXACTLY that path: a customer may read a
-- tailor_profiles row only when there's a tailor_appointments
-- row linking them together (the customer owns the appointment
-- AND that appointment is assigned to this tailor).
--
-- The `EXISTS` subquery runs per-row but is cheap — we already
-- index both tailor_appointments.user_id and tailor_id from
-- migration 023, so the planner hits index-only scans.
--
-- Idempotent — DROP-then-CREATE so the block is safe to re-run
-- (Postgres 15 doesn't support `CREATE POLICY IF NOT EXISTS`).
-- ============================================================

DROP POLICY IF EXISTS "Customers read assigned tailor profile"
  ON public.tailor_profiles;

CREATE POLICY "Customers read assigned tailor profile"
  ON public.tailor_profiles
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.tailor_appointments ta
      WHERE ta.tailor_id = tailor_profiles.id
        AND ta.user_id  = auth.uid()
    )
  );
