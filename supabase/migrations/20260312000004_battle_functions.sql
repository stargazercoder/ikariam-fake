-- Migration: battle resolution function
-- resolve_battles(): called every minute by battle-tick cron job.
-- Processes all battles whose next_turn_at <= NOW().
-- Runs naval phase first, then land phase. Naval gate-keeper: if attacker's naval
-- units are wiped this turn, battle ends immediately with defender victory.
-- All unit stats are constants inside the function body (not a DB table) so
-- rebalancing does not require a schema migration.

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
    -- UPDATE battles row
    -- ================================================================

    IF v_battle_ended THEN
      UPDATE public.battles
      SET status         = v_new_status,
          attacker_units = v_att_units,
          defender_units = v_def_units,
          turn_number    = turn_number + 1,
          updated_at     = NOW()
      WHERE id = b.id;

      IF v_new_status = 'attacker_won' THEN
        -- Clear defender's units that participated (types in original battle snapshot)
        FOR v_kv IN SELECT key FROM jsonb_each_text(b.defender_units) LOOP
          DELETE FROM public.city_units
          WHERE city_id = b.defender_city_id
            AND unit_type = v_kv.key;
        END LOOP;

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

        -- Create return movement for surviving attacker units
        INSERT INTO public.unit_movements (
          owner_id,
          origin_city_id,
          destination_city_id,
          units,
          arrive_at,
          movement_type
        ) VALUES (
          b.attacker_id,
          b.defender_city_id,
          b.attacker_city_id,
          v_att_units,
          NOW() + (v_travel_minutes || ' minutes')::interval,
          'return'
        );

      ELSIF v_new_status = 'defender_won' THEN
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
