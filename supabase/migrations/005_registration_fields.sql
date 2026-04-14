-- ============================================================
-- Add registration form fields to profiles table
-- ============================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS location text,
  ADD COLUMN IF NOT EXISTS preferred_style text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS initial_interest text;
