-- ============================================================
-- Outfitly: tailor_appointments status progression
-- ------------------------------------------------------------
-- Migration 023 introduced four lifecycle states:
--   pending → accepted → completed → cancelled
--
-- The accepted → completed jump is too coarse for the customer
-- tracking surface — once a tailor has claimed a visit, the
-- customer wants to know whether they're still at the workshop,
-- on the way, or already at the door.
--
-- This migration widens the CHECK to include two new in-flight
-- states the Partner app can transition through:
--
--   pending → accepted → en_route → arrived → completed
--                                         ↘ cancelled
--
-- `en_route` and `arrived` are both valid intermediate stops; the
-- Partner app exposes "I'M ON THE WAY" and "I'VE ARRIVED" buttons
-- that flip the status one step at a time. The customer's live
-- tracking screen renders these as filled steps in a vertical
-- timeline, giving the visit a delivery-app feel.
--
-- The migration is a drop-and-recreate of the existing CHECK
-- constraint. Postgres enforces NOT VALID semantics on add, but
-- because every existing row already satisfies the wider set
-- (it's a superset of the old one), the recheck is a no-op.
-- ============================================================

ALTER TABLE public.tailor_appointments
  DROP CONSTRAINT IF EXISTS tailor_appointments_status_check;

ALTER TABLE public.tailor_appointments
  ADD CONSTRAINT tailor_appointments_status_check
  CHECK (status IN (
    'pending',
    'accepted',
    'en_route',
    'arrived',
    'completed',
    'cancelled'
  ));
