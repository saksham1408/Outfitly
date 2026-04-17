-- ============================================================
-- Convert products.fabric_options + products.images from text[] to jsonb
-- This lets Directus insert values as JSON arrays without the
-- "malformed array literal" error.
-- ============================================================

-- fabric_options: text[] → jsonb
ALTER TABLE public.products
  ALTER COLUMN fabric_options DROP DEFAULT;

ALTER TABLE public.products
  ALTER COLUMN fabric_options TYPE jsonb
  USING to_jsonb(fabric_options);

ALTER TABLE public.products
  ALTER COLUMN fabric_options SET DEFAULT '[]'::jsonb;

-- images: text[] → jsonb
ALTER TABLE public.products
  ALTER COLUMN images DROP DEFAULT;

ALTER TABLE public.products
  ALTER COLUMN images TYPE jsonb
  USING to_jsonb(images);

ALTER TABLE public.products
  ALTER COLUMN images SET DEFAULT '[]'::jsonb;

-- Do the same for lookbook_items (colors is already text[], and so was images earlier)
ALTER TABLE public.lookbook_items
  ALTER COLUMN colors DROP DEFAULT;

ALTER TABLE public.lookbook_items
  ALTER COLUMN colors TYPE jsonb
  USING to_jsonb(colors);

ALTER TABLE public.lookbook_items
  ALTER COLUMN colors SET DEFAULT '[]'::jsonb;
