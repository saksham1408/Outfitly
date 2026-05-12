-- ============================================================
-- 048_messages.sql
-- Direct messages between connected friends — the chat half of
-- the Loop feature. Powers the new `/loop/chats` list and the
-- `/loop/chats/<friendId>` conversation screen.
--
-- A single `messages` table handles both:
--   * **Text chats** — `body` populated, `attachment` empty.
--   * **Outfit shares** — `body` is the optional comment the
--     sender wrote, `attachment` carries the shared product's
--     id / name / price / image URL so the recipient can tap
--     through to the PDP.
--
-- RLS scopes every row to its sender or recipient. Customers
-- can't peek at other customers' messages, ever — including via
-- the broadcast SELECT bug that bit migration 040 for stitch
-- orders (see migration 047 for the post-mortem).
-- ============================================================

CREATE TABLE IF NOT EXISTS public.messages (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- auth.uid() default so the client INSERT never has to thread
  -- sender_id; the INSERT policy below re-asserts the match so
  -- the column can never be spoofed.
  sender_id     uuid        NOT NULL DEFAULT auth.uid()
                            REFERENCES auth.users(id) ON DELETE CASCADE,
  recipient_id  uuid        NOT NULL
                            REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Free text. Empty when the message is a pure outfit share
  -- (i.e., attachment is non-null + body is null).
  body          text        CHECK (
                              body IS NULL
                              OR length(body) <= 4000
                            ),
  -- jsonb so we can carry richer payloads as the feature grows
  -- (outfit shares today; voice notes, location pins, etc.
  -- later) without a fresh migration. The MessagesRepository
  -- on the client reads `attachment.kind` to switch
  -- presentation. Common shape today:
  --   {
  --     "kind": "outfit_share",
  --     "product_id": "...",
  --     "product_name": "...",
  --     "product_image": "...",
  --     "product_price": 4500
  --   }
  attachment    jsonb,
  -- NULL until the recipient opens the conversation that
  -- contains this row. The chat-list unread badge counts
  -- messages where read_at IS NULL AND recipient_id = me.
  read_at       timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  -- Sanity check: a body that's null AND no attachment is a
  -- "blank" message — reject it server-side so the chat list
  -- never renders an empty bubble.
  CONSTRAINT messages_body_or_attachment_required
    CHECK (body IS NOT NULL OR attachment IS NOT NULL),
  -- A self-message would be lonely. Forbid.
  CONSTRAINT messages_no_self_send
    CHECK (sender_id <> recipient_id)
);

COMMENT ON TABLE public.messages IS
  'Direct messages between connected Loop friends — text chats AND outfit shares. RLS scoped to (sender, recipient).';

-- Hot path: conversation screen reads
--   `WHERE (sender_id = me AND recipient_id = friend)
--       OR (sender_id = friend AND recipient_id = me)
--   ORDER BY created_at`.
-- Two composite indexes — one per direction — keep that fast
-- without a costly OR-friendly scan.
CREATE INDEX IF NOT EXISTS messages_sender_recipient_idx
  ON public.messages (sender_id, recipient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS messages_recipient_sender_idx
  ON public.messages (recipient_id, sender_id, created_at DESC);

-- Partial index for the unread-count query — kept tiny because
-- the vast majority of rows have a non-null read_at.
CREATE INDEX IF NOT EXISTS messages_unread_idx
  ON public.messages (recipient_id)
  WHERE read_at IS NULL;

-- ── Row-Level Security ─────────────────────────────────────
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- SELECT — either side of the conversation can read it.
DROP POLICY IF EXISTS "messages_participants_select"
  ON public.messages;
CREATE POLICY "messages_participants_select"
  ON public.messages FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

-- INSERT — only as yourself. The WITH CHECK re-asserts sender_id
-- so a tampered client can't pretend to be someone else; the
-- table default also pins it to auth.uid() so the column never
-- has to be sent.
DROP POLICY IF EXISTS "messages_owner_insert"
  ON public.messages;
CREATE POLICY "messages_owner_insert"
  ON public.messages FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

-- UPDATE — only the recipient can update (mark read). The
-- sender shouldn't be able to retroactively edit content;
-- read-state is the only legitimate mutation today.
DROP POLICY IF EXISTS "messages_recipient_update"
  ON public.messages;
CREATE POLICY "messages_recipient_update"
  ON public.messages FOR UPDATE
  USING (auth.uid() = recipient_id)
  WITH CHECK (auth.uid() = recipient_id);

-- DELETE — either side can delete a message (swipe to delete
-- from their own view). The row is hard-removed because soft
-- delete on a chat surface leaves zombie "this message was
-- deleted" stubs that nobody wants in MVP.
DROP POLICY IF EXISTS "messages_participants_delete"
  ON public.messages;
CREATE POLICY "messages_participants_delete"
  ON public.messages FOR DELETE
  USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

-- ── Realtime publication ───────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'messages'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime
             ADD TABLE public.messages';
  END IF;
END $$;
