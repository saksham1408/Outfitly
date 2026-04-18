-- ============================================================
-- 016_custom_embroidery.sql
-- Adds the custom_embroidery_url column to orders so Directus can
-- read user-uploaded reference images as a first-class field, and
-- seeds demo products into the Embroidery subcategories (m/w/k)
-- so the app has something to route through the Design Studio.
-- ============================================================

-- 1. Column on orders for the uploaded reference URL -----------
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS custom_embroidery_url text;

COMMENT ON COLUMN public.orders.custom_embroidery_url IS
  'Public URL of the user-uploaded reference image attached during Design Studio (Embroidery products only).';

-- 2. Ensure products.category_id has an FK to categories so the
--    Supabase PostgREST join syntax (`*, categories(slug, name)`)
--    works from the Flutter client. ----------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints tc
    WHERE tc.table_name = 'products'
      AND tc.constraint_type = 'FOREIGN KEY'
      AND tc.constraint_name = 'products_category_id_fkey'
  ) THEN
    ALTER TABLE public.products
      ADD CONSTRAINT products_category_id_fkey
      FOREIGN KEY (category_id)
      REFERENCES public.categories(id)
      ON DELETE SET NULL;
  END IF;
END$$;

-- 3. Seed demo products into Embroidery subcategories ----------
-- fabric_options / images are jsonb (see 012_products_array_to_jsonb.sql)
INSERT INTO public.products
  (category_id, name, description, base_price, fabric_options, is_featured, images)
SELECT
  c.id,
  v.name,
  v.description,
  v.base_price,
  v.fabrics::jsonb,
  true,
  '[]'::jsonb
FROM (VALUES
  ('m-embroidery',
   'Custom Embroidered Kurta',
   'Upload your own design — we embroider it by hand in pure silk thread.',
   4999.00,
   '["Cotton Voile","Georgette","Raw Silk","Modal Silk"]'),
  ('w-embroidery',
   'Bespoke Embroidered Dupatta',
   'Your monogram, motif, or artwork — hand-stitched on Chanderi silk.',
   3499.00,
   '["Chanderi Silk","Georgette","Cotton Mul"]'),
  ('k-embroidery',
   'Kids Custom Name Kurta',
   'Personalised with your child''s name, initials, or a motif of your choice.',
   2299.00,
   '["Cotton Voile","Mulmul","Linen Blend"]')
) AS v(slug, name, description, base_price, fabrics)
JOIN public.categories c ON c.slug = v.slug
WHERE NOT EXISTS (
  SELECT 1 FROM public.products p
  WHERE p.category_id = c.id AND p.name = v.name
);
