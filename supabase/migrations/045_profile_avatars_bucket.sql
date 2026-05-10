-- ============================================================
-- 045_profile_avatars_bucket.sql
-- Storage bucket for user avatars uploaded from the new Edit
-- Profile screen.
--
-- Same folder-scoped RLS pattern the existing `user_wardrobe`
-- and `custom_stitch_refs` buckets use: writes are allowed only
-- under `${auth.uid()}/...` so a tampered client can never
-- upload into someone else's folder; reads are public so the
-- avatar can be rendered with a plain Image.network without
-- signing the URL.
--
-- This migration only touches Storage; the `profiles.avatar_url`
-- column already exists since migration 001.
-- ============================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- ── Storage RLS ───────────────────────────────────────────
DROP POLICY IF EXISTS "avatars_public_read" ON storage.objects;
CREATE POLICY "avatars_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatars_own_insert" ON storage.objects;
CREATE POLICY "avatars_own_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "avatars_own_update" ON storage.objects;
CREATE POLICY "avatars_own_update"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "avatars_own_delete" ON storage.objects;
CREATE POLICY "avatars_own_delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
