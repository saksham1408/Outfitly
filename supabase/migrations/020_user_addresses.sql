-- ============================================================
-- 020_user_addresses.sql
-- Per-user saved delivery addresses. Replaces the SharedPreferences-
-- only storage used during Phase 1/2 of the delivery-address feature.
--
-- Shape mirrors the on-device SavedAddress model, with snake_case
-- columns and an `is_selected` flag so the home-screen pill can just
-- pick the one selected row on cold launch. A trigger enforces "at
-- most one selected per user" — we auto-clear the previous selection
-- the moment a new row is marked selected, which makes the Flutter
-- `select(id)` call a single round trip.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.user_addresses (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- user_id defaults to auth.uid() so the client never has to send it;
  -- the `_own_insert` RLS policy below still re-asserts the match.
  user_id         uuid NOT NULL DEFAULT auth.uid()
                    REFERENCES auth.users(id) ON DELETE CASCADE,
  label           text NOT NULL
                    CHECK (label IN ('home', 'work', 'other')),
  recipient_name  text NOT NULL,
  phone           text,
  pincode         text NOT NULL,
  address_line1   text NOT NULL,
  address_line2   text,
  city            text NOT NULL,
  state           text,
  latitude        double precision,
  longitude       double precision,
  is_selected     boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.user_addresses IS
  'Per-user delivery addresses. Exactly one row per user has is_selected=true (enforced by trigger).';

CREATE INDEX IF NOT EXISTS user_addresses_user_idx
  ON public.user_addresses(user_id);
CREATE INDEX IF NOT EXISTS user_addresses_user_selected_idx
  ON public.user_addresses(user_id, is_selected)
  WHERE is_selected = true;

-- ── updated_at auto-touch ──
CREATE OR REPLACE FUNCTION public.touch_user_addresses_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_user_addresses_updated_at ON public.user_addresses;
CREATE TRIGGER trg_user_addresses_updated_at
  BEFORE UPDATE ON public.user_addresses
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_user_addresses_updated_at();

-- ── "exactly one selected per user" ──
-- Fires after insert/update when the new row claims to be selected.
-- Wipes the flag on every other row for that user. Runs in the same
-- transaction as the client's upsert, so either both succeed or both
-- roll back — no intermediate "two rows selected" state.
CREATE OR REPLACE FUNCTION public.enforce_single_selected_address()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.is_selected THEN
    UPDATE public.user_addresses
      SET is_selected = false
      WHERE user_id = NEW.user_id
        AND id <> NEW.id
        AND is_selected = true;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_user_addresses_single_selected
  ON public.user_addresses;
CREATE TRIGGER trg_user_addresses_single_selected
  AFTER INSERT OR UPDATE OF is_selected ON public.user_addresses
  FOR EACH ROW
  WHEN (NEW.is_selected = true)
  EXECUTE FUNCTION public.enforce_single_selected_address();

-- ── Row-Level Security ──
ALTER TABLE public.user_addresses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_addresses_own_select" ON public.user_addresses;
CREATE POLICY "user_addresses_own_select"
  ON public.user_addresses FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_addresses_own_insert" ON public.user_addresses;
CREATE POLICY "user_addresses_own_insert"
  ON public.user_addresses FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_addresses_own_update" ON public.user_addresses;
CREATE POLICY "user_addresses_own_update"
  ON public.user_addresses FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_addresses_own_delete" ON public.user_addresses;
CREATE POLICY "user_addresses_own_delete"
  ON public.user_addresses FOR DELETE
  USING (auth.uid() = user_id);
