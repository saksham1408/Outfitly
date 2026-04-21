-- ============================================================
-- 019_planner_events_default_user.sql
-- Hardening pass for the planner_events RLS setup.
--
-- 1. Default user_id to auth.uid() so the client never has to send
--    it. This removes a whole class of "client-sent id does not match
--    JWT" RLS failures.
-- 2. Re-assert the four own-row policies idempotently in case the
--    initial migration (018) was applied partially.
-- ============================================================

-- ── user_id defaults to the signed-in user ──
ALTER TABLE public.planner_events
  ALTER COLUMN user_id SET DEFAULT auth.uid();

-- ── Belt-and-braces: make sure RLS is on and the policies exist ──
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
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "planner_events_own_delete" ON public.planner_events;
CREATE POLICY "planner_events_own_delete"
  ON public.planner_events FOR DELETE
  USING (auth.uid() = user_id);
