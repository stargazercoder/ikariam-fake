-- Migration: extend movement_type CHECK constraint to include 'trade'
-- and add deduct_resources RPC for atomic resource deduction.
--
-- Part of Phase 15 Resource Trading (TRAD-01).
-- Mirrors the deduct_units RPC pattern from 20260315000001_pillage_schema_and_functions.sql.

-- ============================================================
-- 1. Extend movement_type CHECK constraint to include 'trade'
-- ============================================================

-- Drop the existing constraint (defined in 20260312000001_add_movement_type_to_unit_movements.sql)
ALTER TABLE public.unit_movements
  DROP CONSTRAINT IF EXISTS unit_movements_movement_type_check;

-- Re-add with 'trade' included alongside 'attack' and 'return'
ALTER TABLE public.unit_movements
  ADD CONSTRAINT unit_movements_movement_type_check
  CHECK (movement_type IN ('attack', 'return', 'trade'));

-- ============================================================
-- 2. Create deduct_resources RPC
-- Atomically deducts a resource amount from a city.
-- Raises EXCEPTION if the city does not have enough of that resource.
-- Mirrors deduct_units from pillage migration.
-- ============================================================

CREATE OR REPLACE FUNCTION public.deduct_resources(
  p_city_id      uuid,
  p_resource_type text,
  p_amount       numeric
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  UPDATE public.city_resources
  SET amount     = amount - p_amount,
      updated_at = NOW()
  WHERE city_id       = p_city_id
    AND resource_type = p_resource_type
    AND amount        >= p_amount;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Insufficient %', p_resource_type;
  END IF;
END;
$$;
