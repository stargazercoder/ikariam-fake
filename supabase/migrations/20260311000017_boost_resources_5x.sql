-- Migration: 5x resource boost for faster testing
-- Increases starting resources and production rate by 5x.

-- 1. Update on_city_created trigger to give 5x starting resources
CREATE OR REPLACE FUNCTION public.on_city_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  -- Seed starting resources: wood and gold have 2500, others start at 0
  INSERT INTO public.city_resources (city_id, resource_type, amount) VALUES
    (NEW.id, 'wood',   2500),
    (NEW.id, 'marble',    0),
    (NEW.id, 'crystal',   0),
    (NEW.id, 'sulfur',    0),
    (NEW.id, 'gold',   2500);

  INSERT INTO public.city_buildings (city_id, building_type, level, assigned_workers) VALUES
    (NEW.id, 'town_hall',    1, 3),
    (NEW.id, 'sawmill',      1, 3),
    (NEW.id, 'quarry',       1, 3),
    (NEW.id, 'glassblower',  1, 3),
    (NEW.id, 'sulfur_pit',   1, 3),
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
    RAISE WARNING 'on_city_created: % %', SQLERRM, SQLSTATE;
    RETURN NEW;
END;
$$;

-- 2. Update process_resource_tick to produce 5x resources
CREATE OR REPLACE FUNCTION public.process_resource_tick()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT
      cr.id            AS resource_id,
      cr.city_id,
      cr.resource_type,
      cr.amount        AS current_amount,
      COALESCE(pb.level, 0)            AS prod_level,
      COALESCE(pb.assigned_workers, 0) AS workers,
      COALESCE(wh.level, 0)            AS warehouse_level
    FROM public.city_resources cr
    LEFT JOIN public.city_buildings pb
      ON pb.city_id = cr.city_id
      AND pb.building_type = CASE cr.resource_type
            WHEN 'wood'    THEN 'sawmill'
            WHEN 'marble'  THEN 'quarry'
            WHEN 'crystal' THEN 'glassblower'
            WHEN 'sulfur'  THEN 'sulfur_pit'
            WHEN 'gold'    THEN 'town_hall'
          END
    LEFT JOIN public.city_buildings wh
      ON wh.city_id = cr.city_id
      AND wh.building_type = 'warehouse'
  LOOP
    CONTINUE WHEN r.workers = 0 OR r.prod_level = 0;

    UPDATE public.city_resources
    SET
      amount     = LEAST(
                     r.current_amount + (r.workers * r.prod_level * 5.0),
                     500.0 * POWER(1.5, r.warehouse_level)
                   ),
      updated_at = NOW()
    WHERE id = r.resource_id;
  END LOOP;
END;
$$;

-- 3. Boost existing cities' resources (for already-registered users)
UPDATE public.city_resources
SET amount = amount * 5,
    updated_at = NOW()
WHERE amount > 0;
