-- Migration: bot helper functions
-- bot_decide_upgrade(): called by run_bot_decisions() to queue a building upgrade or island donation
-- bot_decide_train(): called by run_bot_decisions() to queue unit training
--
-- Both functions mirror the validation logic of their corresponding Edge Functions:
--   bot_decide_upgrade  ←→  upgrade-building/index.ts + donate-island-wood/index.ts
--   bot_decide_train    ←→  train-units/index.ts
--
-- Security model: SECURITY DEFINER SET search_path = '' (same pattern as all cron functions)
-- All table references are fully qualified with public. prefix.

-- ============================================================
-- bot_decide_upgrade
-- ============================================================
-- Attempts to queue the cheapest affordable building upgrade for p_city_id.
-- Falls back to island wood donation if no building is affordable.
-- Returns true if an action was taken, false otherwise.
--
-- Logic:
--   1. Skip if construction_queue already has an entry for this city.
--   2. Find the cheapest affordable building (lowest level, can afford cost).
--   3. If no building affordable, attempt island wood donation.
--   4. If no action possible, return false.

CREATE OR REPLACE FUNCTION public.bot_decide_upgrade(p_city_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  -- Queue check
  v_queue_id        uuid;

  -- Building selection
  v_building_type   text;
  v_current_level   integer;
  v_wood_cost       integer;
  v_marble_cost     integer;
  v_crystal_cost    integer;
  v_sulfur_cost     integer;
  v_gold_cost       integer;

  -- City resources
  v_res_wood        integer;
  v_res_marble      integer;
  v_res_crystal     integer;
  v_res_sulfur      integer;
  v_res_gold        integer;

  -- Construction timing
  v_finish_at       timestamptz;
  v_duration_mins   integer;

  -- Island donation
  v_island_id       uuid;
  v_island_level    integer;
  v_donation_cost   integer;
  v_rows            integer;

  -- Building candidate loop
  b                 RECORD;
  bc                RECORD;  -- base costs
BEGIN

  -- Step 1: Check construction_queue vacancy
  SELECT id INTO v_queue_id
  FROM public.construction_queue
  WHERE city_id = p_city_id
  LIMIT 1;

  IF FOUND THEN
    RETURN false;  -- queue busy
  END IF;

  -- Building base costs (source: supabase/functions/upgrade-building/index.ts BASE_COSTS)
  -- Cost formula: CEIL(base_cost * 1.5^current_level)
  -- town_hall: wood=200, gold=100
  -- warehouse: wood=100, marble=50
  -- barracks: wood=150, gold=100
  -- shipyard: wood=200, marble=100, gold=150
  -- academy: wood=100, crystal=100, gold=200
  -- embassy: wood=80, marble=80, gold=100
  -- trading_port: wood=150, gold=120
  -- town_wall: wood=200, marble=150
  -- hideout: wood=100, gold=80
  -- tavern: wood=120, gold=100
  -- sawmill: wood=50, gold=50
  -- quarry: wood=80, marble=30
  -- glassblower: wood=80, crystal=30
  -- sulfur_pit: wood=80, sulfur=30

  -- Step 2: Load city resources once
  SELECT
    COALESCE(MAX(CASE WHEN resource_type = 'wood'    THEN amount END), 0),
    COALESCE(MAX(CASE WHEN resource_type = 'marble'  THEN amount END), 0),
    COALESCE(MAX(CASE WHEN resource_type = 'crystal' THEN amount END), 0),
    COALESCE(MAX(CASE WHEN resource_type = 'sulfur'  THEN amount END), 0),
    COALESCE(MAX(CASE WHEN resource_type = 'gold'    THEN amount END), 0)
  INTO v_res_wood, v_res_marble, v_res_crystal, v_res_sulfur, v_res_gold
  FROM public.city_resources
  WHERE city_id = p_city_id;

  -- Step 3: Find cheapest upgradeable building (ordered by level ASC = cheapest first)
  FOR b IN
    SELECT cb.building_type, COALESCE(cb.level, 0) AS level
    FROM public.city_buildings cb
    WHERE cb.city_id = p_city_id
    ORDER BY cb.level ASC, cb.building_type ASC
  LOOP
    v_building_type  := b.building_type;
    v_current_level  := b.level;

    -- Compute costs using the base cost VALUES table
    -- Each building has specific resource requirements; zero out unused resources
    SELECT
      CEIL(base_wood    * POWER(1.5, v_current_level)),
      CEIL(base_marble  * POWER(1.5, v_current_level)),
      CEIL(base_crystal * POWER(1.5, v_current_level)),
      CEIL(base_sulfur  * POWER(1.5, v_current_level)),
      CEIL(base_gold    * POWER(1.5, v_current_level))
    INTO v_wood_cost, v_marble_cost, v_crystal_cost, v_sulfur_cost, v_gold_cost
    FROM (
      VALUES
        -- Cost table source: supabase/functions/upgrade-building/index.ts BASE_COSTS
        ('town_hall',    200, 0,   0,   0,   100),
        ('warehouse',    100, 50,  0,   0,   0  ),
        ('barracks',     150, 0,   0,   0,   100),
        ('shipyard',     200, 100, 0,   0,   150),
        ('academy',      100, 0,   100, 0,   200),
        ('embassy',      80,  80,  0,   0,   100),
        ('trading_port', 150, 0,   0,   0,   120),
        ('town_wall',    200, 150, 0,   0,   0  ),
        ('hideout',      100, 0,   0,   0,   80 ),
        ('tavern',       120, 0,   0,   0,   100),
        ('sawmill',      50,  0,   0,   0,   50 ),
        ('quarry',       80,  30,  0,   0,   0  ),
        ('glassblower',  80,  0,   30,  0,   0  ),
        ('sulfur_pit',   80,  0,   0,   30,  0  )
    ) AS costs(building, base_wood, base_marble, base_crystal, base_sulfur, base_gold)
    WHERE costs.building = v_building_type;

    -- Skip if this building type is not in our cost table (unknown building)
    IF NOT FOUND THEN
      CONTINUE;
    END IF;

    -- Check affordability: city must have enough of every required resource
    IF v_res_wood    >= v_wood_cost
       AND v_res_marble  >= v_marble_cost
       AND v_res_crystal >= v_crystal_cost
       AND v_res_sulfur  >= v_sulfur_cost
       AND v_res_gold    >= v_gold_cost
    THEN
      -- Step 5: Affordable building found — deduct resources and queue upgrade
      -- Deduct each non-zero resource type via existing RPC
      IF v_wood_cost    > 0 THEN PERFORM public.deduct_resource(p_city_id, 'wood',    v_wood_cost);    END IF;
      IF v_marble_cost  > 0 THEN PERFORM public.deduct_resource(p_city_id, 'marble',  v_marble_cost);  END IF;
      IF v_crystal_cost > 0 THEN PERFORM public.deduct_resource(p_city_id, 'crystal', v_crystal_cost); END IF;
      IF v_sulfur_cost  > 0 THEN PERFORM public.deduct_resource(p_city_id, 'sulfur',  v_sulfur_cost);  END IF;
      IF v_gold_cost    > 0 THEN PERFORM public.deduct_resource(p_city_id, 'gold',    v_gold_cost);    END IF;

      -- Calculate finish_at: base_time=1 minute, formula CEIL(1 * 1.2^current_level)
      -- (Source: upgrade-building/index.ts BASE_TIMES — all buildings have base 1 minute)
      v_duration_mins := GREATEST(1, CEIL(1.0 * POWER(1.2, v_current_level))::integer);
      v_finish_at     := NOW() + make_interval(mins => v_duration_mins);

      -- Insert into construction_queue; catch race condition from UNIQUE(city_id)
      BEGIN
        INSERT INTO public.construction_queue (city_id, building_type, target_level, finish_at)
        VALUES (p_city_id, v_building_type, v_current_level + 1, v_finish_at);
      EXCEPTION
        WHEN unique_violation THEN  -- SQLSTATE 23505: another process beat us
          RETURN false;
      END;

      RETURN true;
    END IF;

  END LOOP;

  -- Step 4: Island donation fallback — all buildings queued or unaffordable
  SELECT c.island_id, i.resource_level
  INTO v_island_id, v_island_level
  FROM public.cities c
  JOIN public.islands i ON i.id = c.island_id
  WHERE c.id = p_city_id;

  IF NOT FOUND THEN
    RETURN false;  -- city or island not found
  END IF;

  -- Max level check
  IF v_island_level >= 10 THEN
    RETURN false;  -- island already at maximum level
  END IF;

  -- Island donation cost: CEIL(300 * 1.5^resource_level)
  -- Source: supabase/functions/donate-island-wood/index.ts DONATION_COSTS formula
  v_donation_cost := CEIL(300.0 * POWER(1.5, v_island_level));

  -- Check city has enough wood
  IF v_res_wood < v_donation_cost THEN
    RETURN false;  -- insufficient wood for donation
  END IF;

  -- Deduct wood via existing RPC
  PERFORM public.deduct_resource(p_city_id, 'wood', v_donation_cost);

  -- Conditional UPDATE: only increment if level hasn't changed (prevents double-increment)
  -- Source: donate-island-wood/index.ts step 9 — accepted v1 edge case if race occurs
  UPDATE public.islands
  SET resource_level = resource_level + 1
  WHERE id = v_island_id
    AND resource_level = v_island_level;  -- guard: level unchanged since we read it

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  -- v_rows = 0 means another bot donated simultaneously; wood already deducted — accepted v1 edge case

  RETURN true;

END;
$$;


-- ============================================================
-- bot_decide_train
-- ============================================================
-- Attempts to queue unit training for p_city_id using the cheapest affordable land unit.
-- Returns true if training was queued, false otherwise.
--
-- Logic:
--   1. Skip if training_queue already has an entry for this city.
--   2. Check barracks level — skip if barracks not found or level = 0.
--   3. Find cheapest affordable land unit the barracks level allows.
--   4. Calculate max affordable quantity (up to 50).
--   5. Deduct resources and insert training_queue row.

CREATE OR REPLACE FUNCTION public.bot_decide_train(p_city_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  -- Queue check
  v_queue_id       uuid;

  -- Barracks level
  v_barracks_level integer;

  -- City resources
  v_res_wood       integer;
  v_res_marble     integer;
  v_res_crystal    integer;
  v_res_sulfur     integer;
  v_res_gold       integer;

  -- Selected unit
  v_unit_type      text;
  v_unit_wood      integer;
  v_unit_marble    integer;
  v_unit_crystal   integer;
  v_unit_sulfur    integer;
  v_unit_gold      integer;
  v_min_barracks   integer;

  -- Quantity calculation
  v_quantity       integer;
  v_limit          integer;

  -- Training timing
  v_duration_mins  integer;
  v_finish_at      timestamptz;

  -- Unit candidate loop
  u                RECORD;
BEGIN

  -- Step 1: Check training_queue vacancy
  SELECT id INTO v_queue_id
  FROM public.training_queue
  WHERE city_id = p_city_id
  LIMIT 1;

  IF FOUND THEN
    RETURN false;  -- training queue busy
  END IF;

  -- Step 2: Get barracks level
  SELECT level INTO v_barracks_level
  FROM public.city_buildings
  WHERE city_id = p_city_id
    AND building_type = 'barracks';

  IF NOT FOUND OR v_barracks_level = 0 OR v_barracks_level IS NULL THEN
    RETURN false;  -- no barracks or not built yet
  END IF;

  -- Step 3: Load city resources once
  SELECT
    COALESCE(MAX(CASE WHEN resource_type = 'wood'    THEN amount END), 0),
    COALESCE(MAX(CASE WHEN resource_type = 'marble'  THEN amount END), 0),
    COALESCE(MAX(CASE WHEN resource_type = 'crystal' THEN amount END), 0),
    COALESCE(MAX(CASE WHEN resource_type = 'sulfur'  THEN amount END), 0),
    COALESCE(MAX(CASE WHEN resource_type = 'gold'    THEN amount END), 0)
  INTO v_res_wood, v_res_marble, v_res_crystal, v_res_sulfur, v_res_gold
  FROM public.city_resources
  WHERE city_id = p_city_id;

  -- Step 4: Find cheapest affordable land unit the barracks can train
  -- Units ordered by total cost ASC (cheapest first)
  -- Source: supabase/functions/train-units/index.ts UNIT_BASE_COSTS + UNIT_UNLOCK_LEVELS
  --
  -- Unit costs (per unit):
  --   cook:     wood=20, gold=20          (total=40,  barracks >= 1)
  --   hoplite:  wood=40, gold=30          (total=70,  barracks >= 1)
  --   medic:    wood=30, crystal=30, gold=60  (total=120, barracks >= 3)
  --   archer:   wood=50, crystal=20, gold=40  (total=110, barracks >= 2)
  --   phalanx:  wood=60, marble=20, gold=50   (total=130, barracks >= 2)
  --   cavalry:  wood=80, gold=100         (total=180, barracks >= 3)
  --   catapult: wood=120, sulfur=30, gold=80  (total=230, barracks >= 4)
  --   mortar:   wood=100, sulfur=50, gold=120 (total=270, barracks >= 5)

  FOR u IN
    SELECT unit, wood, marble, crystal, sulfur, gold, min_barracks
    FROM (
      VALUES
        -- (unit_type, wood, marble, crystal, sulfur, gold, min_barracks, total_cost)
        -- Cost table source: supabase/functions/train-units/index.ts UNIT_BASE_COSTS
        -- Unlock levels source: supabase/functions/train-units/index.ts UNIT_UNLOCK_LEVELS
        ('cook',     20,  0,  0,  0,   20,  1,  40),
        ('hoplite',  40,  0,  0,  0,   30,  1,  70),
        ('archer',   50,  0,  20, 0,   40,  2, 110),
        ('medic',    30,  0,  30, 0,   60,  3, 120),
        ('phalanx',  60,  20, 0,  0,   50,  2, 130),
        ('cavalry',  80,  0,  0,  0,  100,  3, 180),
        ('catapult', 120, 0,  0,  30,  80,  4, 230),
        ('mortar',   100, 0,  0,  50, 120,  5, 270)
    ) AS units(unit, wood, marble, crystal, sulfur, gold, min_barracks, total_cost)
    ORDER BY total_cost ASC
  LOOP
    -- Skip if barracks level doesn't meet unlock requirement
    IF v_barracks_level < u.min_barracks THEN
      CONTINUE;
    END IF;

    -- Check affordability: city must have enough of every required resource for at least 1 unit
    IF v_res_wood    >= u.wood
       AND v_res_marble  >= u.marble
       AND v_res_crystal >= u.crystal
       AND v_res_sulfur  >= u.sulfur
       AND v_res_gold    >= u.gold
    THEN
      -- Found an affordable unit — record its details
      v_unit_type    := u.unit;
      v_unit_wood    := u.wood;
      v_unit_marble  := u.marble;
      v_unit_crystal := u.crystal;
      v_unit_sulfur  := u.sulfur;
      v_unit_gold    := u.gold;
      v_min_barracks := u.min_barracks;
      EXIT;  -- use first (cheapest) affordable unit
    END IF;
  END LOOP;

  -- Step 5: No affordable land unit found
  IF v_unit_type IS NULL THEN
    RETURN false;
  END IF;

  -- Step 6: Calculate max affordable quantity (up to 50)
  -- quantity = LEAST(50, FLOOR(min_resource / per_unit_cost)) across all required resource types
  -- Source: bot behavior spec — same MAX_QUANTITY = 50 as train-units/index.ts
  v_quantity := 50;  -- start at max, then constrain by each resource

  IF v_unit_wood > 0 THEN
    v_limit := FLOOR(v_res_wood::numeric / v_unit_wood);
    v_quantity := LEAST(v_quantity, v_limit);
  END IF;
  IF v_unit_marble > 0 THEN
    v_limit := FLOOR(v_res_marble::numeric / v_unit_marble);
    v_quantity := LEAST(v_quantity, v_limit);
  END IF;
  IF v_unit_crystal > 0 THEN
    v_limit := FLOOR(v_res_crystal::numeric / v_unit_crystal);
    v_quantity := LEAST(v_quantity, v_limit);
  END IF;
  IF v_unit_sulfur > 0 THEN
    v_limit := FLOOR(v_res_sulfur::numeric / v_unit_sulfur);
    v_quantity := LEAST(v_quantity, v_limit);
  END IF;
  IF v_unit_gold > 0 THEN
    v_limit := FLOOR(v_res_gold::numeric / v_unit_gold);
    v_quantity := LEAST(v_quantity, v_limit);
  END IF;

  -- Clamp to minimum 1 (affordability was checked above; should not reach 0)
  v_quantity := GREATEST(1, v_quantity);

  -- Step 7: Deduct resources for quantity * per_unit_cost
  IF v_unit_wood    > 0 THEN PERFORM public.deduct_resource(p_city_id, 'wood',    v_unit_wood    * v_quantity); END IF;
  IF v_unit_marble  > 0 THEN PERFORM public.deduct_resource(p_city_id, 'marble',  v_unit_marble  * v_quantity); END IF;
  IF v_unit_crystal > 0 THEN PERFORM public.deduct_resource(p_city_id, 'crystal', v_unit_crystal * v_quantity); END IF;
  IF v_unit_sulfur  > 0 THEN PERFORM public.deduct_resource(p_city_id, 'sulfur',  v_unit_sulfur  * v_quantity); END IF;
  IF v_unit_gold    > 0 THEN PERFORM public.deduct_resource(p_city_id, 'gold',    v_unit_gold    * v_quantity); END IF;

  -- Step 8: Calculate finish_at
  -- Base time = 1 minute per unit (train-units/index.ts UNIT_BASE_TIMES: all land units = 1 min)
  -- Dev speed multiplier = 0.2 (train-units/index.ts DEV_SPEED_MULTIPLIER in development)
  -- TODO: parameterize via game_config table when production deployment is planned
  v_duration_mins := GREATEST(1, CEIL(1.0 * v_quantity * 0.2)::integer);
  v_finish_at     := NOW() + make_interval(mins => v_duration_mins);

  -- Step 9: Insert into training_queue; catch race condition from UNIQUE(city_id)
  BEGIN
    INSERT INTO public.training_queue (city_id, unit_type, quantity, finish_at)
    VALUES (p_city_id, v_unit_type, v_quantity, v_finish_at);
  EXCEPTION
    WHEN unique_violation THEN  -- SQLSTATE 23505: another process beat us
      RETURN false;
  END;

  RETURN true;

END;
$$;
