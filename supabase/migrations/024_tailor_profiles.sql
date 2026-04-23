-- ============================================================
-- Outfitly: tailor_profiles table
-- ------------------------------------------------------------
-- Extends every row in auth.users (with role='tailor') with the
-- partner-facing profile fields the Outfitly Tailor Partner App
-- needs: full name, phone number for dispatch, years of
-- experience for skill gating. The row is created synchronously
-- during sign-up by the client immediately after supabase.auth
-- .signUp() succeeds — the auth user is the owner of their own
-- profile row (FK to auth.users.id + matching RLS policy).
-- ============================================================

CREATE TABLE IF NOT EXISTS public.tailor_profiles (
  id                uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name         text        NOT NULL,
  phone             text        NOT NULL,
  experience_years  smallint    NOT NULL DEFAULT 0 CHECK (experience_years >= 0 AND experience_years <= 99),
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS tailor_profiles_phone_idx
  ON public.tailor_profiles (phone);

-- ──────────────────────────────────────────────────────────
-- Row Level Security
-- ──────────────────────────────────────────────────────────
-- Every policy is keyed on `auth.uid() = id` — tailors can
-- only see and edit their own profile. If you later want
-- customers to see a dispatched tailor's name/experience on
-- the order-tracking card, add a dedicated SELECT policy
-- scoped to "tailors assigned to my appointments".
ALTER TABLE public.tailor_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Tailors read own profile"
  ON public.tailor_profiles
  FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Tailors insert own profile"
  ON public.tailor_profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Tailors update own profile"
  ON public.tailor_profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ──────────────────────────────────────────────────────────
-- updated_at auto-bump — matches the tailor_appointments
-- trigger so both partner-facing tables stay introspectable
-- with one mental model.
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tailor_profiles_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tailor_profiles_touch_updated_at
  ON public.tailor_profiles;

CREATE TRIGGER tailor_profiles_touch_updated_at
  BEFORE UPDATE ON public.tailor_profiles
  FOR EACH ROW EXECUTE FUNCTION public.tailor_profiles_touch_updated_at();
