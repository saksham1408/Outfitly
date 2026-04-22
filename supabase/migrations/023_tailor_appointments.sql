-- ============================================================
-- Outfitly: tailor_appointments table
-- ------------------------------------------------------------
-- Backs the Outfitly Tailor Partner App's real-time dispatch
-- radar. The customer app INSERTs a new row with status='pending'
-- when a customer books a bespoke tailoring visit; every active
-- Partner app is subscribed to pending rows via Supabase
-- Realtime and the first to accept flips the row to
-- status='accepted' + tailor_id=<their auth uid>. The UPDATE is
-- race-guarded by `.eq('status','pending')` on the client so
-- only one tailor can win.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.tailor_appointments (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tailor_id       uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  address         text        NOT NULL,
  scheduled_time  timestamptz NOT NULL,
  status          text        NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'completed', 'cancelled')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- Indexes for the two hot query paths:
--   1. Partner app streaming `where status = 'pending'`
--   2. Customer app reading their own appointments
CREATE INDEX IF NOT EXISTS tailor_appointments_status_idx
  ON public.tailor_appointments (status);

CREATE INDEX IF NOT EXISTS tailor_appointments_user_id_idx
  ON public.tailor_appointments (user_id);

CREATE INDEX IF NOT EXISTS tailor_appointments_tailor_id_idx
  ON public.tailor_appointments (tailor_id);

-- ──────────────────────────────────────────────────────────
-- Row Level Security
-- ──────────────────────────────────────────────────────────
-- Two distinct "tenants" share this table:
--   * Customers (owners of `user_id`)
--   * Tailors (assignees of `tailor_id`)
-- Policies are written so neither side can read the other's
-- PII beyond what they need to complete the dispatch handshake.
ALTER TABLE public.tailor_appointments ENABLE ROW LEVEL SECURITY;

-- Customers manage their own rows end-to-end.
CREATE POLICY "Customers read own appointments"
  ON public.tailor_appointments
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Customers insert own appointments"
  ON public.tailor_appointments
  FOR INSERT
  WITH CHECK (auth.uid() = user_id AND status = 'pending');

CREATE POLICY "Customers cancel own appointments"
  ON public.tailor_appointments
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Tailors can see every pending request (so the radar stream
-- returns them) AND rows they've already claimed.
CREATE POLICY "Tailors read dispatch queue"
  ON public.tailor_appointments
  FOR SELECT
  USING (
    status = 'pending'
    OR auth.uid() = tailor_id
  );

-- Tailors can claim a pending row by flipping status → accepted.
-- The WITH CHECK guard keeps claims honest: the row must land
-- with the tailor_id equal to the caller's uid.
CREATE POLICY "Tailors claim pending dispatch"
  ON public.tailor_appointments
  FOR UPDATE
  USING (status = 'pending')
  WITH CHECK (auth.uid() = tailor_id);

-- Tailors can progress / complete their own claimed jobs.
CREATE POLICY "Tailors update own jobs"
  ON public.tailor_appointments
  FOR UPDATE
  USING (auth.uid() = tailor_id)
  WITH CHECK (auth.uid() = tailor_id);

-- ──────────────────────────────────────────────────────────
-- updated_at auto-bump
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tailor_appointments_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tailor_appointments_touch_updated_at
  ON public.tailor_appointments;

CREATE TRIGGER tailor_appointments_touch_updated_at
  BEFORE UPDATE ON public.tailor_appointments
  FOR EACH ROW EXECUTE FUNCTION public.tailor_appointments_touch_updated_at();

-- ──────────────────────────────────────────────────────────
-- Realtime
-- ──────────────────────────────────────────────────────────
-- The Partner app's StreamBuilder subscribes via Supabase
-- Realtime. Add this table to the supabase_realtime publication
-- so mutations flow through.
ALTER PUBLICATION supabase_realtime ADD TABLE public.tailor_appointments;

-- ──────────────────────────────────────────────────────────
-- Seed — one pending dispatch so the radar has something to
-- pop on first launch while smoke-testing. Safe to re-run.
-- Replace the user_id with a real auth.users.id if you want
-- the customer app's Order Tracking to resolve it cleanly.
-- ──────────────────────────────────────────────────────────
-- INSERT INTO public.tailor_appointments (user_id, address, scheduled_time)
-- SELECT id, 'Mumbai 400001, Marine Drive', now() + interval '1 hour'
-- FROM auth.users
-- WHERE email = 'demo@outfitly.app'
-- ON CONFLICT DO NOTHING;
