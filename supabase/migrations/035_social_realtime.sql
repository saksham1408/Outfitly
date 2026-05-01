-- ============================================================
-- 035_social_realtime.sql
-- Add the social tables to the `supabase_realtime` publication so
-- the client can subscribe to row-level INSERT / UPDATE / DELETE
-- events. Without this, `.stream()` calls return an empty initial
-- snapshot and never fire on subsequent writes.
--
-- Idempotent: each ADD TABLE wrapped in a DO block that no-ops if
-- the table is already in the publication. Re-running this file is
-- safe even after the publication has been seeded by the
-- Supabase Dashboard's "Replication" toggle.
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'friend_connections'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime
             ADD TABLE public.friend_connections';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'borrow_requests'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime
             ADD TABLE public.borrow_requests';
  END IF;
END $$;
