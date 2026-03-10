-- Migration: handle_new_user trigger
-- Atomically creates a profile stub and places the user's first city on signup.
-- Uses SECURITY DEFINER with SET search_path = '' to prevent search_path injection.
-- References all tables by fully qualified name (public.schema).

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_island_id   uuid;
  v_slot_number integer;
  v_city_name   text;
  v_city_names  text[] := ARRAY[
    'Sparta', 'Athens', 'Corinth', 'Argos', 'Thebes',
    'Delphi', 'Rhodes', 'Olympia', 'Mycenae', 'Epidaurus',
    'Megara', 'Tegea', 'Sicyon', 'Phlius', 'Mantinea',
    'Elis', 'Ithaca', 'Pylos', 'Tiryns', 'Nafplio'
  ];
BEGIN
  -- Find island with most empty slots (least populated), ensuring it still has room
  SELECT i.id
  INTO v_island_id
  FROM public.islands i
  LEFT JOIN public.cities c ON c.island_id = i.id
  GROUP BY i.id, i.max_city_slots
  HAVING COUNT(c.id) < i.max_city_slots
  ORDER BY (i.max_city_slots - COUNT(c.id)) DESC
  LIMIT 1;

  -- Assign next available slot number on that island
  SELECT COALESCE(MAX(slot_number), 0) + 1
  INTO v_slot_number
  FROM public.cities
  WHERE island_id = v_island_id;

  -- Pick a random city name from the pool
  v_city_name := v_city_names[1 + floor(random() * array_length(v_city_names, 1))::int];

  -- Insert profile stub (display_name is NULL until user completes the profile screen)
  INSERT INTO public.profiles (id, avatar_id)
  VALUES (NEW.id, 1);

  -- Place the user's starting city on the chosen island
  INSERT INTO public.cities (owner_id, island_id, slot_number, name)
  VALUES (NEW.id, v_island_id, v_slot_number, v_city_name);

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- If no islands exist or any other error: do not block signup
    -- The profile screen will handle the missing city case gracefully
    RAISE WARNING 'handle_new_user: % %', SQLERRM, SQLSTATE;
    RETURN NEW;
END;
$$;

-- Attach the trigger to auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
