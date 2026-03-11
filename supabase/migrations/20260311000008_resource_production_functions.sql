-- Migration: resource production functions
-- process_resource_tick(): called every 5 minutes by pg_cron to advance all city resources
-- deduct_resource(): called by upgrade-building Edge Function to spend resources

-- ============================================================
-- process_resource_tick
-- ============================================================
-- Iterates every city_resources row, computes production based on the matching
-- production building level and assigned workers, respects warehouse capacity,
-- then caps the amount at capacity (LEAST). Only updates if production > 0.
--
-- Resource -> Production building mapping:
--   wood    -> sawmill
--   marble  -> quarry
--   crystal -> glassblower
--   sulfur  -> sulfur_pit
--   gold    -> town_hall
--
-- Production formula: assigned_workers * prod_level * 1.0  (research_bonus = 1.0 for v1)
-- Capacity formula:   500 * POWER(1.5, warehouse_level)   (base capacity 500, scales with warehouse)

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
      -- Production building: sawmill for wood, quarry for marble, etc.
      COALESCE(pb.level, 0)            AS prod_level,
      COALESCE(pb.assigned_workers, 0) AS workers,
      -- Warehouse provides capacity scaling
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
    -- Skip resources with no production building assigned (defensive guard)
    CONTINUE WHEN r.workers = 0 OR r.prod_level = 0;

    UPDATE public.city_resources
    SET
      amount     = LEAST(
                     r.current_amount + (r.workers * r.prod_level * 1.0),
                     500.0 * POWER(1.5, r.warehouse_level)
                   ),
      updated_at = NOW()
    WHERE id = r.resource_id;
  END LOOP;
END;
$$;

-- ============================================================
-- deduct_resource
-- ============================================================
-- Atomically deducts an amount from a city's resource.
-- Raises an exception if the city does not have enough, which causes the
-- calling Edge Function transaction to roll back automatically.

CREATE OR REPLACE FUNCTION public.deduct_resource(
  p_city_id     uuid,
  p_resource_type text,
  p_amount      numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_rows_updated integer;
BEGIN
  UPDATE public.city_resources
  SET
    amount     = amount - p_amount,
    updated_at = NOW()
  WHERE city_id      = p_city_id
    AND resource_type = p_resource_type
    AND amount        >= p_amount;

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
    RAISE EXCEPTION 'Insufficient %', p_resource_type
      USING ERRCODE = 'insufficient_resources';
  END IF;
END;
$$;
