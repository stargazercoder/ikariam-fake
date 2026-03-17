-- Migration: GodMode SECURITY DEFINER RPCs
-- All five functions enforce an admin guard (is_admin check on auth.uid()).
-- Non-admin callers raise SQLSTATE 42501 (insufficient_privilege).
-- search_path = '' forces all table references to use public. prefix.
--
-- Architecture decision (STATE.md):
--   GodMode uses SECURITY DEFINER RPCs with is_admin Postgres check.
--   service_role key must never appear in any Flutter file.

-- ============================================================
-- RPC 1: godmode_get_world_state
-- Returns full world snapshot: all players with resources, army,
-- buildings, bot status, and active battles.
-- ============================================================

CREATE OR REPLACE FUNCTION public.godmode_get_world_state()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_caller_id uuid;
  v_is_admin  boolean;
  v_result    jsonb;
BEGIN
  v_caller_id := auth.uid();
  SELECT is_admin INTO v_is_admin FROM public.profiles WHERE id = v_caller_id;
  IF NOT FOUND OR v_is_admin IS NOT TRUE THEN
    RAISE EXCEPTION 'permission denied: admin access required'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT jsonb_build_object(
    'players',
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id',          p.id,
          'display_name', p.display_name,
          'is_bot',      p.is_bot,
          'is_paused',   bs.is_paused,
          'resources',   (
            SELECT jsonb_object_agg(cr.resource_type, cr.amount)
            FROM public.city_resources cr
            WHERE cr.city_id = c.id
          ),
          'army', jsonb_build_object(
            'land_count', COALESCE((
              SELECT SUM(cu.quantity)
              FROM public.city_units cu
              WHERE cu.city_id = c.id
                AND cu.unit_type IN (
                  'hoplite', 'phalanx', 'archer', 'cavalry',
                  'catapult', 'mortar', 'medic', 'cook'
                )
            ), 0),
            'naval_count', COALESCE((
              SELECT SUM(cu.quantity)
              FROM public.city_units cu
              WHERE cu.city_id = c.id
                AND cu.unit_type IN (
                  'cargo_ship', 'ram_ship', 'catapult_ship',
                  'mortar_ship', 'diving_boat'
                )
            ), 0)
          ),
          'buildings', (
            SELECT jsonb_object_agg(cb.building_type, cb.level)
            FROM public.city_buildings cb
            WHERE cb.city_id = c.id
          ),
          'active_battles', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
              'battle_id',      b.id,
              'attacker_name',  (SELECT display_name FROM public.profiles WHERE id = b.attacker_id),
              'defender_name',  (SELECT display_name FROM public.profiles WHERE id = b.defender_id),
              'current_turn',   b.current_turn
            )), '[]'::jsonb)
            FROM public.battles b
            WHERE (b.attacker_id = p.id OR b.defender_id = p.id)
              AND b.status = 'active'
          )
        )
      ),
      '[]'::jsonb
    )
  )
  INTO v_result
  FROM public.profiles p
  JOIN public.cities c ON c.owner_id = p.id
  LEFT JOIN public.bot_schedules bs ON bs.bot_id = p.id;

  RETURN v_result;
END;
$$;

-- ============================================================
-- RPC 2: godmode_set_bot_paused
-- Pauses or unpauses a bot's scheduled decision cycle.
-- ============================================================

CREATE OR REPLACE FUNCTION public.godmode_set_bot_paused(
  p_bot_id uuid,
  p_paused  boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_caller_id uuid;
  v_is_admin  boolean;
BEGIN
  v_caller_id := auth.uid();
  SELECT is_admin INTO v_is_admin FROM public.profiles WHERE id = v_caller_id;
  IF NOT FOUND OR v_is_admin IS NOT TRUE THEN
    RAISE EXCEPTION 'permission denied: admin access required'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  UPDATE public.bot_schedules SET is_paused = p_paused WHERE bot_id = p_bot_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bot not found: %', p_bot_id USING ERRCODE = 'no_data_found';
  END IF;
END;
$$;

-- ============================================================
-- RPC 3: godmode_force_action
-- Runs one bot decision cycle immediately without updating
-- next_action_at (out-of-band; must not disrupt cron schedule).
-- Returns text label of the action taken: 'upgrade', 'train',
-- 'attack', or 'none'.
-- ============================================================

CREATE OR REPLACE FUNCTION public.godmode_force_action(
  p_bot_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_caller_id  uuid;
  v_is_admin   boolean;
  v_city_id    uuid;
  v_aggression numeric;
BEGIN
  v_caller_id := auth.uid();
  SELECT is_admin INTO v_is_admin FROM public.profiles WHERE id = v_caller_id;
  IF NOT FOUND OR v_is_admin IS NOT TRUE THEN
    RAISE EXCEPTION 'permission denied: admin access required'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT c.id AS city_id, bs.aggression
  INTO v_city_id, v_aggression
  FROM public.profiles p
  JOIN public.cities c ON c.owner_id = p.id
  JOIN public.bot_schedules bs ON bs.bot_id = p.id
  WHERE p.id = p_bot_id AND p.is_bot = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'bot not found: %', p_bot_id USING ERRCODE = 'no_data_found';
  END IF;

  -- Priority chain mirrors run_bot_decisions but does NOT update next_action_at.
  -- Forced actions are out-of-band and must not interfere with the regular cron schedule.
  IF public.bot_decide_upgrade(v_city_id) THEN
    RETURN 'upgrade';
  END IF;
  IF public.bot_decide_train(v_city_id) THEN
    RETURN 'train';
  END IF;
  IF v_aggression > 0 THEN
    PERFORM public.bot_decide_attack(v_city_id, v_aggression);
    RETURN 'attack';
  END IF;
  RETURN 'none';
END;
$$;

-- ============================================================
-- RPC 4: admin_set_resources
-- Sets resource balances for a player's city, clamped to 0 minimum.
-- TODO: one city per player assumed (v1.3); extend to accept city_id
--       if multi-city support is added in a future milestone.
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_set_resources(
  p_player_id uuid,
  p_wood      numeric,
  p_marble    numeric,
  p_crystal   numeric,
  p_sulfur    numeric,
  p_gold      numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_caller_id uuid;
  v_is_admin  boolean;
  v_city_id   uuid;
BEGIN
  v_caller_id := auth.uid();
  SELECT is_admin INTO v_is_admin FROM public.profiles WHERE id = v_caller_id;
  IF NOT FOUND OR v_is_admin IS NOT TRUE THEN
    RAISE EXCEPTION 'permission denied: admin access required'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- TODO: one city per player assumed (v1.3); extend to accept city_id if multi-city added
  SELECT id INTO v_city_id FROM public.cities WHERE owner_id = p_player_id LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'player city not found: %', p_player_id USING ERRCODE = 'no_data_found';
  END IF;

  UPDATE public.city_resources SET amount = GREATEST(p_wood, 0),   updated_at = NOW()
    WHERE city_id = v_city_id AND resource_type = 'wood';
  UPDATE public.city_resources SET amount = GREATEST(p_marble, 0), updated_at = NOW()
    WHERE city_id = v_city_id AND resource_type = 'marble';
  UPDATE public.city_resources SET amount = GREATEST(p_crystal, 0), updated_at = NOW()
    WHERE city_id = v_city_id AND resource_type = 'crystal';
  UPDATE public.city_resources SET amount = GREATEST(p_sulfur, 0), updated_at = NOW()
    WHERE city_id = v_city_id AND resource_type = 'sulfur';
  UPDATE public.city_resources SET amount = GREATEST(p_gold, 0),   updated_at = NOW()
    WHERE city_id = v_city_id AND resource_type = 'gold';
END;
$$;

-- ============================================================
-- RPC 5: godmode_get_events
-- Returns a JSONB array of recent events from battles,
-- unit_movements (trades), and spy_reports, ordered newest first.
-- p_limit defaults to 50; p_event_type filters to a single type
-- ('battle', 'trade', 'espionage') when provided.
-- ============================================================

CREATE OR REPLACE FUNCTION public.godmode_get_events(
  p_limit      integer DEFAULT 50,
  p_event_type text    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_caller_id uuid;
  v_is_admin  boolean;
  v_result    jsonb;
BEGIN
  v_caller_id := auth.uid();
  SELECT is_admin INTO v_is_admin FROM public.profiles WHERE id = v_caller_id;
  IF NOT FOUND OR v_is_admin IS NOT TRUE THEN
    RAISE EXCEPTION 'permission denied: admin access required'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  WITH battle_events AS (
    SELECT b.created_at AS event_time, 'battle' AS event_type,
      jsonb_build_object(
        'battle_id',   b.id,
        'attacker',    (SELECT display_name FROM public.profiles WHERE id = b.attacker_id),
        'defender',    (SELECT display_name FROM public.profiles WHERE id = b.defender_id),
        'summary',     'Battle turn ' || b.current_turn || ' — ' || b.status
      ) AS detail
    FROM public.battles b
    WHERE (p_event_type IS NULL OR p_event_type = 'battle')
  ),
  trade_events AS (
    SELECT um.created_at AS event_time, 'trade' AS event_type,
      jsonb_build_object(
        'movement_id',       um.id,
        'sender',            (SELECT display_name FROM public.profiles WHERE id = um.owner_id),
        'destination_city',  (SELECT name FROM public.cities WHERE id = um.target_city_id),
        'summary',           'Trade shipment in transit'
      ) AS detail
    FROM public.unit_movements um
    WHERE um.movement_type = 'trade'
      AND (p_event_type IS NULL OR p_event_type = 'trade')
  ),
  spy_events AS (
    SELECT sr.created_at AS event_time, 'espionage' AS event_type,
      jsonb_build_object(
        'report_id',   sr.id,
        'spy',         (SELECT display_name FROM public.profiles WHERE id = sr.player_id),
        'target_city', (SELECT name FROM public.cities WHERE id = sr.target_city_id),
        'summary',     'Spy report filed'
      ) AS detail
    FROM public.spy_reports sr
    WHERE (p_event_type IS NULL OR p_event_type = 'espionage')
  ),
  all_events AS (
    SELECT * FROM battle_events
    UNION ALL SELECT * FROM trade_events
    UNION ALL SELECT * FROM spy_events
    ORDER BY event_time DESC
    LIMIT p_limit
  )
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'event_type', event_type,
    'timestamp',  event_time,
    'detail',     detail
  )), '[]'::jsonb)
  INTO v_result
  FROM all_events;

  RETURN v_result;
END;
$$;

-- ============================================================
-- Grant execute to authenticated role for all five functions
-- ============================================================

GRANT EXECUTE ON FUNCTION public.godmode_get_world_state() TO authenticated;
GRANT EXECUTE ON FUNCTION public.godmode_set_bot_paused(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.godmode_force_action(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_resources(UUID, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.godmode_get_events(INTEGER, TEXT) TO authenticated;
