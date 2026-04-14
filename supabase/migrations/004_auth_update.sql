-- ============================================================
-- Outfitly: Add gender & email columns to profiles
-- Run this in Supabase SQL Editor
-- ============================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS gender text,
  ADD COLUMN IF NOT EXISTS email text;

-- Constrain gender to valid values
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'profiles_gender_check'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_gender_check
      CHECK (gender IN ('male', 'female', 'non-binary', 'prefer-not-to-say') OR gender IS NULL);
  END IF;
END $$;

-- Update the trigger function to also store email
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, phone, email)
  VALUES (new.id, new.phone, new.email);
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
