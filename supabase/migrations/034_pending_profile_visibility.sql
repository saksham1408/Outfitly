-- ============================================================
-- 034_pending_profile_visibility.sql
-- Loosen the friends-can-read-profile policy so users with a
-- *pending* connection can also read each other's basic profile
-- (full_name + avatar_url). Without this, the Incoming Request
-- gold strip can't render the requester's name on the addressee's
-- side — PostgREST embeds silently null-out and the dashboard
-- sees zero rows.
--
-- We keep the original is_friend_of(uuid) function unchanged
-- (still accepted-only) because it gates wardrobe_items reads:
-- a pending friend should NOT see your closet, only your name.
-- A new sister function `has_friend_connection_with(uuid)` covers
-- the looser "pending OR accepted" check used only for profiles.
-- ============================================================

CREATE OR REPLACE FUNCTION public.has_friend_connection_with(other_user uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.friend_connections fc
    WHERE fc.status IN ('pending', 'accepted')
      AND (
        (fc.requester_id = auth.uid() AND fc.addressee_id = other_user)
        OR
        (fc.addressee_id = auth.uid() AND fc.requester_id = other_user)
      )
  );
$$;

-- Replace the accepted-only policy with the pending-or-accepted one.
DROP POLICY IF EXISTS "profiles_friends_select" ON public.profiles;

CREATE POLICY "profiles_friends_select"
  ON public.profiles FOR SELECT
  USING (public.has_friend_connection_with(id));
