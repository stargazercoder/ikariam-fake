-- Migration: dev_bulk_spawn_units + dev_instant_complete RPC functions (Phase 13 DEVT-01)
-- ============================================================
-- DEV ONLY — these functions bypass RLS and should NOT be
-- deployed to a production Supabase instance.
-- They exist solely to support the in-app dev toolbar
-- (DevToolbarWidget, gated by kDebugMode) for rapid local
-- testing. Remove this migration before going to production.
-- ============================================================

-- ============================================================
-- dev_bulk_spawn_units
-- Spawns multiple unit types in a city army roster in one call.
-- Accepts a JSONB map of unit_type -> quantity and upserts each
-- atomically. If a unit type already exists, adds to quantity.
-- Used by dev toolbar "Bulk Spawn Units" action (Phase 13).
-- ============================================================
CREATE OR REPLACE FUNCTION public.dev_bulk_spawn_units(
  p_city_id uuid,
  p_units   jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_unit_type text;
  v_quantity  integer;
BEGIN
  -- Iterate over JSONB map: each key = unit_type, each value = quantity
  FOR v_unit_type, v_quantity IN
    SELECT key, value::integer FROM jsonb_each_text(p_units)
  LOOP
    INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
      VALUES (p_city_id, v_unit_type, v_quantity, NOW())
      ON CONFLICT (city_id, unit_type)
      DO UPDATE SET
        quantity   = public.city_units.quantity + EXCLUDED.quantity,
        updated_at = NOW();
  END LOOP;
END;
$$;

-- ============================================================
-- dev_instant_complete
-- Instantly completes all training_queue and construction_queue
-- entries for the specified city.
--
-- Training queue: upserts trained units into city_units and
-- deletes the queue row (mirrors complete_training_queue logic).
--
-- Construction queue: sets finish_at to 1 second in the past so
-- the existing complete_construction() cron function handles the
-- level-up logic correctly on its next tick.
--
-- Used by dev toolbar "Instant Complete" action (Phase 13).
-- ============================================================
CREATE OR REPLACE FUNCTION public.dev_instant_complete(
  p_city_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  q RECORD;
BEGIN
  -- Part 1: Complete training queue
  -- For each active training entry, upsert the units into city_units,
  -- then remove the queue row.
  FOR q IN
    SELECT id, unit_type, quantity
      FROM public.training_queue
     WHERE city_id = p_city_id
  LOOP
    -- Award the trained units to the city
    INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
      VALUES (p_city_id, q.unit_type, q.quantity, NOW())
      ON CONFLICT (city_id, unit_type)
      DO UPDATE SET
        quantity   = public.city_units.quantity + EXCLUDED.quantity,
        updated_at = NOW();

    -- Remove the completed training queue entry
    DELETE FROM public.training_queue WHERE id = q.id;
  END LOOP;

  -- Part 2: Complete construction queue
  -- Set finish_at to 1 second in the past so the existing
  -- complete_construction() cron picks it up on its next run.
  UPDATE public.construction_queue
    SET finish_at = NOW() - INTERVAL '1 second'
    WHERE city_id = p_city_id;
END;
$$;
