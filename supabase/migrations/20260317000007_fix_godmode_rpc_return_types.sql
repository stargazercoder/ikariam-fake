-- Migration: Fix GodMode RPC return types for PostgREST compatibility
-- PostgREST has issues with RETURNS jsonb — "Database error querying schema".
-- Changing world_state to RETURNS SETOF json (one row per player) and
-- events to RETURNS SETOF json (one row per event) so PostgREST can
-- introspect the return type. Mutation RPCs (void/text) are unaffected.

-- ============================================================
-- Fix RPC 1: godmode_get_world_state → SETOF json (one row per player)
-- ============================================================

-- Must drop first — cannot change return type with CREATE OR REPLACE
DROP FUNCTION IF EXISTS public.godmode_get_world_state();

CREATE OR REPLACE FUNCTION public.godmode_get_world_state()
RETURNS SETOF json
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

  RETURN QUERY
  SELECT row_to_json(t)::json FROM (
    SELECT
      p.id,
      p.display_name,
      p.is_bot,
      COALESCE(bs.is_paused, false) AS is_paused,
      COALESCE(
        (SELECT jsonb_object_agg(cr.resource_type, cr.amount)
         FROM public.city_resources cr
         WHERE cr.city_id = c.id),
        '{}'::jsonb
      ) AS resources,
      jsonb_build_object(
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
      ) AS army,
      COALESCE(
        (SELECT jsonb_object_agg(cb.building_type, cb.level)
         FROM public.city_buildings cb
         WHERE cb.city_id = c.id),
        '{}'::jsonb
      ) AS buildings,
      COALESCE(
        (SELECT jsonb_agg(jsonb_build_object(
          'battle_id',      b.id,
          'attacker_name',  (SELECT display_name FROM public.profiles WHERE id = b.attacker_id),
          'defender_name',  (SELECT display_name FROM public.profiles WHERE id = b.defender_id),
          'current_turn',   b.current_turn
        ))
        FROM public.battles b
        WHERE (b.attacker_id = p.id OR b.defender_id = p.id)
          AND b.status = 'active'),
        '[]'::jsonb
      ) AS active_battles
    FROM public.profiles p
    JOIN public.cities c ON c.owner_id = p.id
    LEFT JOIN public.bot_schedules bs ON bs.bot_id = p.id
  ) t;
END;
$$;

-- ============================================================
-- Fix RPC 5: godmode_get_events → SETOF json (one row per event)
-- ============================================================

-- Must drop first — cannot change return type with CREATE OR REPLACE
DROP FUNCTION IF EXISTS public.godmode_get_events(integer, text);

CREATE OR REPLACE FUNCTION public.godmode_get_events(
  p_limit      integer DEFAULT 50,
  p_event_type text    DEFAULT NULL
)
RETURNS SETOF json
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

  RETURN QUERY
  SELECT row_to_json(t)::json FROM (
    WITH battle_events AS (
      SELECT b.created_at AS event_time, 'battle'::text AS event_type,
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
      SELECT um.created_at AS event_time, 'trade'::text AS event_type,
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
      SELECT sr.created_at AS event_time, 'espionage'::text AS event_type,
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
    SELECT
      ae.event_type,
      ae.event_time AS timestamp,
      ae.detail
    FROM all_events ae
  ) t;
END;
$$;

-- Re-grant execute (signature changed for world_state and events)
GRANT EXECUTE ON FUNCTION public.godmode_get_world_state() TO authenticated;
GRANT EXECUTE ON FUNCTION public.godmode_get_events(INTEGER, TEXT) TO authenticated;
