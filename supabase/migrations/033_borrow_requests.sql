-- ============================================================
-- 033_borrow_requests.sql
-- Peer-to-peer "Request to Borrow" lifecycle for the Friend
-- Closet feature.
--
-- Lifecycle (status):
--   pending    → borrower sent the request; owner hasn't responded
--   approved   → owner said yes (still future-dated)
--   denied     → owner said no
--   active     → today is between borrow_start and borrow_end
--   returned   → garment back; closes the loop
--   cancelled  → borrower withdrew before owner responded
--
-- The 'active'/'returned' transitions are "advisory" — the client
-- shows them based on the date window + a return tap. We don't
-- enforce them server-side because there's nothing the DB can
-- usefully verify (we don't have GPS handoff for clothing).
-- ============================================================

CREATE TABLE IF NOT EXISTS public.borrow_requests (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  borrower_id       uuid        NOT NULL DEFAULT auth.uid()
                      REFERENCES auth.users(id) ON DELETE CASCADE,
  -- We store owner_id explicitly (rather than derive it through
  -- the wardrobe_items join) so the RLS policy can compare against
  -- auth.uid() in O(1) instead of a sub-select on every row.
  owner_id          uuid        NOT NULL
                      REFERENCES auth.users(id) ON DELETE CASCADE,
  wardrobe_item_id  uuid        NOT NULL
                      REFERENCES public.wardrobe_items(id) ON DELETE CASCADE,
  status            text        NOT NULL DEFAULT 'pending'
                      CHECK (status IN (
                        'pending',
                        'approved',
                        'denied',
                        'active',
                        'returned',
                        'cancelled'
                      )),
  borrow_start      date        NOT NULL,
  borrow_end        date        NOT NULL,
  -- Optional message ("Hey, can I borrow this for the wedding?").
  -- Capped at 280 chars at the client; we let the DB hold up to
  -- 1000 in case the client cap loosens later.
  note              text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CHECK (borrower_id <> owner_id),
  CHECK (borrow_end >= borrow_start),
  CHECK (note IS NULL OR length(note) <= 1000)
);

COMMENT ON TABLE public.borrow_requests IS
  'Borrow lifecycle between two friends — borrower asks owner to lend a wardrobe item for a date range.';

-- Hot paths:
--  • Incoming list (owner opens "Requests" tab):
--      WHERE owner_id = me ORDER BY created_at DESC
--  • Outgoing list (borrower opens their own tab):
--      WHERE borrower_id = me ORDER BY created_at DESC
CREATE INDEX IF NOT EXISTS borrow_requests_owner_idx
  ON public.borrow_requests (owner_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS borrow_requests_borrower_idx
  ON public.borrow_requests (borrower_id, status, created_at DESC);

-- ── updated_at trigger ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.borrow_requests_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS borrow_requests_updated_at_trg
  ON public.borrow_requests;

CREATE TRIGGER borrow_requests_updated_at_trg
BEFORE UPDATE ON public.borrow_requests
FOR EACH ROW
EXECUTE FUNCTION public.borrow_requests_set_updated_at();

-- ── Row-Level Security ────────────────────────────────────────
ALTER TABLE public.borrow_requests ENABLE ROW LEVEL SECURITY;

-- SELECT: either party can read.
DROP POLICY IF EXISTS "borrow_requests_party_select"
  ON public.borrow_requests;
CREATE POLICY "borrow_requests_party_select"
  ON public.borrow_requests FOR SELECT
  USING (auth.uid() IN (borrower_id, owner_id));

-- INSERT: only the borrower, only against an item whose owner is
-- a friend (and the item is_shareable). The friend check happens
-- via is_friend_of(); the is_shareable check is a sub-select so
-- a private item can't be requested even if the user types its
-- id manually.
DROP POLICY IF EXISTS "borrow_requests_borrower_insert"
  ON public.borrow_requests;
CREATE POLICY "borrow_requests_borrower_insert"
  ON public.borrow_requests FOR INSERT
  WITH CHECK (
    auth.uid() = borrower_id
    AND borrower_id <> owner_id
    AND public.is_friend_of(owner_id)
    AND status = 'pending'
    AND EXISTS (
      SELECT 1 FROM public.wardrobe_items wi
      WHERE wi.id = wardrobe_item_id
        AND wi.user_id = owner_id
        AND wi.is_shareable = true
    )
  );

-- UPDATE: owner can move pending → approved/denied; either party
-- can move approved → active/returned; borrower can pending →
-- cancelled. The policy only enforces "you must be a party"; the
-- valid-transition matrix is enforced in the client + server-side
-- via a guard function we may add later.
DROP POLICY IF EXISTS "borrow_requests_party_update"
  ON public.borrow_requests;
CREATE POLICY "borrow_requests_party_update"
  ON public.borrow_requests FOR UPDATE
  USING (auth.uid() IN (borrower_id, owner_id))
  WITH CHECK (auth.uid() IN (borrower_id, owner_id));

-- DELETE: either party (rare — usually you cancel by status
-- transition, not delete — but we keep the door open for cleanup
-- in support tooling).
DROP POLICY IF EXISTS "borrow_requests_party_delete"
  ON public.borrow_requests;
CREATE POLICY "borrow_requests_party_delete"
  ON public.borrow_requests FOR DELETE
  USING (auth.uid() IN (borrower_id, owner_id));
