-- Migration: admin_set_army SECURITY DEFINER RPC
-- Sets army unit quantities for any player's city, per-unit-type.
-- Only non-NULL parameters are applied — pass NULL to leave a unit type unchanged.
-- Follows the exact admin_set_resources pattern (migration 20260317000005_godmode_rpcs.sql).
--
-- Architecture decision (STATE.md):
--   GodMode uses SECURITY DEFINER RPCs with is_admin Postgres check.
--   service_role key must never appear in any Flutter file.

-- ============================================================
-- RPC: admin_set_army
-- Sets city_units rows for any player via admin override.
-- Only unit types with non-NULL parameters are touched.
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_set_army(
  p_player_id   uuid,
  p_hoplite     integer DEFAULT NULL,
  p_phalanx     integer DEFAULT NULL,
  p_archer      integer DEFAULT NULL,
  p_cavalry     integer DEFAULT NULL,
  p_catapult    integer DEFAULT NULL,
  p_mortar      integer DEFAULT NULL,
  p_medic       integer DEFAULT NULL,
  p_cook        integer DEFAULT NULL,
  p_cargo_ship  integer DEFAULT NULL,
  p_ram_ship    integer DEFAULT NULL,
  p_catapult_ship integer DEFAULT NULL,
  p_mortar_ship   integer DEFAULT NULL,
  p_diving_boat   integer DEFAULT NULL
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

  -- Upsert each non-NULL unit type; quantity clamped to 0 minimum
  IF p_hoplite IS NOT NULL THEN
    INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
      VALUES (v_city_id, 'hoplite', GREATEST(p_hoplite, 0), NOW())
      ON CONFLICT (city_id, unit_type) DO UPDATE
        SET quantity = GREATEST(EXCLUDED.quantity, 0), updated_at = NOW();
  END IF;

  IF p_phalanx IS NOT NULL THEN
    INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
      VALUES (v_city_id, 'phalanx', GREATEST(p_phalanx, 0), NOW())
      ON CONFLICT (city_id, unit_type) DO UPDATE
        SET quantity = GREATEST(EXCLUDED.quantity, 0), updated_at = NOW();
  END IF;

  IF p_archer IS NOT NULL THEN
    INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
      VALUES (v_city_id, 'archer', GREATEST(p_archer, 0), NOW())
      ON CONFLICT (city_id, unit_type) DO UPDATE
        SET quantity = GREATEST(EXCLUDED.quantity, 0), updated_at = NOW();
  END IF;

  IF p_cavalry IS NOT NULL THEN
    INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
      VALUES (v_city_id, 'cavalry', GREATEST(p_cavalry, 0), NOW())
      ON CONFLICT (city_id, unit_type) DO UPDATE
        SET quantity = GREATEST(EXCLUDED.quantity, 0), updated_at = NOW();
  END IF;

  IF p_catapult IS NOT NULL THEN
    INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
      VALUES (v_city_id, 'catapult', GREATEST(p_catapult, 0), NOW())
      ON CONFLICT (city_id, unit_type) DO UPDATE
        SET quantity = GREATEST(EXCLUDED.quantity, 0), updated_at = NOW();
  END IF;

  IF p_mortar IS NOT NULL THEN
    INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
      VALUES (v_city_id, 'mortar', GREATEST(p_mortar, 0), NOW())
      ON CONFLICT (city_id, unit_type) DO UPDATE
        SET quantity = GREATEST(EXCLUDED.quantity, 0), updated_at = NOW();
  END IF;

  IF p_medic IS NOT NULL THEN
    INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
      VALUES (v_city_id, 'medic', GREATEST(p_medic, 0), NOW())
      ON CONFLICT (city_id, unit_type) DO UPDATE
        SET quantity = GREATEST(EXCLUDED.quantity, 0), updated_at = NOW();
  END IF;

  IF p_cook IS NOT NULL THEN
    INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
      VALUES (v_city_id, 'cook', GREATEST(p_cook, 0), NOW())
      ON CONFLICT (city_id, unit_type) DO UPDATE
        SET quantity = GREATEST(EXCLUDED.quantity, 0), updated_at = NOW();
  END IF;

  IF p_cargo_ship IS NOT NULL THEN
    INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
      VALUES (v_city_id, 'cargo_ship', GREATEST(p_cargo_ship, 0), NOW())
      ON CONFLICT (city_id, unit_type) DO UPDATE
        SET quantity = GREATEST(EXCLUDED.quantity, 0), updated_at = NOW();
  END IF;

  IF p_ram_ship IS NOT NULL THEN
    INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
      VALUES (v_city_id, 'ram_ship', GREATEST(p_ram_ship, 0), NOW())
      ON CONFLICT (city_id, unit_type) DO UPDATE
        SET quantity = GREATEST(EXCLUDED.quantity, 0), updated_at = NOW();
  END IF;

  IF p_catapult_ship IS NOT NULL THEN
    INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
      VALUES (v_city_id, 'catapult_ship', GREATEST(p_catapult_ship, 0), NOW())
      ON CONFLICT (city_id, unit_type) DO UPDATE
        SET quantity = GREATEST(EXCLUDED.quantity, 0), updated_at = NOW();
  END IF;

  IF p_mortar_ship IS NOT NULL THEN
    INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
      VALUES (v_city_id, 'mortar_ship', GREATEST(p_mortar_ship, 0), NOW())
      ON CONFLICT (city_id, unit_type) DO UPDATE
        SET quantity = GREATEST(EXCLUDED.quantity, 0), updated_at = NOW();
  END IF;

  IF p_diving_boat IS NOT NULL THEN
    INSERT INTO public.city_units (city_id, unit_type, quantity, updated_at)
      VALUES (v_city_id, 'diving_boat', GREATEST(p_diving_boat, 0), NOW())
      ON CONFLICT (city_id, unit_type) DO UPDATE
        SET quantity = GREATEST(EXCLUDED.quantity, 0), updated_at = NOW();
  END IF;
END;
$$;

-- Grant execute to authenticated role (admin guard is enforced inside the function)
GRANT EXECUTE ON FUNCTION public.admin_set_army(UUID, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER) TO authenticated;
