-- ============================================================
-- 018_planner_events.sql
-- Calendar entries the user adds manually in the Wardrobe Planner.
-- Each row carries the event metadata and, optionally, a Mix-and-Match
-- outfit (serialised as a jsonb of wardrobe item ids). The app reads
-- this table on the Closet tab, and the atelier / admin can see upcoming
-- events in Directus for curation nudges.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.planner_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title       text NOT NULL,
  subtitle    text,
  event_date  timestamptz NOT NULL,
  -- Shape: {"top_id": "...", "bottom_id": "...", "footwear_id": "...", "accessory_id": "..."}
  -- Any key may be null. Outfit stays nullable so a freshly created event
  -- can exist without a planned look.
  outfit      jsonb,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.planner_events IS
  'Calendar-synced events the user wants to dress for. Nullable outfit blob is populated by the Mix-and-Match planner.';

CREATE INDEX IF NOT EXISTS planner_events_user_date_idx
  ON public.planner_events(user_id, event_date);
CREATE INDEX IF NOT EXISTS planner_events_event_date_idx
  ON public.planner_events(event_date);

-- Auto-touch updated_at on any UPDATE
CREATE OR REPLACE FUNCTION public.touch_planner_events_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_planner_events_updated_at ON public.planner_events;
CREATE TRIGGER trg_planner_events_updated_at
  BEFORE UPDATE ON public.planner_events
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_planner_events_updated_at();

-- ── Row-Level Security ──
ALTER TABLE public.planner_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "planner_events_own_select" ON public.planner_events;
CREATE POLICY "planner_events_own_select"
  ON public.planner_events FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "planner_events_own_insert" ON public.planner_events;
CREATE POLICY "planner_events_own_insert"
  ON public.planner_events FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "planner_events_own_update" ON public.planner_events;
CREATE POLICY "planner_events_own_update"
  ON public.planner_events FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "planner_events_own_delete" ON public.planner_events;
CREATE POLICY "planner_events_own_delete"
  ON public.planner_events FOR DELETE
  USING (auth.uid() = user_id);
