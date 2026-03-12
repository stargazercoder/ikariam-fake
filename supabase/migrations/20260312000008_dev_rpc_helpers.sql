-- ============================================================
-- DEV ONLY — these functions bypass RLS and should NOT be
-- deployed to a production Supabase instance.
-- They exist solely to support the in-app dev toolbar
-- (DevToolbarWidget, gated by kDebugMode) for rapid local
-- testing. Remove this migration before going to production.
-- ============================================================

-- ============================================================
-- dev_inject_resources
-- Adds resources to a city, capped at 99999 per type.
-- Used by dev toolbar "Inject Resources" action.
-- ============================================================
CREATE OR REPLACE FUNCTION public.dev_inject_resources(
  p_city_id  uuid,
  p_wood     int DEFAULT 5000,
  p_marble   int DEFAULT 5000,
  p_crystal  int DEFAULT 5000,
  p_sulfur   int DEFAULT 5000,
  p_gold     int DEFAULT 5000
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  UPDATE public.city_resources
    SET amount = LEAST(amount + p_wood, 99999)
    WHERE city_id = p_city_id AND resource_type = 'wood';

  UPDATE public.city_resources
    SET amount = LEAST(amount + p_marble, 99999)
    WHERE city_id = p_city_id AND resource_type = 'marble';

  UPDATE public.city_resources
    SET amount = LEAST(amount + p_crystal, 99999)
    WHERE city_id = p_city_id AND resource_type = 'crystal';

  UPDATE public.city_resources
    SET amount = LEAST(amount + p_sulfur, 99999)
    WHERE city_id = p_city_id AND resource_type = 'sulfur';

  UPDATE public.city_resources
    SET amount = LEAST(amount + p_gold, 99999)
    WHERE city_id = p_city_id AND resource_type = 'gold';
END;
$$;

-- ============================================================
-- dev_level_up_building
-- Sets a building's level. If p_target_level = 0, increments
-- current level by 1. Otherwise sets to exact target level.
-- Used by dev toolbar "Level Up Building" action.
-- ============================================================
CREATE OR REPLACE FUNCTION public.dev_level_up_building(
  p_city_id      uuid,
  p_building_type text,
  p_target_level  int DEFAULT 0
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF p_target_level = 0 THEN
    UPDATE public.city_buildings
      SET level = level + 1
      WHERE city_id = p_city_id AND building_type = p_building_type;
  ELSE
    UPDATE public.city_buildings
      SET level = p_target_level
      WHERE city_id = p_city_id AND building_type = p_building_type;
  END IF;
END;
$$;

-- ============================================================
-- dev_spawn_units
-- Spawns units in a city army roster. If unit type already
-- exists, adds to existing quantity.
-- Used by dev toolbar "Spawn Units" action.
-- ============================================================
CREATE OR REPLACE FUNCTION public.dev_spawn_units(
  p_city_id   uuid,
  p_unit_type text,
  p_quantity  int DEFAULT 50
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.city_units (city_id, unit_type, quantity)
    VALUES (p_city_id, p_unit_type, p_quantity)
    ON CONFLICT (city_id, unit_type)
    DO UPDATE SET quantity = public.city_units.quantity + EXCLUDED.quantity;
END;
$$;

-- ============================================================
-- dev_trigger_battle
-- Creates an active battle between two cities immediately.
-- Returns the new battle UUID.
-- Used by dev toolbar "Trigger Battle" action.
-- ============================================================
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
BEGIN
  -- Resolve owner IDs from city IDs
  SELECT owner_id INTO v_attacker_id
    FROM public.cities
    WHERE id = p_attacker_city_id;

  SELECT owner_id INTO v_defender_id
    FROM public.cities
    WHERE id = p_defender_city_id;

  -- Insert the active battle row
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
    '{}'::jsonb,
    '{}'::jsonb,
    'active',
    0,
    NOW() + INTERVAL '30 seconds'
  )
  RETURNING id INTO v_battle_id;

  RETURN v_battle_id;
END;
$$;
