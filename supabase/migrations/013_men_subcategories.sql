-- ============================================================
-- Add missing Men subcategories to match the static list:
-- Ethnics, Sherwanis, Blazers, Suits, Formal Shirts, Formal Pants, Embroidery
-- (Shirts, Trousers, Kurtas already exist — we keep them too.)
-- ============================================================

INSERT INTO public.categories (name, slug, sort_order, app_category_id, image_url) VALUES
  ('Ethnics', 'm-ethnics', 10,
    (SELECT id FROM public.app_categories WHERE name = 'Men'),
    'https://images.unsplash.com/photo-1606107557195-0e29a4b5b4aa?w=400'),
  ('Formal Shirts', 'm-formal-shirts', 11,
    (SELECT id FROM public.app_categories WHERE name = 'Men'),
    'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=400'),
  ('Formal Pants', 'm-formal-pants', 12,
    (SELECT id FROM public.app_categories WHERE name = 'Men'),
    'https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=400'),
  ('Embroidery', 'm-embroidery', 13,
    (SELECT id FROM public.app_categories WHERE name = 'Men'),
    'https://images.unsplash.com/photo-1558171813-4c088753af8f?w=400')
ON CONFLICT (slug) DO NOTHING;
