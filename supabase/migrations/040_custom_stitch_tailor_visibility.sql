-- ============================================================
-- 040_custom_stitch_tailor_visibility.sql
-- Open `public.custom_stitch_orders` to the Partner (tailor) app:
--   1. Tailors must see every `pending_pickup` row with no
--      assigned tailor (the broadcast queue) so the radar-style
--      "Pickups" screen can stream them via Supabase Realtime.
--   2. Tailors must be able to CLAIM such a row by stamping
--      `tailor_id = auth.uid()` onto it.
--   3. Once claimed, the existing
--      `custom_stitch_orders_tailor_update` policy from migration
--      039 already lets the assigned tailor walk the status
--      forward (fabric_collected → stitching → ready_for_delivery
--      → delivered).
--
-- Migration 039 originally scoped the SELECT to
-- `auth.uid() = tailor_id`, which hid the broadcast queue from
-- every tailor. This migration drops that policy and replaces it
-- with a unioned predicate, then adds the claim-UPDATE policy.
--
-- Customer-side policies are untouched.
-- ============================================================

-- ── 1. Tailor SELECT — broadcast queue + own claimed rows ──
DROP POLICY IF EXISTS "custom_stitch_orders_tailor_select"
  ON public.custom_stitch_orders;

CREATE POLICY "custom_stitch_orders_tailor_select"
  ON public.custom_stitch_orders FOR SELECT
  USING (
    -- (a) Rows already assigned to me — own queue.
    auth.uid() = tailor_id
    -- (b) The broadcast queue: pending + unclaimed. Once a tailor
    --     claims a row, condition (b) drops it from every other
    --     tailor's stream automatically because tailor_id is now
    --     non-NULL.
    OR (
      status = 'pending_pickup'
      AND tailor_id IS NULL
    )
  );

-- ── 2. Tailor claim — atomic UPDATE that stamps tailor_id ──
-- The USING clause filters the row set to "claimable" (still
-- pending and unclaimed); the WITH CHECK clause asserts the
-- caller is stamping their *own* uid onto the row. Together they
-- prevent a tailor from "claiming for someone else" and prevent
-- a late tap from over-writing a row another tailor already
-- claimed (because USING no longer matches once tailor_id is
-- non-NULL).
DROP POLICY IF EXISTS "custom_stitch_orders_tailor_claim"
  ON public.custom_stitch_orders;

CREATE POLICY "custom_stitch_orders_tailor_claim"
  ON public.custom_stitch_orders FOR UPDATE
  USING (
    status = 'pending_pickup'
    AND tailor_id IS NULL
  )
  WITH CHECK (
    auth.uid() = tailor_id
  );

-- The existing `custom_stitch_orders_tailor_update` policy from
-- migration 039 covers post-claim status progression; nothing to
-- change there. The `custom_stitch_orders_owner_*` policies
-- continue to apply on top — a customer can still cancel/amend
-- their own row regardless of which tailor (if any) owns it.
