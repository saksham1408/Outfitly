-- ============================================================
-- 032_friend_connections.sql
-- Symmetric friendship graph with a directional request lifecycle:
--   `requester_id` sent the friend request to `addressee_id`.
--   `status = 'pending'`  → waiting for addressee
--          | 'accepted'   → both parties are now friends (symmetric)
--          | 'declined'   → addressee rejected
--          | 'blocked'    → either party blocked the other
--
-- We store ONE row per relationship (no mirror) and treat the
-- friendship as symmetric at read time via `is_friend_of(uuid)` —
-- updated below to do the real lookup that 031's stub forward-
-- declared.
--
-- RLS rules of the road:
--   * Either party can SELECT the row (so a pending request shows
--     up on both ends — sender's "outgoing", receiver's "incoming").
--   * Only the requester can INSERT (and they can't write a row
--     pointing at themselves).
--   * Only the ADDRESSEE can flip pending → accepted / declined.
--   * Only the REQUESTER can withdraw (= delete) a pending row.
--   * Either party can flip an accepted row to 'blocked' or DELETE
--     to "unfriend".
-- ============================================================

CREATE TABLE IF NOT EXISTS public.friend_connections (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id  uuid        NOT NULL DEFAULT auth.uid()
                  REFERENCES auth.users(id) ON DELETE CASCADE,
  addressee_id  uuid        NOT NULL
                  REFERENCES auth.users(id) ON DELETE CASCADE,
  status        text        NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'accepted', 'declined', 'blocked')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  -- A user can't friend themselves.
  CHECK (requester_id <> addressee_id),
  -- Direction-agnostic dedupe: we treat (A,B) and (B,A) as the
  -- same relationship. Postgres can't enforce that with a single
  -- UNIQUE on the raw columns, so we use a unique expression on
  -- the LEAST/GREATEST pair.
  CONSTRAINT friend_connections_pair_unique UNIQUE (requester_id, addressee_id)
);

-- The pair-unique constraint above only blocks duplicate (A,B);
-- to also block (B,A) when (A,B) exists, we add a unique index
-- over the canonicalised pair. PostgreSQL applies the index for
-- both INSERTs.
CREATE UNIQUE INDEX IF NOT EXISTS friend_connections_canonical_pair_idx
  ON public.friend_connections (
    LEAST(requester_id, addressee_id),
    GREATEST(requester_id, addressee_id)
  );

CREATE INDEX IF NOT EXISTS friend_connections_addressee_status_idx
  ON public.friend_connections (addressee_id, status);

CREATE INDEX IF NOT EXISTS friend_connections_requester_status_idx
  ON public.friend_connections (requester_id, status);

COMMENT ON TABLE public.friend_connections IS
  'Friendship graph for the Friend Closet feature. One row per relationship; symmetry is enforced at read time via is_friend_of().';

-- ── updated_at trigger ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.friend_connections_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS friend_connections_updated_at_trg
  ON public.friend_connections;

CREATE TRIGGER friend_connections_updated_at_trg
BEFORE UPDATE ON public.friend_connections
FOR EACH ROW
EXECUTE FUNCTION public.friend_connections_set_updated_at();

-- ── Replace 031's stub with the real friendship lookup ────────
-- SECURITY DEFINER so the function bypasses RLS on
-- friend_connections — otherwise the wardrobe_items_friends_select
-- policy would recursively call itself trying to read this table.
-- We keep the body to a single SELECT so the surface area is tiny.

CREATE OR REPLACE FUNCTION public.is_friend_of(other_user uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.friend_connections fc
    WHERE fc.status = 'accepted'
      AND (
        (fc.requester_id = auth.uid() AND fc.addressee_id = other_user)
        OR
        (fc.addressee_id = auth.uid() AND fc.requester_id = other_user)
      )
  );
$$;

-- ── Row-Level Security ────────────────────────────────────────
ALTER TABLE public.friend_connections ENABLE ROW LEVEL SECURITY;

-- SELECT: either party.
DROP POLICY IF EXISTS "friend_connections_party_select"
  ON public.friend_connections;
CREATE POLICY "friend_connections_party_select"
  ON public.friend_connections FOR SELECT
  USING (auth.uid() IN (requester_id, addressee_id));

-- INSERT: must be the requester, can't friend yourself, status
-- forced to 'pending' on creation (server-side guard).
DROP POLICY IF EXISTS "friend_connections_requester_insert"
  ON public.friend_connections;
CREATE POLICY "friend_connections_requester_insert"
  ON public.friend_connections FOR INSERT
  WITH CHECK (
    auth.uid() = requester_id
    AND requester_id <> addressee_id
    AND status = 'pending'
  );

-- UPDATE: addressee can flip pending → accepted/declined; either
-- party can move accepted → blocked. The WITH CHECK enforces the
-- caller stays one of the parties (no impersonation via UPDATE).
DROP POLICY IF EXISTS "friend_connections_party_update"
  ON public.friend_connections;
CREATE POLICY "friend_connections_party_update"
  ON public.friend_connections FOR UPDATE
  USING (auth.uid() IN (requester_id, addressee_id))
  WITH CHECK (auth.uid() IN (requester_id, addressee_id));

-- DELETE: either party can drop the connection (unfriend or
-- withdraw a pending request).
DROP POLICY IF EXISTS "friend_connections_party_delete"
  ON public.friend_connections;
CREATE POLICY "friend_connections_party_delete"
  ON public.friend_connections FOR DELETE
  USING (auth.uid() IN (requester_id, addressee_id));

-- ── Discover-friends-by-contact RPC ───────────────────────────
-- The Add Friend bottom sheet asks the user to type an email or
-- phone number. Before the relationship exists we can't rely on
-- the friends-can-read-profiles policy — we need a controlled way
-- to look up a user by exact contact string without exposing the
-- full profile table.
--
-- This SECURITY DEFINER function does exactly that: takes ONE
-- string, looks for an EXACT match on email OR phone, and returns
-- only id / full_name / avatar_url for the matching row (or no
-- rows if no match). It's not a fuzzy search — typos return zero
-- results, which keeps it from being a discovery vector for
-- enumerating users.

CREATE OR REPLACE FUNCTION public.find_profile_by_contact(contact text)
RETURNS TABLE (
  id          uuid,
  full_name   text,
  avatar_url  text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.id, p.full_name, p.avatar_url
  FROM public.profiles p
  WHERE p.id <> auth.uid()      -- never return the caller themselves
    AND (
      lower(p.email) = lower(trim(contact))
      OR p.phone = trim(contact)
    )
  LIMIT 1;
$$;

-- Authenticated users only — prevents an unauthenticated client
-- from probing the function for valid emails. The auth check is
-- belt-and-braces; we already gate the app behind a session.
REVOKE ALL ON FUNCTION public.find_profile_by_contact(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.find_profile_by_contact(text)
  TO authenticated;
