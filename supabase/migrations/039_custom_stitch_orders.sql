-- ============================================================
-- 039_custom_stitch_orders.sql
-- "Stitch My Fabric" — a customer who already owns unstitched
-- fabric books a tailor visit to (a) take measurements and
-- (b) collect the fabric for stitching. Tracked separately
-- from `public.orders` (catalog purchases) and
-- `public.tailor_appointments` (the bespoke-design flow) so
-- the customer's "Stitch My Fabric" dashboard never bleeds
-- into the standard order tracker.
--
-- Two halves:
--   1. `public.custom_stitch_orders` row (one per booking).
--   2. `custom_stitch_refs` Storage bucket for the optional
--      reference-design image the customer uploads so the
--      tailor knows the desired silhouette.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.custom_stitch_orders (
  id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Default to auth.uid() so the client-side insert never has
  -- to send user_id (and therefore can't spoof it). The RLS
  -- INSERT policy below re-asserts the match on top.
  user_id              uuid        NOT NULL DEFAULT auth.uid()
                                   REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Assigned by the atelier dispatch desk after the row lands —
  -- nullable on insert. SET NULL on delete so historical orders
  -- survive a tailor offboarding.
  tailor_id            uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  -- Free text + a soft client-side catalog. Kept off CHECK so a
  -- merch team adding "Sherwani" or "Blouse Pattern" later
  -- doesn't need a migration.
  garment_type         text        NOT NULL,
  pickup_address       text        NOT NULL,
  pickup_time          timestamptz NOT NULL,
  -- Public URL of the optional reference-design photo (Storage
  -- bucket below). NULL when the customer skips the upload step.
  reference_image_url  text,
  -- Five-state lifecycle, identical to the dashboard's vertical
  -- timeline. Kept as text + CHECK to match the rest of the
  -- codebase's status columns.
  status               text        NOT NULL DEFAULT 'pending_pickup'
                       CHECK (status IN (
                         'pending_pickup',
                         'fabric_collected',
                         'stitching',
                         'ready_for_delivery',
                         'delivered'
                       )),
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.custom_stitch_orders IS
  'Stitch My Fabric bookings — customer owns the fabric, books a tailor home-visit for measurement + pickup. Isolated from public.orders by design.';

-- Customer dashboard reads `WHERE user_id = auth.uid() ORDER BY created_at DESC`.
CREATE INDEX IF NOT EXISTS custom_stitch_orders_user_idx
  ON public.custom_stitch_orders (user_id, created_at DESC);

-- Atelier ops queue reads `WHERE status = 'pending_pickup'`.
CREATE INDEX IF NOT EXISTS custom_stitch_orders_status_idx
  ON public.custom_stitch_orders (status);

-- Assigned tailor queries `WHERE tailor_id = auth.uid()`.
CREATE INDEX IF NOT EXISTS custom_stitch_orders_tailor_idx
  ON public.custom_stitch_orders (tailor_id);

-- ── Row-Level Security ─────────────────────────────────────
ALTER TABLE public.custom_stitch_orders ENABLE ROW LEVEL SECURITY;

-- Customers see their own bookings end-to-end.
DROP POLICY IF EXISTS "custom_stitch_orders_owner_select"
  ON public.custom_stitch_orders;
CREATE POLICY "custom_stitch_orders_owner_select"
  ON public.custom_stitch_orders FOR SELECT
  USING (auth.uid() = user_id);

-- Customers can insert only as themselves and only at the start
-- of the lifecycle. The atelier — not the client — promotes
-- status forward.
DROP POLICY IF EXISTS "custom_stitch_orders_owner_insert"
  ON public.custom_stitch_orders;
CREATE POLICY "custom_stitch_orders_owner_insert"
  ON public.custom_stitch_orders FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND status = 'pending_pickup'
  );

-- Customers may cancel or amend their own bookings.
-- (Atelier-driven progression is handled by the assigned-tailor
-- policy below.)
DROP POLICY IF EXISTS "custom_stitch_orders_owner_update"
  ON public.custom_stitch_orders;
CREATE POLICY "custom_stitch_orders_owner_update"
  ON public.custom_stitch_orders FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Assigned tailor can read the rows assigned to them and
-- progress status as the visit unfolds. They cannot read
-- another customer's row even if it's pending — the atelier
-- does the assignment server-side so this stays single-tenant
-- per row.
DROP POLICY IF EXISTS "custom_stitch_orders_tailor_select"
  ON public.custom_stitch_orders;
CREATE POLICY "custom_stitch_orders_tailor_select"
  ON public.custom_stitch_orders FOR SELECT
  USING (auth.uid() = tailor_id);

DROP POLICY IF EXISTS "custom_stitch_orders_tailor_update"
  ON public.custom_stitch_orders;
CREATE POLICY "custom_stitch_orders_tailor_update"
  ON public.custom_stitch_orders FOR UPDATE
  USING (auth.uid() = tailor_id)
  WITH CHECK (auth.uid() = tailor_id);

-- ── updated_at auto-bump ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.custom_stitch_orders_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS custom_stitch_orders_touch_updated_at
  ON public.custom_stitch_orders;

CREATE TRIGGER custom_stitch_orders_touch_updated_at
  BEFORE UPDATE ON public.custom_stitch_orders
  FOR EACH ROW EXECUTE FUNCTION public.custom_stitch_orders_touch_updated_at();

-- ── Realtime ───────────────────────────────────────────────
-- The dashboard watches its own rows so a status flip in the
-- Tailor app surfaces in the customer's timeline without a
-- pull-to-refresh.
ALTER PUBLICATION supabase_realtime ADD TABLE public.custom_stitch_orders;

-- ============================================================
-- Storage bucket: custom_stitch_refs
-- Holds the optional reference-design image. Public-read so the
-- tailor app can render the URL directly; writes scoped to
-- `${auth.uid()}/...` so the folder name keeps RLS honest.
-- ============================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('custom_stitch_refs', 'custom_stitch_refs', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "custom_stitch_refs_public_read" ON storage.objects;
CREATE POLICY "custom_stitch_refs_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'custom_stitch_refs');

DROP POLICY IF EXISTS "custom_stitch_refs_own_insert" ON storage.objects;
CREATE POLICY "custom_stitch_refs_own_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'custom_stitch_refs'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "custom_stitch_refs_own_update" ON storage.objects;
CREATE POLICY "custom_stitch_refs_own_update"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'custom_stitch_refs'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "custom_stitch_refs_own_delete" ON storage.objects;
CREATE POLICY "custom_stitch_refs_own_delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'custom_stitch_refs'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
