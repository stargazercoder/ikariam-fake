-- Migration: pillage mechanics — schema additions + updated resolve_battles() + process_arrivals()
-- Adds cargo column to unit_movements, pillage_result column to battles,
-- and updates both functions to support pillage on attacker victory.

-- ============================================================
-- SCHEMA CHANGES
-- ============================================================

-- Nullable JSONB column to carry pillaged resources on return movements.
-- Example value: {"wood": 450, "marble": 200}
ALTER TABLE public.unit_movements ADD COLUMN cargo JSONB;

-- Nullable JSONB column to store the final pillage breakdown on battles.
-- Visible to both attacker and defender via battle reports.
ALTER TABLE public.battles ADD COLUMN pillage_result JSONB;

-- ============================================================
-- REPLACE resolve_battles()
-- Full replacement of 20260312000004_battle_functions.sql version.
-- Adds pillage logic inside the attacker_won branch.
-- ============================================================

CREATE OR REPLACE FUNCTION public.resolve_battles()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  -- Unit stats constants (attack power per unit)
  v_unit_attack  jsonb := '{
    "hoplite":10,"phalanx":15,"archer":20,"cavalry":30,"catapult":40,"mortar":50,
    "medic":0,"cook":0,
    "cargo_ship":5,"ram_ship":25,"catapult_ship":35,"mortar_ship":45,"diving_boat":15
  }';
  -- Unit stats constants (defense power per unit)
  v_unit_defense jsonb := '{
    "hoplite":20,"phalanx":30,"archer":15,"cavalry":20,"catapult":10,"mortar":10,
    "medic":5,"cook":5,
    "cargo_ship":10,"ram_ship":20,"catapult_ship":15,"mortar_ship":15,"diving_boat":25
  }';
  -- Naval unit type list
  v_naval_types  text[] := ARRAY[
    'cargo_ship','ram_ship','catapult_ship','mortar_ship','diving_boat'
  ];

  b                         RECORD;

  -- Naval phase working variables
  v_att_naval_attack        numeric := 0;
  v_att_naval_defense       numeric := 0;
  v_def_naval_attack        numeric := 0;
  v_def_naval_defense       numeric := 0;
  v_att_had_naval           boolean;
  v_att_naval_loss_ratio    numeric;
  v_def_naval_loss_ratio    numeric;
  v_naval_att_casualties    jsonb := '{}';
  v_naval_def_casualties    jsonb := '{}';
  v_naval_outcome           text;

  -- Land phase working variables
  v_wall_level              integer;
  v_wall_bonus              numeric;
  v_att_land_attack         numeric := 0;
  v_att_land_defense        numeric := 0;
  v_def_land_attack         numeric := 0;
  v_def_land_defense        numeric := 0;
  v_att_land_loss_ratio     numeric;
  v_def_land_loss_ratio     numeric;
  v_land_att_casualties     jsonb := '{}';
  v_land_def_casualties     jsonb := '{}';
  v_land_outcome            text;

  -- Mutable unit snapshots
  v_att_units               jsonb;
  v_def_units               jsonb;

  -- Generic iteration
  v_unit_type               text;
  v_att_qty                 numeric;
  v_def_qty                 numeric;
  v_att_loss                numeric;
  v_def_loss                numeric;

  -- End-of-turn totals
  v_att_total               numeric;
  v_def_total               numeric;
  v_battle_ended            boolean;
  v_new_status              text;

  -- Return trip variables
  v_att_island_x            integer;
  v_att_island_y            integer;
  v_def_island_x            integer;
  v_def_island_y            integer;
  v_dx                      numeric;
  v_dy                      numeric;
  v_travel_minutes          integer;

  -- Pair for iterating jsonb_each_text
  v_kv                      RECORD;

  -- Pillage variables
  v_hideout_level           integer;
  v_hideout_floor           numeric;
  v_cargo_cap               numeric;
  v_surviving_cs            numeric;
  v_total_att_land          numeric;
  v_pillage_ratio           numeric;
  v_loot                    jsonb := '{}';
  v_resource_types          text[] := ARRAY['wood','marble','crystal','sulfur'];
  v_res_type                text;
  v_defender_amt            numeric;
  v_unprotected             numeric;
  v_raw_loot                numeric;
  v_total_raw_loot          numeric := 0;
  v_scale                   numeric;
  v_actual_loot             numeric;
BEGIN
  FOR b IN
    SELECT *
    FROM public.battles
    WHERE next_turn_at <= NOW()
      AND status = 'active'
    FOR UPDATE SKIP LOCKED
  LOOP
    -- Reset phase variables for each battle
    v_att_naval_attack  := 0;
    v_att_naval_defense := 0;
    v_def_naval_attack  := 0;
    v_def_naval_defense := 0;
    v_naval_att_casualties := '{}';
    v_naval_def_casualties := '{}';
    v_naval_outcome     := NULL;
    v_att_land_attack   := 0;
    v_att_land_defense  := 0;
    v_def_land_attack   := 0;
    v_def_land_defense  := 0;
    v_land_att_casualties := '{}';
    v_land_def_casualties := '{}';
    v_land_outcome      := NULL;
    v_battle_ended      := false;
    v_new_status        := 'active';
    v_loot              := '{}';
    v_total_raw_loot    := 0;

    -- Work on copies of the JSONB snapshots
    v_att_units := b.attacker_units;
    v_def_units := b.defender_units;

    -- ================================================================
    -- NAVAL PHASE
    -- ================================================================

    -- Sum attacker naval attack and defense
    FOREACH v_unit_type IN ARRAY v_naval_types LOOP
      v_att_qty := COALESCE((v_att_units ->> v_unit_type)::numeric, 0);
      IF v_att_qty > 0 THEN
        v_att_naval_attack  := v_att_naval_attack  + v_att_qty * COALESCE((v_unit_attack  ->> v_unit_type)::numeric, 0);
        v_att_naval_defense := v_att_naval_defense + v_att_qty * COALESCE((v_unit_defense ->> v_unit_type)::numeric, 0);
      END IF;
    END LOOP;

    -- Sum defender naval attack and defense
    FOREACH v_unit_type IN ARRAY v_naval_types LOOP
      v_def_qty := COALESCE((v_def_units ->> v_unit_type)::numeric, 0);
      IF v_def_qty > 0 THEN
        v_def_naval_attack  := v_def_naval_attack  + v_def_qty * COALESCE((v_unit_attack  ->> v_unit_type)::numeric, 0);
        v_def_naval_defense := v_def_naval_defense + v_def_qty * COALESCE((v_unit_defense ->> v_unit_type)::numeric, 0);
      END IF;
    END LOOP;

    v_att_had_naval := (v_att_naval_attack > 0 OR v_att_naval_defense > 0);

    IF v_att_naval_attack = 0 AND v_att_naval_defense = 0
       AND v_def_naval_attack = 0 AND v_def_naval_defense = 0 THEN
      -- Neither side has naval units: skip naval entirely
      v_naval_outcome := 'skipped';

    ELSIF NOT v_att_had_naval AND (v_def_naval_attack > 0 OR v_def_naval_defense > 0) THEN
      -- Attacker has no naval but defender does: skip naval (attacker land can still fight)
      v_naval_outcome := 'skipped';

    ELSIF v_att_had_naval AND v_def_naval_attack = 0 AND v_def_naval_defense = 0 THEN
      -- Attacker has naval but defender has none: attacker wins naval with no casualties
      v_naval_outcome := 'attacker_won';

    ELSE
      -- Both sides have naval units: compute casualties
      v_att_naval_loss_ratio := v_def_naval_attack / GREATEST(v_att_naval_defense, 1);
      v_def_naval_loss_ratio := v_att_naval_attack / GREATEST(v_def_naval_defense, 1);

      FOREACH v_unit_type IN ARRAY v_naval_types LOOP
        v_att_qty := COALESCE((v_att_units ->> v_unit_type)::numeric, 0);
        IF v_att_qty > 0 THEN
          v_att_loss := LEAST(FLOOR(v_att_qty * v_att_naval_loss_ratio), v_att_qty);
          IF v_att_loss > 0 THEN
            v_naval_att_casualties := v_naval_att_casualties || jsonb_build_object(v_unit_type, v_att_loss::integer);
            v_att_units := jsonb_set(
              v_att_units,
              ARRAY[v_unit_type],
              to_jsonb((v_att_qty - v_att_loss)::integer)
            );
            -- Remove zero-quantity entries
            IF (v_att_units ->> v_unit_type)::integer = 0 THEN
              v_att_units := v_att_units - v_unit_type;
            END IF;
          END IF;
        END IF;

        v_def_qty := COALESCE((v_def_units ->> v_unit_type)::numeric, 0);
        IF v_def_qty > 0 THEN
          v_def_loss := LEAST(FLOOR(v_def_qty * v_def_naval_loss_ratio), v_def_qty);
          IF v_def_loss > 0 THEN
            v_naval_def_casualties := v_naval_def_casualties || jsonb_build_object(v_unit_type, v_def_loss::integer);
            v_def_units := jsonb_set(
              v_def_units,
              ARRAY[v_unit_type],
              to_jsonb((v_def_qty - v_def_loss)::integer)
            );
            IF (v_def_units ->> v_unit_type)::integer = 0 THEN
              v_def_units := v_def_units - v_unit_type;
            END IF;
          END IF;
        END IF;
      END LOOP;

      -- Determine naval outcome from surviving units
      DECLARE
        v_att_naval_remaining numeric := 0;
        v_def_naval_remaining numeric := 0;
      BEGIN
        FOREACH v_unit_type IN ARRAY v_naval_types LOOP
          v_att_naval_remaining := v_att_naval_remaining + COALESCE((v_att_units ->> v_unit_type)::numeric, 0);
          v_def_naval_remaining := v_def_naval_remaining + COALESCE((v_def_units ->> v_unit_type)::numeric, 0);
        END LOOP;

        IF v_att_had_naval AND v_att_naval_remaining = 0 THEN
          -- Naval gate-keeper: attacker's naval wiped — defender wins, land units cannot land
          v_naval_outcome := 'defender_won';
          v_land_outcome  := 'blocked';
          v_battle_ended  := true;
          v_new_status    := 'defender_won';
        ELSIF v_def_naval_remaining = 0 THEN
          v_naval_outcome := 'attacker_won';
        ELSE
          v_naval_outcome := 'ongoing';
        END IF;
      END;
    END IF;

    -- ================================================================
    -- LAND PHASE (only when naval gate-keeper did NOT trigger)
    -- ================================================================

    IF NOT v_battle_ended THEN
      -- Get Town Wall level for defense bonus
      SELECT COALESCE(
        (SELECT level FROM public.city_buildings
         WHERE city_id = b.defender_city_id AND building_type = 'town_wall'),
        0
      ) INTO v_wall_level;
      v_wall_bonus := 1.0 + 0.05 * v_wall_level;

      -- Sum attacker land (non-naval) attack and defense
      FOR v_kv IN SELECT key, value FROM jsonb_each_text(v_att_units) LOOP
        IF NOT (v_kv.key = ANY(v_naval_types)) THEN
          v_att_qty := v_kv.value::numeric;
          v_att_land_attack  := v_att_land_attack  + v_att_qty * COALESCE((v_unit_attack  ->> v_kv.key)::numeric, 0);
          v_att_land_defense := v_att_land_defense + v_att_qty * COALESCE((v_unit_defense ->> v_kv.key)::numeric, 0);
        END IF;
      END LOOP;

      -- Sum defender land (non-naval) attack and defense, apply wall bonus to defense
      FOR v_kv IN SELECT key, value FROM jsonb_each_text(v_def_units) LOOP
        IF NOT (v_kv.key = ANY(v_naval_types)) THEN
          v_def_qty := v_kv.value::numeric;
          v_def_land_attack  := v_def_land_attack  + v_def_qty * COALESCE((v_unit_attack  ->> v_kv.key)::numeric, 0);
          v_def_land_defense := v_def_land_defense + v_def_qty * COALESCE((v_unit_defense ->> v_kv.key)::numeric, 0) * v_wall_bonus;
        END IF;
      END LOOP;

      IF v_att_land_attack = 0 AND v_att_land_defense = 0
         AND v_def_land_attack = 0 AND v_def_land_defense = 0 THEN
        -- No land units on either side: land phase produces no result
        v_land_outcome := 'ongoing';
      ELSE
        v_att_land_loss_ratio := v_def_land_attack / GREATEST(v_att_land_defense, 1);
        v_def_land_loss_ratio := v_att_land_attack / GREATEST(v_def_land_defense, 1);

        FOR v_kv IN SELECT key, value FROM jsonb_each_text(v_att_units) LOOP
          IF NOT (v_kv.key = ANY(v_naval_types)) THEN
            v_att_qty := v_kv.value::numeric;
            v_att_loss := LEAST(FLOOR(v_att_qty * v_att_land_loss_ratio), v_att_qty);
            IF v_att_loss > 0 THEN
              v_land_att_casualties := v_land_att_casualties || jsonb_build_object(v_kv.key, v_att_loss::integer);
              v_att_units := jsonb_set(
                v_att_units,
                ARRAY[v_kv.key],
                to_jsonb((v_att_qty - v_att_loss)::integer)
              );
              IF (v_att_units ->> v_kv.key)::integer = 0 THEN
                v_att_units := v_att_units - v_kv.key;
              END IF;
            END IF;
          END IF;
        END LOOP;

        FOR v_kv IN SELECT key, value FROM jsonb_each_text(v_def_units) LOOP
          IF NOT (v_kv.key = ANY(v_naval_types)) THEN
            v_def_qty := v_kv.value::numeric;
            v_def_loss := LEAST(FLOOR(v_def_qty * v_def_land_loss_ratio), v_def_qty);
            IF v_def_loss > 0 THEN
              v_land_def_casualties := v_land_def_casualties || jsonb_build_object(v_kv.key, v_def_loss::integer);
              v_def_units := jsonb_set(
                v_def_units,
                ARRAY[v_kv.key],
                to_jsonb((v_def_qty - v_def_loss)::integer)
              );
              IF (v_def_units ->> v_kv.key)::integer = 0 THEN
                v_def_units := v_def_units - v_kv.key;
              END IF;
            END IF;
          END IF;
        END LOOP;

        -- Land outcome from survivors
        v_att_total := 0;
        v_def_total := 0;
        FOR v_kv IN SELECT key, value FROM jsonb_each_text(v_att_units) LOOP
          IF NOT (v_kv.key = ANY(v_naval_types)) THEN
            v_att_total := v_att_total + v_kv.value::numeric;
          END IF;
        END LOOP;
        FOR v_kv IN SELECT key, value FROM jsonb_each_text(v_def_units) LOOP
          IF NOT (v_kv.key = ANY(v_naval_types)) THEN
            v_def_total := v_def_total + v_kv.value::numeric;
          END IF;
        END LOOP;

        IF v_att_total = 0 THEN
          v_land_outcome := 'defender_won';
        ELSIF v_def_total = 0 THEN
          v_land_outcome := 'attacker_won';
        ELSE
          v_land_outcome := 'ongoing';
        END IF;
      END IF;
    END IF;

    -- ================================================================
    -- END-OF-TURN: check wipeout conditions
    -- ================================================================

    IF NOT v_battle_ended THEN
      -- Count total surviving units for each side
      v_att_total := 0;
      v_def_total := 0;
      FOR v_kv IN SELECT key, value FROM jsonb_each_text(v_att_units) LOOP
        v_att_total := v_att_total + v_kv.value::numeric;
      END LOOP;
      FOR v_kv IN SELECT key, value FROM jsonb_each_text(v_def_units) LOOP
        v_def_total := v_def_total + v_kv.value::numeric;
      END LOOP;

      IF v_att_total = 0 THEN
        v_battle_ended := true;
        v_new_status   := 'defender_won';
        v_land_outcome := COALESCE(v_land_outcome, 'defender_won');
      ELSIF v_def_total = 0 THEN
        v_battle_ended := true;
        v_new_status   := 'attacker_won';
        v_land_outcome := COALESCE(v_land_outcome, 'attacker_won');
      END IF;
    END IF;

    -- ================================================================
    -- INSERT battle_turns record
    -- ================================================================

    INSERT INTO public.battle_turns (
      battle_id,
      turn_number,
      naval_attacker_casualties,
      naval_defender_casualties,
      naval_outcome,
      land_attacker_casualties,
      land_defender_casualties,
      land_outcome,
      attacker_survivors,
      defender_survivors
    ) VALUES (
      b.id,
      b.turn_number + 1,
      CASE WHEN v_naval_att_casualties = '{}' THEN NULL ELSE v_naval_att_casualties END,
      CASE WHEN v_naval_def_casualties = '{}' THEN NULL ELSE v_naval_def_casualties END,
      v_naval_outcome,
      CASE WHEN v_land_att_casualties = '{}' THEN NULL ELSE v_land_att_casualties END,
      CASE WHEN v_land_def_casualties = '{}' THEN NULL ELSE v_land_def_casualties END,
      v_land_outcome,
      v_att_units,
      v_def_units
    );

    -- ================================================================
    -- UPDATE battles row + pillage logic (attacker_won branch)
    -- ================================================================

    IF v_battle_ended THEN

      IF v_new_status = 'attacker_won' THEN
        -- Clear defender's units that participated (types in original battle snapshot)
        FOR v_kv IN SELECT key FROM jsonb_each_text(b.defender_units) LOOP
          DELETE FROM public.city_units
          WHERE city_id = b.defender_city_id
            AND unit_type = v_kv.key;
        END LOOP;

        -- ============================================================
        -- PILLAGE LOGIC
        -- ============================================================

        -- Step P1: Count surviving cargo ships
        v_surviving_cs := COALESCE((v_att_units->>'cargo_ship')::numeric, 0);
        v_cargo_cap := v_surviving_cs * 500;

        -- Step P2: If no cargo ships, skip pillage entirely
        IF v_cargo_cap > 0 THEN
          -- Step P3: Get Hideout level — COALESCE handles missing hideout row.
          -- Per user decision: base protection = 50 per resource even without Hideout built.
          SELECT level INTO v_hideout_level
          FROM public.city_buildings
          WHERE city_id = b.defender_city_id AND building_type = 'hideout';

          -- If no row was found at all, SELECT INTO leaves v_hideout_level NULL → treat as -1
          IF v_hideout_level IS NULL THEN
            v_hideout_level := -1;
          END IF;

          -- Base 50 protection for cities without Hideout; otherwise 100 * 1.5^level
          v_hideout_floor := CASE
            WHEN v_hideout_level < 0 THEN 50
            ELSE FLOOR(100.0 * POWER(1.5, v_hideout_level))
          END;

          -- Step P4: Pillage ratio from surviving land attackers
          v_total_att_land := 0;
          FOR v_kv IN SELECT key, value FROM jsonb_each_text(v_att_units) LOOP
            IF NOT (v_kv.key = ANY(v_naval_types)) THEN
              v_total_att_land := v_total_att_land + v_kv.value::numeric;
            END IF;
          END LOOP;
          v_pillage_ratio := LEAST(0.75, v_total_att_land / 50.0 * 0.10);

          -- Step P5: Compute raw loot per resource (SELECT FOR UPDATE prevents race with resource tick)
          v_total_raw_loot := 0;
          FOREACH v_res_type IN ARRAY v_resource_types LOOP
            SELECT COALESCE(amount, 0)
            INTO v_defender_amt
            FROM public.city_resources
            WHERE city_id = b.defender_city_id AND resource_type = v_res_type
            FOR UPDATE;

            v_unprotected := GREATEST(0, v_defender_amt - v_hideout_floor);
            v_raw_loot := FLOOR(v_unprotected * v_pillage_ratio);
            IF v_raw_loot > 0 THEN
              v_loot := v_loot || jsonb_build_object(v_res_type, v_raw_loot::integer);
              v_total_raw_loot := v_total_raw_loot + v_raw_loot;
            END IF;
          END LOOP;

          -- Step P6: Apply cargo capacity cap (proportional scaling)
          IF v_total_raw_loot > v_cargo_cap THEN
            v_scale := v_cargo_cap / v_total_raw_loot;
            v_loot := '{}';
            v_total_raw_loot := 0;
            FOREACH v_res_type IN ARRAY v_resource_types LOOP
              SELECT COALESCE(amount, 0) INTO v_defender_amt
              FROM public.city_resources
              WHERE city_id = b.defender_city_id AND resource_type = v_res_type;

              v_unprotected := GREATEST(0, v_defender_amt - v_hideout_floor);
              v_raw_loot := FLOOR(v_unprotected * v_pillage_ratio);
              v_actual_loot := FLOOR(v_raw_loot * v_scale);
              IF v_actual_loot > 0 THEN
                v_loot := v_loot || jsonb_build_object(v_res_type, v_actual_loot::integer);
              END IF;
            END LOOP;
          END IF;

          -- Step P7: Deduct from defender city resources
          FOR v_kv IN SELECT key, value FROM jsonb_each_text(v_loot) LOOP
            UPDATE public.city_resources
            SET amount = amount - v_kv.value::numeric,
                updated_at = NOW()
            WHERE city_id = b.defender_city_id AND resource_type = v_kv.key;
          END LOOP;
        END IF;  -- end cargo_cap > 0

        -- ============================================================
        -- END PILLAGE LOGIC
        -- ============================================================

        -- Compute return travel time using island grid coordinates
        SELECT i.grid_x, i.grid_y
        INTO v_att_island_x, v_att_island_y
        FROM public.cities c
        JOIN public.islands i ON i.id = c.island_id
        WHERE c.id = b.attacker_city_id;

        SELECT i.grid_x, i.grid_y
        INTO v_def_island_x, v_def_island_y
        FROM public.cities c
        JOIN public.islands i ON i.id = c.island_id
        WHERE c.id = b.defender_city_id;

        v_dx := ABS(v_att_island_x - v_def_island_x)::numeric;
        v_dy := ABS(v_att_island_y - v_def_island_y)::numeric;
        -- Formula matches Dart calcTravelMinutes: max(1, ceil(sqrt(dx^2+dy^2) * 2))
        v_travel_minutes := GREATEST(1, CEIL(SQRT(v_dx * v_dx + v_dy * v_dy) * 2)::integer);

        -- Update battles row with pillage_result
        UPDATE public.battles
        SET status         = v_new_status,
            attacker_units = v_att_units,
            defender_units = v_def_units,
            turn_number    = turn_number + 1,
            pillage_result = CASE WHEN v_loot = '{}' THEN NULL ELSE v_loot END,
            updated_at     = NOW()
        WHERE id = b.id;

        -- Create return movement for surviving attacker units, with cargo
        INSERT INTO public.unit_movements (
          owner_id,
          origin_city_id,
          destination_city_id,
          units,
          arrive_at,
          movement_type,
          cargo
        ) VALUES (
          b.attacker_id,
          b.defender_city_id,
          b.attacker_city_id,
          v_att_units,
          NOW() + (v_travel_minutes || ' minutes')::interval,
          'return',
          CASE WHEN v_loot = '{}' THEN NULL ELSE v_loot END
        );

      ELSIF v_new_status = 'defender_won' THEN
        -- Update battles row (pillage_result stays NULL for defender victory)
        UPDATE public.battles
        SET status         = v_new_status,
            attacker_units = v_att_units,
            defender_units = v_def_units,
            turn_number    = turn_number + 1,
            pillage_result = NULL,
            updated_at     = NOW()
        WHERE id = b.id;

        -- Restore defender's city_units from the surviving snapshot
        FOR v_kv IN SELECT key, value FROM jsonb_each_text(v_def_units) LOOP
          INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
          VALUES (b.defender_city_id, v_kv.key, v_kv.value::integer, NOW())
          ON CONFLICT (city_id, unit_type)
          DO UPDATE SET
            quantity   = EXCLUDED.quantity,
            updated_at = NOW();
        END LOOP;
      END IF;

    ELSE
      -- Battle continues: advance turn and set next resolution time
      UPDATE public.battles
      SET turn_number    = turn_number + 1,
          next_turn_at   = next_turn_at + INTERVAL '5 minutes',
          attacker_units = v_att_units,
          defender_units = v_def_units,
          updated_at     = NOW()
      WHERE id = b.id;
    END IF;

  END LOOP;
END;
$$;

-- ============================================================
-- REPLACE process_arrivals()
-- Full replacement of 20260312000005_modify_process_arrivals.sql version.
-- Adds cargo delivery in the friendly arrival branch.
-- ============================================================

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
    SELECT id, destination_city_id, origin_city_id, owner_id, units, cargo
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

      -- Deliver pillaged resources from cargo (if any)
      IF m.cargo IS NOT NULL THEN
        FOR v_type, v_qty_txt IN
          SELECT key, value FROM jsonb_each_text(m.cargo)
        LOOP
          v_qty := v_qty_txt::integer;
          IF v_qty > 0 THEN
            UPDATE public.city_resources
            SET amount = amount + v_qty,
                updated_at = NOW()
            WHERE city_id = m.destination_city_id AND resource_type = v_type;
          END IF;
        END LOOP;
      END IF;

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
