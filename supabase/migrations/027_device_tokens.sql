-- ============================================================
-- Outfitly: device_tokens table
-- ------------------------------------------------------------
-- Powers push notifications across both the customer app and the
-- Outfitly Tailor Partner app. One row per device the signed-in
-- user has opened the app on; the server side of push fan-out
-- reads this table to look up every token it needs to deliver
-- to for a given user_id.
--
-- Token lifecycle:
--   1. On launch (after auth), the client calls the FCM /APNs
--      bridge to get the current device token, then UPSERTs a
--      row keyed on the token string (unique) so re-opens don't
--      duplicate rows but a reinstall (which rotates the token)
--      does create a fresh row.
--   2. On sign-out the client DELETEs the row so a previously-
--      signed-in user on this device doesn't receive pushes
--      meant for the new signed-in user.
--   3. A scheduled purge (future work) drops tokens we've
--      observed delivering a `NotRegistered` / `InvalidToken`
--      response from FCM, so the table stays tidy.
--
-- The `app` column discriminates which app the token came from.
-- A single auth user MAY have both a 'customer' and 'tailor'
-- token (our internal team members do) — the RLS policy lets
-- them see every row keyed on their own uid regardless of which
-- app asked for it.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.device_tokens (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token       text        NOT NULL UNIQUE,
  platform    text        NOT NULL
                CHECK (platform IN ('ios', 'android', 'web')),
  app         text        NOT NULL
                CHECK (app IN ('customer', 'tailor')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- Hot query path: "give me every token registered for this
-- user by this app" (fan-out keyed on auth uid).
CREATE INDEX IF NOT EXISTS device_tokens_user_app_idx
  ON public.device_tokens (user_id, app);

-- ──────────────────────────────────────────────────────────
-- Row Level Security
-- ──────────────────────────────────────────────────────────
-- Tokens are device PII. Only the owner can see or modify them;
-- the server-side notifier runs as the service role (bypasses
-- RLS) so fan-out queries still work.
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own tokens"    ON public.device_tokens;
DROP POLICY IF EXISTS "Users insert own tokens"  ON public.device_tokens;
DROP POLICY IF EXISTS "Users update own tokens"  ON public.device_tokens;
DROP POLICY IF EXISTS "Users delete own tokens"  ON public.device_tokens;

CREATE POLICY "Users read own tokens"
  ON public.device_tokens
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users insert own tokens"
  ON public.device_tokens
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own tokens"
  ON public.device_tokens
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users delete own tokens"
  ON public.device_tokens
  FOR DELETE
  USING (auth.uid() = user_id);

-- ──────────────────────────────────────────────────────────
-- updated_at auto-bump
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.device_tokens_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS device_tokens_touch_updated_at
  ON public.device_tokens;

CREATE TRIGGER device_tokens_touch_updated_at
  BEFORE UPDATE ON public.device_tokens
  FOR EACH ROW EXECUTE FUNCTION public.device_tokens_touch_updated_at();
