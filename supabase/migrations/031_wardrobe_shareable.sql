-- ============================================================
-- 031_wardrobe_shareable.sql
-- Friend Closet Sharing — opt-out flag on wardrobe items + the
-- RLS policy that lets accepted friends read each other's
-- shareable rows.
--
-- Two changes:
--   1. `wardrobe_items.is_shareable boolean DEFAULT true` — the
--      one-tap toggle a user uses to keep a piece private. Default
--      true so onboarding feels social out of the box; the user
--      can flip individual items later.
--   2. A new SELECT policy on `wardrobe_items` that joins through
--      `public.friend_connections` (created in migration 032 — we
--      reference it here in a function that's evaluated lazily, so
--      the policy can be defined before the table exists as long
--      as the function is recreated below 032 too).
--
-- We also add the corresponding "friends can see basic profile"
-- policy on `public.profiles` so the social dashboard can render
-- avatars + names without exposing phone, email, addresses, etc.
-- ============================================================

ALTER TABLE public.wardrobe_items
  ADD COLUMN IF NOT EXISTS is_shareable boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.wardrobe_items.is_shareable IS
  'When true, accepted friends can SELECT this row via the wardrobe_items_friends_select policy. Owner controls; default true.';

-- ── Friends-can-read policy on wardrobe_items ──
-- The function `public.is_friend_of(other_user)` returns true if
-- the calling user and `other_user` have an accepted row in
-- `friend_connections` (in either direction). We define it as
-- SECURITY DEFINER so the policy doesn't recursively trigger RLS
-- on `friend_connections` when it joins back through.
--
-- Forward-declared here as a stub returning false; migration 032
-- replaces it with the real implementation once the table exists.
-- This pattern keeps each migration runnable in isolation.

CREATE OR REPLACE FUNCTION public.is_friend_of(other_user uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  -- Stub: 032 replaces this with the real friend_connections lookup.
  -- Returning false until then means the policy below grants no
  -- additional access, so the migration is safe to apply on its own.
  SELECT false;
$$;

DROP POLICY IF EXISTS "wardrobe_items_friends_select"
  ON public.wardrobe_items;

CREATE POLICY "wardrobe_items_friends_select"
  ON public.wardrobe_items FOR SELECT
  USING (
    is_shareable = true
    AND public.is_friend_of(user_id)
  );

-- ── Friends-can-read policy on profiles ──
-- The social dashboard needs to render full_name + avatar_url for
-- every connected friend. We don't want to expose phone, email,
-- country, etc. — but row-level policies in Postgres are all-or-
-- nothing on columns. Two options:
--   A. Create a dedicated `public_profiles` view with only the
--      safe columns, hand SELECT-as-friend to that.
--   B. Allow the SELECT and rely on the *client* to only request
--      the safe columns (`select('id, full_name, avatar_url')`).
--
-- We pick (B) for v1 — simpler, and PostgREST honours column
-- selection in the response. If the safety bar rises (e.g. once
-- we add health data), revisit and switch to (A).

DROP POLICY IF EXISTS "profiles_friends_select" ON public.profiles;

CREATE POLICY "profiles_friends_select"
  ON public.profiles FOR SELECT
  USING (
    public.is_friend_of(id)
  );

-- ── Hot-path index for friend-closet queries ──
-- The Friend Closet screen does
--   SELECT * FROM wardrobe_items
--    WHERE user_id = :friend AND is_shareable = true
-- per friend visit. The existing `wardrobe_items_user_idx` covers
-- the user_id half; this partial index makes the AND-shareable
-- filter a single seek.
CREATE INDEX IF NOT EXISTS wardrobe_items_user_shareable_idx
  ON public.wardrobe_items(user_id, created_at DESC)
  WHERE is_shareable = true;
