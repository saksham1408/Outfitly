-- ============================================================
-- 044_cart_items.sql
-- Multi-item shopping cart (the bag).
--
-- The legacy `cart_screen` takes an OrderPayload and reviews ONE
-- customised order in flight (the customisation-wizard endpoint).
-- That flow stays untouched. This migration adds the persistent
-- multi-item bag a customer fills from the PDP "Add to Bag" CTA
-- — same model used by Myntra, Nykaa, Amazon, etc.
--
-- Denormalised product fields (name, image, price) are stored at
-- the moment the customer adds the item — so a price change on
-- the catalog row doesn't silently mutate everyone's cart, and
-- the bag still renders even if the underlying product is later
-- soft-deleted.
--
-- This migration also adds `wishlist` to the supabase_realtime
-- publication so the WishlistRepository can subscribe and the
-- home AppBar's heart badge stays in sync across devices.
-- ============================================================

-- ── 1. cart_items table ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.cart_items (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- auth.uid() default mirrors every other own-row table; the
  -- INSERT policy re-asserts the match.
  user_id       uuid        NOT NULL DEFAULT auth.uid()
                            REFERENCES auth.users(id) ON DELETE CASCADE,
  -- We don't FK to products.id so the bag survives a soft-deleted
  -- product. The denormalised columns below carry the display
  -- info the cart needs without a join.
  product_id    text        NOT NULL,
  product_name  text        NOT NULL,
  product_image text,
  product_price numeric(10,2) NOT NULL CHECK (product_price >= 0),
  quantity      smallint    NOT NULL DEFAULT 1
                            CHECK (quantity BETWEEN 1 AND 99),
  -- Optional customisation fields the customer set on the PDP
  -- before adding (mostly null today; the customisation wizard
  -- still routes through the express-checkout path).
  fabric        text,
  size          text,
  added_at      timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.cart_items IS
  'Multi-item shopping bag. One row per (product, customisation) pair the customer has saved for checkout.';

-- Hot path: customer cart screen reads
--   `WHERE user_id = auth.uid() ORDER BY added_at DESC`.
CREATE INDEX IF NOT EXISTS cart_items_user_idx
  ON public.cart_items (user_id, added_at DESC);

-- Convenience: dedupe scan when the same product is added twice
-- with the same customisation (we bump quantity instead of
-- inserting a duplicate row — see CartRepository.addToCart).
CREATE INDEX IF NOT EXISTS cart_items_user_product_idx
  ON public.cart_items (user_id, product_id);

-- ── 2. RLS ──────────────────────────────────────────────────
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "cart_items_owner_select" ON public.cart_items;
CREATE POLICY "cart_items_owner_select"
  ON public.cart_items FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "cart_items_owner_insert" ON public.cart_items;
CREATE POLICY "cart_items_owner_insert"
  ON public.cart_items FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "cart_items_owner_update" ON public.cart_items;
CREATE POLICY "cart_items_owner_update"
  ON public.cart_items FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "cart_items_owner_delete" ON public.cart_items;
CREATE POLICY "cart_items_owner_delete"
  ON public.cart_items FOR DELETE
  USING (auth.uid() = user_id);

-- ── 3. updated_at trigger ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.cart_items_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS cart_items_touch_updated_at ON public.cart_items;
CREATE TRIGGER cart_items_touch_updated_at
  BEFORE UPDATE ON public.cart_items
  FOR EACH ROW EXECUTE FUNCTION public.cart_items_touch_updated_at();

-- ── 4. Realtime ─────────────────────────────────────────────
-- Cart count badge subscribes; same for wishlist (added below).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'cart_items'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime
             ADD TABLE public.cart_items';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'wishlist'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime
             ADD TABLE public.wishlist';
  END IF;
END $$;
