-- Seed: 100 islands in a 10x10 grid
-- Luxury types distributed cyclically: marble, crystal, sulfur (~33 each)
-- max_city_slots: 16 for most, 17 for every 5th island (idx % 5 == 0)

DO $$
DECLARE
  x             int;
  y             int;
  luxury_types  text[] := ARRAY['marble', 'crystal', 'sulfur'];
  idx           int := 0;
BEGIN
  FOR x IN 1..10 LOOP
    FOR y IN 1..10 LOOP
      INSERT INTO public.islands (grid_x, grid_y, luxury_type, max_city_slots)
      VALUES (
        x,
        y,
        luxury_types[1 + (idx % 3)],
        16 + (CASE WHEN (idx % 5) = 0 THEN 1 ELSE 0 END)
      );
      idx := idx + 1;
    END LOOP;
  END LOOP;
END;
$$;
