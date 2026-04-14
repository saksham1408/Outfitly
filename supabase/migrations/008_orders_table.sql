-- ============================================================
-- Outfitly: Orders table with tracking stages
-- ============================================================

CREATE TABLE IF NOT EXISTS public.orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  product_name text NOT NULL,
  fabric text,
  design_choices jsonb DEFAULT '{}',
  total_price numeric(10,2) NOT NULL,
  status text NOT NULL DEFAULT 'order_placed'
    CHECK (status IN ('order_placed','fabric_sourcing','cutting','stitching','embroidery_finishing','quality_check','out_for_delivery','delivered')),
  estimated_delivery date,
  tracking_note text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own orders" ON public.orders FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own orders" ON public.orders FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own orders" ON public.orders FOR UPDATE USING (auth.uid() = user_id);
