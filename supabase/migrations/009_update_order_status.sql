-- Add pending_admin_approval and accepted to valid order statuses
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_status_check
  CHECK (status IN (
    'pending_admin_approval',
    'accepted',
    'order_placed',
    'fabric_sourcing',
    'cutting',
    'stitching',
    'embroidery_finishing',
    'quality_check',
    'out_for_delivery',
    'delivered',
    'cancelled'
  ));
