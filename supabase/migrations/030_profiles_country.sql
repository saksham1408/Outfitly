-- ============================================================
-- Outfitly: profiles.country — ISO 3166-1 alpha-2
-- ------------------------------------------------------------
-- Captured at register time via the new country picker on the
-- signup form. Drives:
--   1. Phone-number prefix on the auth surface (+91, +44, +1).
--   2. Currency the catalog is displayed in (Money service —
--      lib/core/locale/money.dart). On login we read this column
--      and call Money.setOverrideCountry() before navigating off
--      the auth flow, so the home screen lands with the user's
--      currency already rendered.
--
-- Stored as alpha-2 (`IN`, `GB`, `JP`) because that's what the
-- in-app country map (lib/core/locale/country_currency_map.dart)
-- keys on. Length-2 CHECK + uppercase normalisation guard against
-- "ind" / "USA" / null-string drift from older client builds.
--
-- Backfill: existing rows default to 'IN' since the app was
-- India-only pre this migration. Users can change the country at
-- any time and the change persists on next signin.
-- ============================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS country text;

-- Backfill before tightening the constraint.
UPDATE public.profiles
SET country = 'IN'
WHERE country IS NULL;

-- Length and shape constraint. Permissive on case so the client
-- can send 'in' or 'IN' without us special-casing — the trigger
-- below normalises to upper.
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_country_alpha2_chk;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_country_alpha2_chk
  CHECK (country IS NULL OR length(country) = 2);

-- Normalise to uppercase on every write so SELECTs are predictable.
CREATE OR REPLACE FUNCTION public.profiles_country_uppercase()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.country IS NOT NULL THEN
    NEW.country := upper(NEW.country);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_country_uppercase_trg ON public.profiles;

CREATE TRIGGER profiles_country_uppercase_trg
BEFORE INSERT OR UPDATE OF country
ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.profiles_country_uppercase();
