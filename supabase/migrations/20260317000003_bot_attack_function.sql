-- Migration: bot attack helper function
-- bot_decide_attack(): called by run_bot_decisions() to dispatch an attack
--   against a random non-bot city on the same island, or globally as fallback.
--
-- Security model: SECURITY DEFINER SET search_path = '' (same pattern as all cron functions)
-- All table references are fully qualified with public. prefix.

-- ============================================================
-- bot_decide_attack
-- ============================================================
-- Attempts to launch an attack from p_city_id given the bot's aggression level.
-- Returns void (fire-and-forget; orchestrator does not branch on attack result).
--
-- Logic:
--   1. Aggression probability gate: random() >= (aggression / 3.0) → RETURN early.
--      (Aggression 0 always skips since 0/3.0 = 0.0 and random() is always >= 0.0)
--   2. Count total land units; skip if < 5 (not enough army to attack).
--   3. Target selection: same island first, then any non-bot city globally.
--      If no valid target found, RETURN early.
--   4. Calculate send_count: 50-75% of total land units (at least 1).
--   5. Iterate city_units in DESC quantity order, accumulate units into JSONB,
--      deduct each via deduct_units().
--   6. Get bot owner_id.
--   7. Calculate travel time using grid distance formula with dev speed multiplier 0.2.
--   8. INSERT into unit_movements with movement_type = 'attack'.

CREATE OR REPLACE FUNCTION public.bot_decide_attack(p_city_id uuid, p_aggression integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  -- Army check
  v_total_land      bigint;

  -- Target selection
  v_target_city_id  uuid;

  -- Send count + unit distribution
  v_send_count      integer;
  v_units_json      jsonb;
  v_remaining       integer;
  v_take            integer;
  v_unit            RECORD;

  -- Owner
  v_bot_owner_id    uuid;

  -- Travel time calculation
  v_origin_x        integer;
  v_origin_y        integer;
  v_dest_x          integer;
  v_dest_y          integer;
  v_distance        numeric;
  v_raw_minutes     integer;
  v_travel_minutes  integer;
BEGIN

  -- Step 1: Aggression probability gate
  -- Aggression 0 → 0/3.0 = 0.0 → random() always >= 0.0 → always RETURN (passive bot never attacks)
  -- Aggression 1 → skip 66.7% of ticks
  -- Aggression 2 → skip 33.3% of ticks
  -- Aggression 3 → skip 0% of ticks (always attacks when eligible)
  IF random() >= (p_aggression / 3.0) THEN
    RETURN;
  END IF;

  -- Step 2: Count total land units
  SELECT COALESCE(SUM(quantity), 0) INTO v_total_land
  FROM public.city_units
  WHERE city_id = p_city_id
    AND unit_type IN ('hoplite', 'phalanx', 'archer', 'cavalry', 'catapult', 'mortar', 'medic', 'cook');

  IF v_total_land < 5 THEN
    RETURN;  -- not enough army to form an attack party
  END IF;

  -- Step 3a: Target selection — same island first (prefer local targets)
  SELECT c.id INTO v_target_city_id
  FROM public.cities c
  JOIN public.profiles p ON p.id = c.owner_id
  WHERE c.island_id = (SELECT island_id FROM public.cities WHERE id = p_city_id)
    AND c.id <> p_city_id
    AND p.is_bot = false
  ORDER BY random() LIMIT 1;

  -- Step 3b: Fallback — any non-bot city globally
  IF NOT FOUND THEN
    SELECT c.id INTO v_target_city_id
    FROM public.cities c
    JOIN public.profiles p ON p.id = c.owner_id
    WHERE p.is_bot = false
      AND c.id <> p_city_id
    ORDER BY random() LIMIT 1;
  END IF;

  -- Step 3c: No valid target found anywhere — bail out
  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Step 4: Determine how many units to send (50-75% of total land units, at least 1)
  v_send_count := GREATEST(1, FLOOR(v_total_land * (0.50 + random() * 0.25))::int);

  -- Step 5: Build units JSONB and deduct from city_units
  -- Iterate in DESC quantity order to drain largest stacks first
  v_units_json := '{}'::jsonb;
  v_remaining  := v_send_count;

  FOR v_unit IN
    SELECT unit_type, quantity
    FROM public.city_units
    WHERE city_id = p_city_id
      AND unit_type IN ('hoplite', 'phalanx', 'archer', 'cavalry', 'catapult', 'mortar', 'medic', 'cook')
      AND quantity > 0
    ORDER BY quantity DESC
  LOOP
    v_take := LEAST(v_unit.quantity, v_remaining);
    v_units_json := v_units_json || jsonb_build_object(v_unit.unit_type, v_take);
    PERFORM public.deduct_units(p_city_id, v_unit.unit_type, v_take);
    v_remaining := v_remaining - v_take;
    EXIT WHEN v_remaining <= 0;
  END LOOP;

  -- Guard: if no units were actually accumulated (edge case), abort
  IF v_units_json = '{}'::jsonb THEN
    RETURN;
  END IF;

  -- Step 6: Resolve bot owner
  SELECT owner_id INTO v_bot_owner_id
  FROM public.cities
  WHERE id = p_city_id;

  -- Step 7: Calculate travel time
  -- Formula: distance = sqrt(dx^2 + dy^2) from grid coordinates
  --          raw_minutes = GREATEST(1, CEIL(distance * 2.0))
  --          travel_minutes = GREATEST(1, CEIL(raw_minutes * 0.2))   -- 0.2 = dev speed multiplier
  -- TODO: parameterize dev speed multiplier via game_config table when production deployment is planned

  SELECT i.grid_x, i.grid_y INTO v_origin_x, v_origin_y
  FROM public.islands i
  JOIN public.cities c ON c.island_id = i.id
  WHERE c.id = p_city_id;

  SELECT i.grid_x, i.grid_y INTO v_dest_x, v_dest_y
  FROM public.islands i
  JOIN public.cities c ON c.island_id = i.id
  WHERE c.id = v_target_city_id;

  v_distance       := sqrt(POWER(v_dest_x - v_origin_x, 2.0) + POWER(v_dest_y - v_origin_y, 2.0));
  v_raw_minutes    := GREATEST(1, CEIL(v_distance * 2.0));
  v_travel_minutes := GREATEST(1, CEIL(v_raw_minutes * 0.2));

  -- Step 8: Dispatch the attack by inserting into unit_movements
  -- movement_type = 'attack' is required by CHECK (movement_type IN ('attack', 'return', 'trade'))
  INSERT INTO public.unit_movements (
    origin_city_id,
    destination_city_id,
    owner_id,
    units,
    movement_type,
    depart_at,
    arrive_at
  ) VALUES (
    p_city_id,
    v_target_city_id,
    v_bot_owner_id,
    v_units_json,
    'attack',
    NOW(),
    NOW() + make_interval(mins => v_travel_minutes::int)
  );

END;
$$;
