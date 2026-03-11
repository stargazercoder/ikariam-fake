-- Migration: training completion and unit deduction functions
-- complete_training(): called every minute by pg_cron to finalize unit training
-- deduct_units(): called by dispatch-units Edge Function to atomically remove units

-- ============================================================
-- complete_training
-- ============================================================
-- Finds all training_queue rows whose finish_at has passed, upserts units into
-- city_units (adding to existing stacks), then removes the queue entry.
-- Runs as SECURITY DEFINER so it can write without client RLS.
-- Note: cities start with NO city_units rows — INSERT ON CONFLICT handles first training.

CREATE OR REPLACE FUNCTION public.complete_training()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  q RECORD;
BEGIN
  FOR q IN
    SELECT id, city_id, unit_type, quantity
    FROM public.training_queue
    WHERE finish_at <= NOW()
  LOOP
    -- Upsert into city_units: add quantity to existing stack, or create new row
    -- Cities start with no city_units rows (no pre-population trigger), so INSERT is required
    INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
    VALUES (q.city_id, q.unit_type, q.quantity, NOW())
    ON CONFLICT (city_id, unit_type)
    DO UPDATE SET
      quantity   = public.city_units.quantity + EXCLUDED.quantity,
      updated_at = NOW();

    -- Remove completed training entry — releases the UNIQUE(city_id) slot
    DELETE FROM public.training_queue WHERE id = q.id;
  END LOOP;
END;
$$;

-- ============================================================
-- deduct_units
-- ============================================================
-- Atomically deducts units from city_units for the dispatch-units Edge Function.
-- Mirrors deduct_resource() pattern from migration 20260311000008.
-- Raises exception with ERRCODE 'insufficient_resources' if quantity insufficient
-- so the caller can catch and return 422.

CREATE OR REPLACE FUNCTION public.deduct_units(
  p_city_id   uuid,
  p_unit_type text,
  p_quantity  integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_rows integer;
BEGIN
  UPDATE public.city_units
  SET
    quantity   = quantity - p_quantity,
    updated_at = NOW()
  WHERE city_id   = p_city_id
    AND unit_type = p_unit_type
    AND quantity  >= p_quantity;  -- atomic guard: only updates if sufficient units exist

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    RAISE EXCEPTION 'Insufficient %', p_unit_type
      USING ERRCODE = 'insufficient_resources';
  END IF;
END;
$$;
