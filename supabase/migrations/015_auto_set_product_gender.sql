-- ============================================================
-- Auto-set products.gender from the selected subcategory's parent
-- (so admin doesn't need to manage the gender field manually).
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_product_gender()
RETURNS trigger AS $$
DECLARE
  parent_name text;
BEGIN
  IF NEW.category_id IS NOT NULL THEN
    SELECT lower(ac.name)
      INTO parent_name
      FROM public.categories c
      JOIN public.app_categories ac ON ac.id = c.app_category_id
      WHERE c.id = NEW.category_id;

    IF parent_name IS NOT NULL THEN
      NEW.gender := parent_name; -- 'men' / 'women' / 'kids'
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_product_gender ON public.products;

CREATE TRIGGER trg_set_product_gender
  BEFORE INSERT OR UPDATE OF category_id ON public.products
  FOR EACH ROW
  EXECUTE FUNCTION public.set_product_gender();

-- Also fix any existing products where gender doesn't match their category's parent
UPDATE public.products p
SET gender = lower(ac.name)
FROM public.categories c
JOIN public.app_categories ac ON ac.id = c.app_category_id
WHERE p.category_id = c.id
  AND p.gender IS DISTINCT FROM lower(ac.name);
