-- ============================================================
-- Outfitly: AI Style Assistant — user style profile
-- ------------------------------------------------------------
-- Backs the new "Outfitly AI Stylist" feature. The data captured
-- here is silently injected into the Gemini chat session as a
-- system instruction so every reply already knows the user's
-- body type / skin tone / preferred occasions — no need for the
-- user to repeat themselves on every prompt.
--
-- We deliberately keep this on its own table (not on the
-- existing `style_preferences` row used by the onboarding quiz)
-- because the AI quiz is a different surface with a different
-- write cadence: users can re-take it any time without touching
-- the catalog-level preferences that drive product filtering.
--
-- The PK is `user_id` (1:1 with auth.users). We do not use a
-- separate UUID — there's exactly one style profile per user.
-- ============================================================


CREATE TABLE IF NOT EXISTS public.style_profiles (
  user_id     uuid        PRIMARY KEY
              REFERENCES auth.users(id) ON DELETE CASCADE,
  body_type   text        NOT NULL,
  skin_tone   text        NOT NULL,
  occasions   text[]      NOT NULL DEFAULT '{}',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- Auto-bump `updated_at` on any UPDATE so we can trust it as a
-- "last quiz retake" timestamp without making the client do it.
CREATE OR REPLACE FUNCTION public.style_profiles_touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS style_profiles_set_updated_at
  ON public.style_profiles;
CREATE TRIGGER style_profiles_set_updated_at
  BEFORE UPDATE ON public.style_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.style_profiles_touch_updated_at();


-- ──────────────────────────────────────────────────────────
-- Row Level Security
-- A user owns exactly one row, identified by its PK. They can
-- read, insert, and update that row only. No DELETE policy —
-- profiles are evergreen; retakes update in place.
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.style_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own style profile"   ON public.style_profiles;
DROP POLICY IF EXISTS "Users insert own style profile" ON public.style_profiles;
DROP POLICY IF EXISTS "Users update own style profile" ON public.style_profiles;

CREATE POLICY "Users read own style profile"
  ON public.style_profiles
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users insert own style profile"
  ON public.style_profiles
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own style profile"
  ON public.style_profiles
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
