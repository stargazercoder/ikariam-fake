-- Migration: on_city_created trigger
-- Seeds 5 resource rows and 14 building rows whenever a new city is inserted.
-- Fires AFTER INSERT on public.cities — triggered by handle_new_user during signup.
-- Production buildings (sawmill, quarry, glassblower, sulfur_pit) and town_hall
-- are seeded at level=1 with assigned_workers=3 so all 5 resources produce from day one.

CREATE OR REPLACE FUNCTION public.on_city_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  -- Seed starting resources: wood and gold have 500, others start at 0
  INSERT INTO public.city_resources (city_id, resource_type, amount) VALUES
    (NEW.id, 'wood',    500),
    (NEW.id, 'marble',    0),
    (NEW.id, 'crystal',   0),
    (NEW.id, 'sulfur',    0),
    (NEW.id, 'gold',    500);

  -- Seed 14 buildings:
  -- Production buildings + town_hall start at level 1 with 3 workers (enables all 5 resources from day 1)
  -- All other city buildings start at level 0 with 0 workers (not yet built)
  INSERT INTO public.city_buildings (city_id, building_type, level, assigned_workers) VALUES
    -- Gold producer (city building)
    (NEW.id, 'town_hall',    1, 3),
    -- Wood producer (production building)
    (NEW.id, 'sawmill',      1, 3),
    -- Marble producer (production building)
    (NEW.id, 'quarry',       1, 3),
    -- Crystal producer (production building)
    (NEW.id, 'glassblower',  1, 3),
    -- Sulfur producer (production building)
    (NEW.id, 'sulfur_pit',   1, 3),
    -- Remaining city buildings (not yet built)
    (NEW.id, 'warehouse',    0, 0),
    (NEW.id, 'barracks',     0, 0),
    (NEW.id, 'shipyard',     0, 0),
    (NEW.id, 'academy',      0, 0),
    (NEW.id, 'embassy',      0, 0),
    (NEW.id, 'trading_port', 0, 0),
    (NEW.id, 'town_wall',    0, 0),
    (NEW.id, 'hideout',      0, 0),
    (NEW.id, 'tavern',       0, 0);

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Do not block city creation if seeding fails (defensive)
    RAISE WARNING 'on_city_created: % %', SQLERRM, SQLSTATE;
    RETURN NEW;
END;
$$;

-- Attach trigger to cities table — fires after each city row is inserted
CREATE TRIGGER on_city_created
  AFTER INSERT ON public.cities
  FOR EACH ROW EXECUTE PROCEDURE public.on_city_created();
