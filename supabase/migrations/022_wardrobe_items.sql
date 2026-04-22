-- ============================================================
-- 022_wardrobe_items.sql
-- Personal Digital Wardrobe — users upload photos of their own
-- clothes (Top / Bottom / Shoes / Accessory) and the Daily AI
-- Stylist reads this inventory to suggest outfits from clothes
-- the user actually owns.
--
-- Two halves:
--   1. The `public.wardrobe_items` row (id, image url, category,
--      color, style) with own-row RLS.
--   2. The `user_wardrobe` Storage bucket + RLS policies so the
--      image binary lives next to the row it belongs to.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.wardrobe_items (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Same auth.uid() default pattern as planner_events / user_addresses
  -- so the client never has to send user_id (and therefore can't spoof
  -- it — the `_own_insert` RLS re-asserts the match anyway).
  user_id     uuid NOT NULL DEFAULT auth.uid()
                REFERENCES auth.users(id) ON DELETE CASCADE,
  image_url   text NOT NULL,
  -- Four broad buckets keep the Gemini prompt (and the UI) simple.
  -- Kept as text + CHECK instead of an enum because Supabase's
  -- PostgREST surfaces enums awkwardly.
  category    text NOT NULL
                CHECK (category IN ('Top', 'Bottom', 'Shoes', 'Accessory')),
  color       text NOT NULL,
  -- Casual / Formal / Party — the stylist uses this to skew its
  -- pick toward the requested occasion.
  style_type  text NOT NULL
                CHECK (style_type IN ('Casual', 'Formal', 'Party')),
  created_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.wardrobe_items IS
  'User-uploaded clothing items that feed the Daily AI Stylist. One row per garment; the image lives in the user_wardrobe Storage bucket.';

CREATE INDEX IF NOT EXISTS wardrobe_items_user_idx
  ON public.wardrobe_items(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS wardrobe_items_user_category_idx
  ON public.wardrobe_items(user_id, category);

-- ── Row-Level Security ─────────────────────────────────────
ALTER TABLE public.wardrobe_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wardrobe_items_own_select" ON public.wardrobe_items;
CREATE POLICY "wardrobe_items_own_select"
  ON public.wardrobe_items FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "wardrobe_items_own_insert" ON public.wardrobe_items;
CREATE POLICY "wardrobe_items_own_insert"
  ON public.wardrobe_items FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "wardrobe_items_own_update" ON public.wardrobe_items;
CREATE POLICY "wardrobe_items_own_update"
  ON public.wardrobe_items FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "wardrobe_items_own_delete" ON public.wardrobe_items;
CREATE POLICY "wardrobe_items_own_delete"
  ON public.wardrobe_items FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- Storage bucket: user_wardrobe
-- Public-read (so <Image.network(publicUrl)> just works without
-- signing) but writes are scoped to `${auth.uid()}/filename` so
-- a user can only ever upload or delete under their own folder.
-- ============================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('user_wardrobe', 'user_wardrobe', true)
ON CONFLICT (id) DO NOTHING;

-- ── Storage RLS ────────────────────────────────────────────
-- The folder-name pattern is the Supabase-idiomatic way to enforce
-- "this user owns this object": the first path segment must be the
-- caller's uid, and storage.foldername() exposes that segment to
-- the policy.

DROP POLICY IF EXISTS "user_wardrobe_public_read" ON storage.objects;
CREATE POLICY "user_wardrobe_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'user_wardrobe');

DROP POLICY IF EXISTS "user_wardrobe_own_insert" ON storage.objects;
CREATE POLICY "user_wardrobe_own_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'user_wardrobe'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "user_wardrobe_own_update" ON storage.objects;
CREATE POLICY "user_wardrobe_own_update"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'user_wardrobe'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "user_wardrobe_own_delete" ON storage.objects;
CREATE POLICY "user_wardrobe_own_delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'user_wardrobe'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
