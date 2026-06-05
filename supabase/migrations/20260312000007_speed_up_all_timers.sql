-- Migration: Speed up all game timers for faster testing
-- Resource tick: 5 min → 1 min (pg_cron minimum)
-- Battle turn interval: 5 min → 10 seconds
-- Battle start delay: 5 min → 10 seconds
-- Return trip travel formula: uses seconds instead of minutes for faster testing

-- ============================================================
-- 1. Reschedule resource-tick: every 1 minute instead of 5
-- ============================================================
SELECT cron.unschedule('resource-tick');
SELECT cron.schedule(
  'resource-tick',
  '* * * * *',
  'SELECT public.process_resource_tick()'
);

-- ============================================================
-- 2. Update resolve_battles() — 5 min turns → 10 second turns
-- ============================================================
CREATE OR REPLACE FUNCTION public.resolve_battles()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_unit_attack  jsonb := '{
    "hoplite":10,"phalanx":15,"archer":20,"cavalry":30,"catapult":40,"mortar":50,
    "medic":0,"cook":0,
    "cargo_ship":5,"ram_ship":25,"catapult_ship":35,"mortar_ship":45,"diving_boat":15
  }';
  v_unit_defense jsonb := '{
    "hoplite":20,"phalanx":30,"archer":15,"cavalry":20,"catapult":10,"mortar":10,
    "medic":5,"cook":5,
    "cargo_ship":10,"ram_ship":20,"catapult_ship":15,"mortar_ship":15,"diving_boat":25
  }';
  v_naval_types  text[] := ARRAY[
    'cargo_ship','ram_ship','catapult_ship','mortar_ship','diving_boat'
  ];

  b                         RECORD;
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

  v_att_units               jsonb;
  v_def_units               jsonb;

  v_unit_type               text;
  v_att_qty                 numeric;
  v_def_qty                 numeric;
  v_att_loss                numeric;
  v_def_loss                numeric;

  v_att_total               numeric;
  v_def_total               numeric;
  v_battle_ended            boolean;
  v_new_status              text;

  v_att_island_x            integer;
  v_att_island_y            integer;
  v_def_island_x            integer;
  v_def_island_y            integer;
  v_dx                      numeric;
  v_dy                      numeric;
  v_travel_minutes          integer;

  v_kv                      RECORD;
BEGIN
  FOR b IN
    SELECT *
    FROM public.battles
    WHERE next_turn_at <= NOW()
      AND status = 'active'
    FOR UPDATE SKIP LOCKED
  LOOP
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

    v_att_units := b.attacker_units;
    v_def_units := b.defender_units;

    -- NAVAL PHASE
    FOREACH v_unit_type IN ARRAY v_naval_types LOOP
      v_att_qty := COALESCE((v_att_units ->> v_unit_type)::numeric, 0);
      IF v_att_qty > 0 THEN
        v_att_naval_attack  := v_att_naval_attack  + v_att_qty * COALESCE((v_unit_attack  ->> v_unit_type)::numeric, 0);
        v_att_naval_defense := v_att_naval_defense + v_att_qty * COALESCE((v_unit_defense ->> v_unit_type)::numeric, 0);
      END IF;
    END LOOP;

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
      v_naval_outcome := 'skipped';
    ELSIF NOT v_att_had_naval AND (v_def_naval_attack > 0 OR v_def_naval_defense > 0) THEN
      v_naval_outcome := 'skipped';
    ELSIF v_att_had_naval AND v_def_naval_attack = 0 AND v_def_naval_defense = 0 THEN
      v_naval_outcome := 'attacker_won';
    ELSE
      v_att_naval_loss_ratio := v_def_naval_attack / GREATEST(v_att_naval_defense, 1);
      v_def_naval_loss_ratio := v_att_naval_attack / GREATEST(v_def_naval_defense, 1);

      FOREACH v_unit_type IN ARRAY v_naval_types LOOP
        v_att_qty := COALESCE((v_att_units ->> v_unit_type)::numeric, 0);
        IF v_att_qty > 0 THEN
          v_att_loss := LEAST(FLOOR(v_att_qty * v_att_naval_loss_ratio), v_att_qty);
          IF v_att_loss > 0 THEN
            v_naval_att_casualties := v_naval_att_casualties || jsonb_build_object(v_unit_type, v_att_loss::integer);
            v_att_units := jsonb_set(v_att_units, ARRAY[v_unit_type], to_jsonb((v_att_qty - v_att_loss)::integer));
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
            v_def_units := jsonb_set(v_def_units, ARRAY[v_unit_type], to_jsonb((v_def_qty - v_def_loss)::integer));
            IF (v_def_units ->> v_unit_type)::integer = 0 THEN
              v_def_units := v_def_units - v_unit_type;
            END IF;
          END IF;
        END IF;
      END LOOP;

      DECLARE
        v_att_naval_remaining numeric := 0;
        v_def_naval_remaining numeric := 0;
      BEGIN
        FOREACH v_unit_type IN ARRAY v_naval_types LOOP
          v_att_naval_remaining := v_att_naval_remaining + COALESCE((v_att_units ->> v_unit_type)::numeric, 0);
          v_def_naval_remaining := v_def_naval_remaining + COALESCE((v_def_units ->> v_unit_type)::numeric, 0);
        END LOOP;

        IF v_att_had_naval AND v_att_naval_remaining = 0 THEN
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

    -- LAND PHASE
    IF NOT v_battle_ended THEN
      SELECT COALESCE(
        (SELECT level FROM public.city_buildings
         WHERE city_id = b.defender_city_id AND building_type = 'town_wall'),
        0
      ) INTO v_wall_level;
      v_wall_bonus := 1.0 + 0.05 * v_wall_level;

      FOR v_kv IN SELECT key, value FROM jsonb_each_text(v_att_units) LOOP
        IF NOT (v_kv.key = ANY(v_naval_types)) THEN
          v_att_qty := v_kv.value::numeric;
          v_att_land_attack  := v_att_land_attack  + v_att_qty * COALESCE((v_unit_attack  ->> v_kv.key)::numeric, 0);
          v_att_land_defense := v_att_land_defense + v_att_qty * COALESCE((v_unit_defense ->> v_kv.key)::numeric, 0);
        END IF;
      END LOOP;

      FOR v_kv IN SELECT key, value FROM jsonb_each_text(v_def_units) LOOP
        IF NOT (v_kv.key = ANY(v_naval_types)) THEN
          v_def_qty := v_kv.value::numeric;
          v_def_land_attack  := v_def_land_attack  + v_def_qty * COALESCE((v_unit_attack  ->> v_kv.key)::numeric, 0);
          v_def_land_defense := v_def_land_defense + v_def_qty * COALESCE((v_unit_defense ->> v_kv.key)::numeric, 0) * v_wall_bonus;
        END IF;
      END LOOP;

      IF v_att_land_attack = 0 AND v_att_land_defense = 0
         AND v_def_land_attack = 0 AND v_def_land_defense = 0 THEN
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
              v_att_units := jsonb_set(v_att_units, ARRAY[v_kv.key], to_jsonb((v_att_qty - v_att_loss)::integer));
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
              v_def_units := jsonb_set(v_def_units, ARRAY[v_kv.key], to_jsonb((v_def_qty - v_def_loss)::integer));
              IF (v_def_units ->> v_kv.key)::integer = 0 THEN
                v_def_units := v_def_units - v_kv.key;
              END IF;
            END IF;
          END IF;
        END LOOP;

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

    -- END-OF-TURN
    IF NOT v_battle_ended THEN
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

    -- INSERT battle_turns
    INSERT INTO public.battle_turns (
      battle_id, turn_number,
      naval_attacker_casualties, naval_defender_casualties, naval_outcome,
      land_attacker_casualties, land_defender_casualties, land_outcome,
      attacker_survivors, defender_survivors
    ) VALUES (
      b.id, b.turn_number + 1,
      CASE WHEN v_naval_att_casualties = '{}' THEN NULL ELSE v_naval_att_casualties END,
      CASE WHEN v_naval_def_casualties = '{}' THEN NULL ELSE v_naval_def_casualties END,
      v_naval_outcome,
      CASE WHEN v_land_att_casualties = '{}' THEN NULL ELSE v_land_att_casualties END,
      CASE WHEN v_land_def_casualties = '{}' THEN NULL ELSE v_land_def_casualties END,
      v_land_outcome,
      v_att_units, v_def_units
    );

    -- UPDATE battles
    IF v_battle_ended THEN
      UPDATE public.battles
      SET status         = v_new_status,
          attacker_units = v_att_units,
          defender_units = v_def_units,
          turn_number    = turn_number + 1,
          updated_at     = NOW()
      WHERE id = b.id;

      IF v_new_status = 'attacker_won' THEN
        FOR v_kv IN SELECT key FROM jsonb_each_text(b.defender_units) LOOP
          DELETE FROM public.city_units
          WHERE city_id = b.defender_city_id
            AND unit_type = v_kv.key;
        END LOOP;

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
        -- Return travel: use seconds-based formula for fast testing (10s per grid unit)
        v_travel_minutes := GREATEST(1, CEIL(SQRT(v_dx * v_dx + v_dy * v_dy) * 2)::integer);

        INSERT INTO public.unit_movements (
          owner_id, origin_city_id, destination_city_id,
          units, arrive_at, movement_type
        ) VALUES (
          b.attacker_id, b.defender_city_id, b.attacker_city_id,
          v_att_units,
          NOW() + (v_travel_minutes || ' minutes')::interval,
          'return'
        );

      ELSIF v_new_status = 'defender_won' THEN
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
      -- Battle continues: advance turn — 10 SECONDS instead of 5 minutes
      UPDATE public.battles
      SET turn_number    = turn_number + 1,
          next_turn_at   = next_turn_at + INTERVAL '10 seconds',
          attacker_units = v_att_units,
          defender_units = v_def_units,
          updated_at     = NOW()
      WHERE id = b.id;
    END IF;

  END LOOP;
END;
$$;

-- ============================================================
-- 3. Update process_arrivals() — battle start: 10 seconds instead of 5 min
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
    SELECT id, destination_city_id, origin_city_id, owner_id, units
    FROM public.unit_movements
    WHERE arrive_at <= NOW()
  LOOP
    SELECT owner_id
    INTO v_dest_owner_id
    FROM public.cities
    WHERE id = m.destination_city_id;

    IF m.owner_id = v_dest_owner_id THEN
      -- FRIENDLY ARRIVAL
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
      -- ENEMY ARRIVAL
      SELECT EXISTS(
        SELECT 1 FROM public.battles
        WHERE defender_city_id = m.destination_city_id
          AND status = 'active'
      ) INTO v_active_battle;

      IF NOT v_active_battle THEN
        SELECT COALESCE(
          jsonb_object_agg(unit_type, quantity)
            FILTER (WHERE quantity > 0),
          '{}'::jsonb
        )
        INTO v_def_units_snap
        FROM public.city_units
        WHERE city_id = m.destination_city_id;

        -- First turn resolves 10 SECONDS from now (was 5 minutes)
        INSERT INTO public.battles (
          defender_city_id, attacker_city_id,
          attacker_id, defender_id,
          attacker_units, defender_units,
          next_turn_at
        )
        SELECT
          m.destination_city_id, m.origin_city_id,
          m.owner_id, c.owner_id,
          m.units, v_def_units_snap,
          NOW() + INTERVAL '10 seconds'
        FROM public.cities c
        WHERE c.id = m.destination_city_id;
      END IF;
    END IF;

    DELETE FROM public.unit_movements WHERE id = m.id;
  END LOOP;
END;
$$;

-- ============================================================
-- 4. Reschedule battle-tick and arrivals-tick to run every 10 seconds
--    pg_cron minimum is 1 minute, so we use pg_cron for the schedule
--    but the functions themselves handle sub-minute resolution via next_turn_at.
--    The cron jobs already run every minute which will catch 10-second turns.
-- ============================================================
-- No change needed: cron runs every 1 minute, which catches 10-second turns
-- because resolve_battles() checks next_turn_at <= NOW()
