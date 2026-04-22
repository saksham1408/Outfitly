-- ============================================================
-- 021_india_locations.sql
-- Reference tables powering the Add Address form's State + City
-- dropdowns. Phase 1/2 hard-coded the list in a Dart constant; moving
-- it to Supabase lets the catalog team expand coverage (add Tier-3
-- towns, update city names) without shipping a new client build.
--
-- Both tables are world-readable (anon role) and never written by the
-- app — only the CMS / admin panel inserts rows.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.india_states (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name           text NOT NULL UNIQUE,
  -- Short ISO 3166-2 code (e.g. "MH", "RJ", "DL"). Optional — the
  -- reverse-geocoding path tolerates nulls.
  code           text,
  display_order  int NOT NULL DEFAULT 100,
  created_at     timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.india_states IS
  'Canonical list of Indian states + union territories for the Add Address dropdown.';

CREATE INDEX IF NOT EXISTS india_states_order_idx
  ON public.india_states(display_order, name);

CREATE TABLE IF NOT EXISTS public.india_cities (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  state_id       uuid NOT NULL
                   REFERENCES public.india_states(id) ON DELETE CASCADE,
  name           text NOT NULL,
  -- The "Other" escape-hatch row. Rendered at the bottom of the list
  -- and preserved across sort orders.
  is_other       boolean NOT NULL DEFAULT false,
  display_order  int NOT NULL DEFAULT 100,
  created_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (state_id, name)
);

COMMENT ON TABLE public.india_cities IS
  'Cities keyed by state. The catalog team adds rows here to unlock new delivery zones without a client release.';

CREATE INDEX IF NOT EXISTS india_cities_state_order_idx
  ON public.india_cities(state_id, is_other, display_order, name);

-- ── Row-Level Security ──
-- Read-only for the app; only service role (admin panel) writes.
ALTER TABLE public.india_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.india_cities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "india_states_public_read" ON public.india_states;
CREATE POLICY "india_states_public_read"
  ON public.india_states FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "india_cities_public_read" ON public.india_cities;
CREATE POLICY "india_cities_public_read"
  ON public.india_cities FOR SELECT
  USING (true);

-- ============================================================
-- Seed data. Kept in sync with
-- lib/features/addresses/domain/india_locations.dart so users who
-- launch the app offline (pre-fetch) still see the expected list.
-- ON CONFLICT DO NOTHING keeps this idempotent — re-running the
-- migration in local dev won't duplicate rows.
-- ============================================================

INSERT INTO public.india_states (name, code, display_order) VALUES
  ('Andhra Pradesh', 'AP',  10),
  ('Arunachal Pradesh', 'AR', 20),
  ('Assam', 'AS', 30),
  ('Bihar', 'BR', 40),
  ('Chhattisgarh', 'CG', 50),
  ('Goa', 'GA', 60),
  ('Gujarat', 'GJ', 70),
  ('Haryana', 'HR', 80),
  ('Himachal Pradesh', 'HP', 90),
  ('Jharkhand', 'JH', 100),
  ('Karnataka', 'KA', 110),
  ('Kerala', 'KL', 120),
  ('Madhya Pradesh', 'MP', 130),
  ('Maharashtra', 'MH', 140),
  ('Manipur', 'MN', 150),
  ('Meghalaya', 'ML', 160),
  ('Mizoram', 'MZ', 170),
  ('Nagaland', 'NL', 180),
  ('Odisha', 'OD', 190),
  ('Punjab', 'PB', 200),
  ('Rajasthan', 'RJ', 210),
  ('Sikkim', 'SK', 220),
  ('Tamil Nadu', 'TN', 230),
  ('Telangana', 'TG', 240),
  ('Tripura', 'TR', 250),
  ('Uttar Pradesh', 'UP', 260),
  ('Uttarakhand', 'UK', 270),
  ('West Bengal', 'WB', 280),
  ('Andaman and Nicobar Islands', 'AN', 500),
  ('Chandigarh', 'CH', 510),
  ('Dadra and Nagar Haveli and Daman and Diu', 'DH', 520),
  ('Delhi', 'DL', 530),
  ('Jammu and Kashmir', 'JK', 540),
  ('Ladakh', 'LA', 550),
  ('Lakshadweep', 'LD', 560),
  ('Puducherry', 'PY', 570)
ON CONFLICT (name) DO NOTHING;

-- Cities: inserted via a DO block so we can look up each state's id
-- by name and keep the seed readable as state → list-of-cities pairs.
-- is_other=true marks the catch-all row so the client pins it at the
-- bottom of the dropdown.
DO $$
DECLARE
  seeds jsonb := '{
    "Andhra Pradesh": ["Visakhapatnam","Vijayawada","Guntur","Nellore","Tirupati","Kakinada","Rajahmundry"],
    "Arunachal Pradesh": ["Itanagar","Naharlagun","Pasighat"],
    "Assam": ["Guwahati","Dibrugarh","Silchar","Jorhat","Tezpur"],
    "Bihar": ["Patna","Gaya","Bhagalpur","Muzaffarpur","Darbhanga"],
    "Chhattisgarh": ["Raipur","Bhilai","Bilaspur","Korba","Durg"],
    "Goa": ["Panaji","Margao","Vasco da Gama","Mapusa"],
    "Gujarat": ["Ahmedabad","Surat","Vadodara","Rajkot","Bhavnagar","Jamnagar","Gandhinagar"],
    "Haryana": ["Gurugram","Faridabad","Panipat","Ambala","Karnal","Hisar"],
    "Himachal Pradesh": ["Shimla","Manali","Dharamshala","Solan","Mandi"],
    "Jharkhand": ["Ranchi","Jamshedpur","Dhanbad","Bokaro","Hazaribagh"],
    "Karnataka": ["Bengaluru","Mysuru","Mangaluru","Hubballi","Belagavi","Davanagere"],
    "Kerala": ["Kochi","Thiruvananthapuram","Kozhikode","Thrissur","Kollam","Kannur"],
    "Madhya Pradesh": ["Bhopal","Indore","Gwalior","Jabalpur","Ujjain","Sagar"],
    "Maharashtra": ["Mumbai","Pune","Nagpur","Nashik","Aurangabad","Thane","Navi Mumbai","Kolhapur"],
    "Manipur": ["Imphal","Thoubal"],
    "Meghalaya": ["Shillong","Tura"],
    "Mizoram": ["Aizawl","Lunglei"],
    "Nagaland": ["Kohima","Dimapur"],
    "Odisha": ["Bhubaneswar","Cuttack","Rourkela","Berhampur","Sambalpur"],
    "Punjab": ["Ludhiana","Amritsar","Jalandhar","Patiala","Bathinda","Mohali"],
    "Rajasthan": ["Jaipur","Jodhpur","Udaipur","Kota","Ajmer","Bikaner","Alwar"],
    "Sikkim": ["Gangtok","Namchi"],
    "Tamil Nadu": ["Chennai","Coimbatore","Madurai","Tiruchirappalli","Salem","Tirunelveli","Erode"],
    "Telangana": ["Hyderabad","Warangal","Nizamabad","Karimnagar","Khammam"],
    "Tripura": ["Agartala","Udaipur"],
    "Uttar Pradesh": ["Lucknow","Kanpur","Varanasi","Agra","Noida","Ghaziabad","Prayagraj","Meerut"],
    "Uttarakhand": ["Dehradun","Haridwar","Rishikesh","Haldwani","Nainital"],
    "West Bengal": ["Kolkata","Howrah","Siliguri","Durgapur","Asansol","Kharagpur"],
    "Andaman and Nicobar Islands": ["Port Blair"],
    "Chandigarh": ["Chandigarh"],
    "Dadra and Nagar Haveli and Daman and Diu": ["Daman","Diu","Silvassa"],
    "Delhi": ["New Delhi","Delhi"],
    "Jammu and Kashmir": ["Srinagar","Jammu","Anantnag"],
    "Ladakh": ["Leh","Kargil"],
    "Lakshadweep": ["Kavaratti"],
    "Puducherry": ["Puducherry","Karaikal","Mahe","Yanam"]
  }'::jsonb;
  state_name text;
  city_arr jsonb;
  city_name text;
  state_uuid uuid;
  ord int;
BEGIN
  FOR state_name, city_arr IN SELECT * FROM jsonb_each(seeds) LOOP
    SELECT id INTO state_uuid FROM public.india_states WHERE name = state_name;
    IF state_uuid IS NULL THEN CONTINUE; END IF;

    ord := 10;
    FOR city_name IN SELECT jsonb_array_elements_text(city_arr) LOOP
      INSERT INTO public.india_cities (state_id, name, is_other, display_order)
        VALUES (state_uuid, city_name, false, ord)
        ON CONFLICT (state_id, name) DO NOTHING;
      ord := ord + 10;
    END LOOP;

    -- Add a single "Other" fallback row per state so users in smaller
    -- towns can still save an address; the client renders it last.
    INSERT INTO public.india_cities (state_id, name, is_other, display_order)
      VALUES (state_uuid, 'Other', true, 9999)
      ON CONFLICT (state_id, name) DO NOTHING;
  END LOOP;
END;
$$;
