-- Migration: modify process_arrivals() to branch between friendly and enemy arrivals
-- When arriving army belongs to the destination city owner: deliver troops (original logic).
-- When arriving army belongs to a different player: create a battle instead.
-- If a battle is already active at that city, the arriving army is rejected (units lost).

CREATE OR REPLACE FUNCTION public.process_arrivals()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  m                  RECORD;
  v_type             text;
  v_qty_txt          text;
  v_qty              integer;
  v_dest_owner_id    uuid;
  v_active_battle    boolean;
  v_def_units_snap   jsonb;
BEGIN
  FOR m IN
    SELECT id, destination_city_id, origin_city_id, owner_id, units
    FROM public.unit_movements
    WHERE arrive_at <= NOW()
  LOOP
    -- Determine who owns the destination city
    SELECT owner_id
    INTO v_dest_owner_id
    FROM public.cities
    WHERE id = m.destination_city_id;

    IF m.owner_id = v_dest_owner_id THEN
      -- ================================================================
      -- FRIENDLY ARRIVAL: deliver units to the city (original logic)
      -- ================================================================
      FOR v_type, v_qty_txt IN
        SELECT key, value FROM jsonb_each_text(m.units)
      LOOP
        v_qty := v_qty_txt::integer;

        INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
        VALUES (m.destination_city_id, v_type, v_qty, NOW())
        ON CONFLICT (city_id, unit_type)
        DO UPDATE SET
          quantity   = public.city_units.quantity + EXCLUDED.quantity,
          updated_at = NOW();
      END LOOP;

    ELSE
      -- ================================================================
      -- ENEMY ARRIVAL: start a battle or reject if city already in battle
      -- ================================================================

      -- Check whether an active battle already exists at this city
      SELECT EXISTS(
        SELECT 1 FROM public.battles
        WHERE defender_city_id = m.destination_city_id
          AND status = 'active'
      ) INTO v_active_battle;

      IF NOT v_active_battle THEN
        -- Snapshot the defender's current units
        SELECT COALESCE(
          jsonb_object_agg(unit_type, quantity)
            FILTER (WHERE quantity > 0),
          '{}'::jsonb
        )
        INTO v_def_units_snap
        FROM public.city_units
        WHERE city_id = m.destination_city_id;

        -- Create the battle row; first turn resolves 5 minutes from now
        INSERT INTO public.battles (
          defender_city_id,
          attacker_city_id,
          attacker_id,
          defender_id,
          attacker_units,
          defender_units,
          next_turn_at
        )
        SELECT
          m.destination_city_id,
          m.origin_city_id,
          m.owner_id,
          c.owner_id,
          m.units,
          v_def_units_snap,
          NOW() + INTERVAL '5 minutes'
        FROM public.cities c
        WHERE c.id = m.destination_city_id;
      END IF;
      -- If v_active_battle is true, the army is lost (rejected) — units are gone.
    END IF;

    -- Remove the completed movement row — fires Realtime DELETE event
    DELETE FROM public.unit_movements WHERE id = m.id;
  END LOOP;
END;
$$;
