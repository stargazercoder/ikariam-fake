-- Fix dev_trigger_battle to snapshot city_units into battle instead of empty JSON.
-- Previously both attacker_units and defender_units were set to '{}',
-- causing "No Units" for both sides.

CREATE OR REPLACE FUNCTION public.dev_trigger_battle(
  p_attacker_city_id uuid,
  p_defender_city_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_attacker_id  uuid;
  v_defender_id  uuid;
  v_battle_id    uuid;
  v_att_units    jsonb;
  v_def_units    jsonb;
BEGIN
  -- Resolve owner IDs from city IDs
  SELECT owner_id INTO v_attacker_id
    FROM public.cities
    WHERE id = p_attacker_city_id;

  SELECT owner_id INTO v_defender_id
    FROM public.cities
    WHERE id = p_defender_city_id;

  -- Snapshot attacker units from city_units (only units with quantity > 0)
  SELECT COALESCE(jsonb_object_agg(unit_type, quantity), '{}'::jsonb)
    INTO v_att_units
    FROM public.city_units
    WHERE city_id = p_attacker_city_id AND quantity > 0;

  -- Snapshot defender units from city_units (only units with quantity > 0)
  SELECT COALESCE(jsonb_object_agg(unit_type, quantity), '{}'::jsonb)
    INTO v_def_units
    FROM public.city_units
    WHERE city_id = p_defender_city_id AND quantity > 0;

  -- Insert the active battle row with actual unit snapshots
  INSERT INTO public.battles (
    attacker_id,
    defender_id,
    attacker_city_id,
    defender_city_id,
    attacker_units,
    defender_units,
    status,
    turn_number,
    next_turn_at
  ) VALUES (
    v_attacker_id,
    v_defender_id,
    p_attacker_city_id,
    p_defender_city_id,
    v_att_units,
    v_def_units,
    'active',
    0,
    NOW() + INTERVAL '30 seconds'
  )
  RETURNING id INTO v_battle_id;

  RETURN v_battle_id;
END;
$$;
