-- ============================================================
-- Add gender tag to products for Myntra-style segmentation
-- ============================================================

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS gender text DEFAULT 'all'
  CHECK (gender IN ('all', 'men', 'women', 'kids'));

-- Seed existing products with gender tags based on category slugs
UPDATE public.products p
SET gender = CASE
  WHEN c.slug IN ('suits', 'trousers', 'blazers') THEN 'men'
  WHEN c.slug IN ('sherwanis', 'kurtas') THEN 'men'
  WHEN c.slug = 'shirts' THEN 'men'
  ELSE 'all'
END
FROM public.categories c
WHERE p.category_id = c.id;

-- Distribute some products to women/kids for variety
UPDATE public.products SET gender = 'women'
WHERE name IN ('Lucknowi Chikan Kurta', 'Silk Festive Kurta');

UPDATE public.products SET gender = 'women'
WHERE name = 'Linen Casual Shirt';
