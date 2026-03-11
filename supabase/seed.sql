-- Seed: 25 islands in a 5x5 grid
-- Luxury types distributed cyclically: marble, crystal, sulfur (~8-9 each)
-- max_city_slots: 16 for most, 17 for every 5th island (idx % 5 == 0)

DO $$
DECLARE
  x             int;
  y             int;
  luxury_types  text[] := ARRAY['marble', 'crystal', 'sulfur'];
  idx           int := 0;
BEGIN
  FOR x IN 0..4 LOOP
    FOR y IN 0..4 LOOP
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
