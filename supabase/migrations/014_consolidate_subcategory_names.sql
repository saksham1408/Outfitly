-- ============================================================
-- Clean up subcategory names so they're simple shared types:
--   Ethnics, Sherwanis, Blazers, Suits, Formal Shirts, Formal Pants,
--   Embroidery, Sarees, Ethnic Suits, Kurtas, Shirts, Trousers
-- The "Men/Women/Kids" grouping comes from app_category_id
-- ============================================================

-- Women: strip "Women" prefix and "W" prefixes from slugs / names
UPDATE public.categories SET name = 'Embroidery'
  WHERE slug = 'w-embroidery';

UPDATE public.categories SET name = 'Suits'
  WHERE slug = 'w-suits' AND name = 'Women Suits';

-- Kids: strip "Kids" prefix from names
UPDATE public.categories SET name = 'Ethnics'          WHERE slug = 'k-ethnics';
UPDATE public.categories SET name = 'Sherwanis'        WHERE slug = 'k-sherwanis';
UPDATE public.categories SET name = 'Blazers'          WHERE slug = 'k-blazers';
UPDATE public.categories SET name = 'Suits'            WHERE slug = 'k-suits';
UPDATE public.categories SET name = 'Formal Shirts'    WHERE slug = 'k-formal-shirts';
UPDATE public.categories SET name = 'Formal Pants'     WHERE slug = 'k-formal-pants';
UPDATE public.categories SET name = 'Embroidery'       WHERE slug = 'k-embroidery';
