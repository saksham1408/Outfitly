-- ============================================================
-- 047_custom_stitch_orders_customer_isolation.sql
-- Plug a data-isolation gap introduced by migration 040.
--
-- Migration 040 opened the SELECT policy on
-- `public.custom_stitch_orders` so tailors could see the
-- broadcast queue (`status='pending_pickup' AND tailor_id IS
-- NULL`). The predicate didn't restrict who counts as a "tailor"
-- — every authenticated row matched — so a CUSTOMER signing in
-- could also see every other customer's pending pickup rows,
-- INCLUDING the pickup address. That's a privacy bug, not just a
-- caching one.
--
-- This migration scopes the broadcast leg of the policy to
-- accounts that actually have a `tailor_profiles` row. Customer
-- accounts (no tailor_profiles entry) fall back to seeing ONLY
-- the rows they own via the existing
-- `custom_stitch_orders_owner_select` policy.
--
-- Tailor-side claim + post-claim update policies are untouched.
-- ============================================================

DROP POLICY IF EXISTS "custom_stitch_orders_tailor_select"
  ON public.custom_stitch_orders;

CREATE POLICY "custom_stitch_orders_tailor_select"
  ON public.custom_stitch_orders FOR SELECT
  USING (
    -- (a) Rows already assigned to me — my own queue.
    auth.uid() = tailor_id
    -- (b) Broadcast queue. Same as migration 040 but now gated
    --     by the existence of a `tailor_profiles` row for the
    --     caller, so customer accounts can't see other
    --     customers' bookings.
    OR (
      status = 'pending_pickup'
      AND tailor_id IS NULL
      AND EXISTS (
        SELECT 1 FROM public.tailor_profiles
        WHERE tailor_profiles.id = auth.uid()
      )
    )
  );

-- Belt-and-braces on the claim policy too — only tailors can
-- claim a broadcast row. Without this an authenticated customer
-- could (in theory) UPDATE someone else's pending row to stamp
-- their own uid as tailor_id, which the WITH CHECK currently
-- allows.
DROP POLICY IF EXISTS "custom_stitch_orders_tailor_claim"
  ON public.custom_stitch_orders;

CREATE POLICY "custom_stitch_orders_tailor_claim"
  ON public.custom_stitch_orders FOR UPDATE
  USING (
    status = 'pending_pickup'
    AND tailor_id IS NULL
    AND EXISTS (
      SELECT 1 FROM public.tailor_profiles
      WHERE tailor_profiles.id = auth.uid()
    )
  )
  WITH CHECK (
    auth.uid() = tailor_id
    AND EXISTS (
      SELECT 1 FROM public.tailor_profiles
      WHERE tailor_profiles.id = auth.uid()
    )
  );
