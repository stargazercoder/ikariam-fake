-- Migration: construction completion function
-- complete_building_upgrades(): called every minute by pg_cron to finalize builds

-- ============================================================
-- complete_building_upgrades
-- ============================================================
-- Finds all construction_queue rows whose finish_at has passed, advances the
-- corresponding building level to target_level, then removes the queue entry.
-- Runs as SECURITY DEFINER so it can write to city_buildings without client RLS.

CREATE OR REPLACE FUNCTION public.complete_building_upgrades()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  q RECORD;
BEGIN
  FOR q IN
    SELECT id, city_id, building_type, target_level
    FROM public.construction_queue
    WHERE finish_at <= NOW()
  LOOP
    -- Advance building level to target
    UPDATE public.city_buildings
    SET
      level      = q.target_level,
      updated_at = NOW()
    WHERE city_id       = q.city_id
      AND building_type = q.building_type;

    -- Remove the completed queue entry
    DELETE FROM public.construction_queue
    WHERE id = q.id;
  END LOOP;
END;
$$;
