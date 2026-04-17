-- ============================================================
-- Dynamic Catalog Hierarchy: AppCategory > SubCategory > Product
-- ============================================================
-- Turns the flat `categories` table into a two-level hierarchy:
--   app_categories (Men / Women / Kids)
--     └── categories (Ethnics / Blazers / Suits / Sarees ...)
--           └── products
-- ============================================================

-- ── 1. app_categories (top level) ──
CREATE TABLE IF NOT EXISTS public.app_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  sort_order int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.app_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_categories_public_read" ON public.app_categories;
CREATE POLICY "app_categories_public_read"
  ON public.app_categories FOR SELECT USING (true);

-- Seed top-level categories
INSERT INTO public.app_categories (name, sort_order) VALUES
  ('Men', 1),
  ('Women', 2),
  ('Kids', 3)
ON CONFLICT (name) DO NOTHING;

-- ── 2. Link existing `categories` table to app_categories ──
ALTER TABLE public.categories
  ADD COLUMN IF NOT EXISTS app_category_id uuid
    REFERENCES public.app_categories(id) ON DELETE SET NULL;

-- Assign all existing subcategories to 'Men' by default
UPDATE public.categories
SET app_category_id = (SELECT id FROM public.app_categories WHERE name = 'Men')
WHERE app_category_id IS NULL;

-- ── 3. Seed Women subcategories ──
INSERT INTO public.categories (name, slug, sort_order, app_category_id, image_url) VALUES
  ('Ethnic Suits', 'w-ethnic-suits', 1,
    (SELECT id FROM public.app_categories WHERE name = 'Women'),
    'https://images.unsplash.com/photo-1583391733981-8698e9ec9a99?w=400'),
  ('Sarees', 'sarees', 2,
    (SELECT id FROM public.app_categories WHERE name = 'Women'),
    'https://images.unsplash.com/photo-1610030006630-3a4ac2d63b06?w=400'),
  ('Formal Pants', 'w-formal-pants', 3,
    (SELECT id FROM public.app_categories WHERE name = 'Women'),
    'https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=400'),
  ('Formal Shirts', 'w-formal-shirts', 4,
    (SELECT id FROM public.app_categories WHERE name = 'Women'),
    'https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=400'),
  ('Women Suits', 'w-suits', 5,
    (SELECT id FROM public.app_categories WHERE name = 'Women'),
    'https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=400'),
  ('Women Embroidery', 'w-embroidery', 6,
    (SELECT id FROM public.app_categories WHERE name = 'Women'),
    'https://images.unsplash.com/photo-1606107557195-0e29a4b5b4aa?w=400')
ON CONFLICT (slug) DO NOTHING;

-- ── 4. Seed Kids subcategories ──
INSERT INTO public.categories (name, slug, sort_order, app_category_id, image_url) VALUES
  ('Kids Ethnics', 'k-ethnics', 1,
    (SELECT id FROM public.app_categories WHERE name = 'Kids'),
    'https://images.unsplash.com/photo-1522771930-78848d9293e8?w=400'),
  ('Kids Sherwanis', 'k-sherwanis', 2,
    (SELECT id FROM public.app_categories WHERE name = 'Kids'),
    'https://images.unsplash.com/photo-1549298916-b41d501d3772?w=400'),
  ('Kids Blazers', 'k-blazers', 3,
    (SELECT id FROM public.app_categories WHERE name = 'Kids'),
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400'),
  ('Kids Suits', 'k-suits', 4,
    (SELECT id FROM public.app_categories WHERE name = 'Kids'),
    'https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=400'),
  ('Kids Formal Shirts', 'k-formal-shirts', 5,
    (SELECT id FROM public.app_categories WHERE name = 'Kids'),
    'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=400'),
  ('Kids Formal Pants', 'k-formal-pants', 6,
    (SELECT id FROM public.app_categories WHERE name = 'Kids'),
    'https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=400'),
  ('Kids Embroidery', 'k-embroidery', 7,
    (SELECT id FROM public.app_categories WHERE name = 'Kids'),
    'https://images.unsplash.com/photo-1606107557195-0e29a4b5b4aa?w=400')
ON CONFLICT (slug) DO NOTHING;

-- ── 5. Seed Men subcategory images (update existing) ──
UPDATE public.categories SET image_url = CASE slug
  WHEN 'shirts'     THEN 'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=400'
  WHEN 'trousers'   THEN 'https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=400'
  WHEN 'suits'      THEN 'https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=400'
  WHEN 'kurtas'     THEN 'https://images.unsplash.com/photo-1606107557195-0e29a4b5b4aa?w=400'
  WHEN 'sherwanis'  THEN 'https://images.unsplash.com/photo-1549298916-b41d501d3772?w=400'
  WHEN 'blazers'    THEN 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400'
  ELSE image_url
END
WHERE slug IN ('shirts','trousers','suits','kurtas','sherwanis','blazers');

-- ── 6. Seed women + kids products for testing ──
-- Women: one product per subcategory
INSERT INTO public.products (category_id, name, description, base_price, fabric_options, images, is_featured, gender) VALUES
  ((SELECT id FROM public.categories WHERE slug = 'w-ethnic-suits'),
    'Anarkali Silk Suit', 'Hand-embroidered anarkali in flowing silk.', 7499.00,
    '{"Silk","Georgette","Chanderi"}',
    '{"https://images.unsplash.com/photo-1583391733981-8698e9ec9a99?w=800"}',
    true, 'women'),
  ((SELECT id FROM public.categories WHERE slug = 'sarees'),
    'Banarasi Silk Saree', 'Traditional Banarasi with gold zari work.', 9999.00,
    '{"Banarasi Silk","Art Silk"}',
    '{"https://images.unsplash.com/photo-1610030006630-3a4ac2d63b06?w=800"}',
    true, 'women'),
  ((SELECT id FROM public.categories WHERE slug = 'w-formal-shirts'),
    'Silk Formal Blouse', 'Classic tailored blouse for office wear.', 2499.00,
    '{"Silk","Cotton Poplin"}',
    '{"https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=800"}',
    false, 'women'),
  ((SELECT id FROM public.categories WHERE slug = 'w-suits'),
    'Pantsuit Two-Piece', 'Sharp two-piece pantsuit for the boardroom.', 8999.00,
    '{"Wool Blend","Poly-Viscose"}',
    '{"https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=800"}',
    false, 'women')
ON CONFLICT DO NOTHING;

-- Kids: one product per main subcategory
INSERT INTO public.products (category_id, name, description, base_price, fabric_options, images, is_featured, gender) VALUES
  ((SELECT id FROM public.categories WHERE slug = 'k-sherwanis'),
    'Kids Wedding Sherwani', 'Miniature sherwani for the little prince.', 4999.00,
    '{"Jacquard Silk","Brocade"}',
    '{"https://images.unsplash.com/photo-1549298916-b41d501d3772?w=800"}',
    true, 'kids'),
  ((SELECT id FROM public.categories WHERE slug = 'k-blazers'),
    'Kids Classic Blazer', 'Tailored blazer in soft merino.', 2999.00,
    '{"Merino Wool","Cotton Twill"}',
    '{"https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800"}',
    false, 'kids'),
  ((SELECT id FROM public.categories WHERE slug = 'k-formal-shirts'),
    'Kids Oxford Shirt', 'Crisp Oxford weave for kids.', 1499.00,
    '{"Cotton Oxford","Supima Cotton"}',
    '{"https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=800"}',
    true, 'kids')
ON CONFLICT DO NOTHING;

-- ── 7. Convenience: add main_image_url virtual view (use images[1]) ──
-- No schema change — Flutter picks images[0] as main.
