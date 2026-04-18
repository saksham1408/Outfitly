-- ============================================================
-- 017_custom_requests.sql
-- Bespoke "Design Your Own Embroidery" requests submitted from the
-- Embroidery subcategory. Atelier reviews them in Directus.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.custom_requests (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  image_url    text NOT NULL,
  base_garment text NOT NULL,
  custom_notes text NOT NULL,
  status       text NOT NULL DEFAULT 'pending_review'
               CHECK (status IN ('pending_review','quoted','accepted','rejected','completed')),
  quoted_price numeric(10,2),
  admin_notes  text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.custom_requests IS
  'Bespoke embroidery requests submitted from the app. Atelier reviews these in Directus.';

CREATE INDEX IF NOT EXISTS custom_requests_user_id_idx
  ON public.custom_requests(user_id);
CREATE INDEX IF NOT EXISTS custom_requests_status_idx
  ON public.custom_requests(status);
CREATE INDEX IF NOT EXISTS custom_requests_created_at_idx
  ON public.custom_requests(created_at DESC);

-- Auto-touch updated_at on any UPDATE
CREATE OR REPLACE FUNCTION public.touch_custom_requests_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS custom_requests_touch_updated_at ON public.custom_requests;
CREATE TRIGGER custom_requests_touch_updated_at
  BEFORE UPDATE ON public.custom_requests
  FOR EACH ROW EXECUTE FUNCTION public.touch_custom_requests_updated_at();

-- RLS: users can insert and read their own; admins (service role)
-- bypass RLS automatically via the service key used by Directus.
ALTER TABLE public.custom_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users insert own custom_request"
  ON public.custom_requests;
CREATE POLICY "users insert own custom_request"
  ON public.custom_requests FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "users read own custom_request"
  ON public.custom_requests;
CREATE POLICY "users read own custom_request"
  ON public.custom_requests FOR SELECT TO authenticated
  USING (user_id = auth.uid());
