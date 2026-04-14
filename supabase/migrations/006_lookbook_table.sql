-- ============================================================
-- Outfitly: Lookbook items table (managed by Directus CMS)
-- Run this in Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS public.lookbook_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  price numeric(10,2) NOT NULL,
  fabric_type text,
  image_url text,
  colors text[] DEFAULT '{}',
  category text,
  is_published boolean DEFAULT true,
  sort_order int DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.lookbook_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Lookbook items are publicly readable"
  ON public.lookbook_items FOR SELECT
  USING (is_published = true);

-- ── Seed Data: Fabric Collection ──
INSERT INTO public.lookbook_items (name, description, price, fabric_type, image_url, colors, category, sort_order) VALUES
  ('Royal Banarasi Silk', 'Hand-woven Banarasi silk with intricate zari work. A timeless fabric for weddings and grand celebrations.', 8999.00, 'Silk', 'https://images.unsplash.com/photo-1558171813-4c088753af8f?w=800', '{"Gold","Maroon","Navy","Emerald"}', 'Premium', 1),
  ('Italian Linen Blend', 'Lightweight Italian linen blended with cotton for the perfect summer drape. Breathable and effortlessly elegant.', 4599.00, 'Linen', 'https://images.unsplash.com/photo-1620799140408-edc6dcb6d633?w=800', '{"White","Sky Blue","Beige","Olive"}', 'Summer', 2),
  ('Supima Cotton Oxford', 'Premium long-staple Supima cotton with a crisp Oxford weave. The foundation of every gentleman''s wardrobe.', 2999.00, 'Cotton', 'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=800', '{"White","Light Blue","Pink","Lavender"}', 'Everyday', 3),
  ('Merino Wool Tweed', 'Soft Australian merino wool in a classic herringbone tweed. Perfect for blazers and winter suiting.', 7499.00, 'Wool', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800', '{"Charcoal","Brown","Forest Green","Navy"}', 'Winter', 4),
  ('Chanderi Silk Cotton', 'Handloom Chanderi fabric with gold-silver buttis. Light as air, rich in heritage.', 5499.00, 'Silk Cotton', 'https://images.unsplash.com/photo-1606107557195-0e29a4b5b4aa?w=800', '{"Ivory","Peach","Mint","Powder Blue"}', 'Festive', 5),
  ('Japanese Chambray', 'Selvedge chambray from Okayama mills. Develops beautiful character with every wear.', 3799.00, 'Cotton', 'https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=800', '{"Indigo","Light Wash","Dark Wash"}', 'Casual', 6),
  ('Pure Khadi Handspun', 'Authentic hand-spun khadi with natural texture. Supporting Indian artisan communities.', 2499.00, 'Khadi', 'https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=800', '{"Natural","Off White","Earthy Brown","Slate"}', 'Heritage', 7),
  ('Velvet Brocade', 'Luxurious velvet brocade with traditional motifs. For sherwanis and statement pieces.', 12999.00, 'Velvet', 'https://images.unsplash.com/photo-1549298916-b41d501d3772?w=800', '{"Royal Blue","Burgundy","Black","Deep Purple"}', 'Premium', 8);
