-- Migration: unit movement arrival function
-- process_arrivals(): called every minute by pg_cron to deliver in-transit armies

-- ============================================================
-- process_arrivals
-- ============================================================
-- Finds all unit_movements rows whose arrive_at has passed, adds units to the
-- destination city's army roster (upserts into city_units), then removes the
-- movement row — which fires a Realtime DELETE event to update the UI.
-- Runs as SECURITY DEFINER so it can write without client RLS.
-- Units JSONB format: {"hoplite": 10, "archer": 5}

CREATE OR REPLACE FUNCTION public.process_arrivals()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  m         RECORD;
  v_type    text;
  v_qty_txt text;
  v_qty     integer;
BEGIN
  FOR m IN
    SELECT id, destination_city_id, units
    FROM public.unit_movements
    WHERE arrive_at <= NOW()
  LOOP
    -- Iterate over JSONB unit snapshot: {"hoplite": 10, "archer": 5}
    FOR v_type, v_qty_txt IN
      SELECT key, value FROM jsonb_each_text(m.units)
    LOOP
      v_qty := v_qty_txt::integer;

      -- Upsert into destination city's army roster
      -- Troops arrive at destination; city may have no existing row for this unit type
      INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
      VALUES (m.destination_city_id, v_type, v_qty, NOW())
      ON CONFLICT (city_id, unit_type)
      DO UPDATE SET
        quantity   = public.city_units.quantity + EXCLUDED.quantity,
        updated_at = NOW();
    END LOOP;

    -- Remove the completed movement — Realtime DELETE event notifies the UI
    DELETE FROM public.unit_movements WHERE id = m.id;
  END LOOP;
END;
$$;
