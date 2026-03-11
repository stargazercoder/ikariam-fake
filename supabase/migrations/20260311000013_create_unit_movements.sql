-- Migration: create unit_movements table with RLS and Realtime
-- Records in-transit armies as a JSONB snapshot (e.g. {"hoplite": 10, "archer": 5}).
-- Introduces the first cross-city operation in the game.
-- All writes are server-side only (SECURITY DEFINER functions).

CREATE TABLE public.unit_movements (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  origin_city_id      uuid        NOT NULL REFERENCES public.cities(id),
  destination_city_id uuid        NOT NULL REFERENCES public.cities(id),
  owner_id            uuid        NOT NULL REFERENCES auth.users(id),
  -- JSONB snapshot of units at departure time: {"hoplite": 10, "archer": 5}
  -- Immutable after creation; avoids join complexity in Phase 5 combat resolution
  units               jsonb       NOT NULL,
  depart_at           timestamptz NOT NULL DEFAULT NOW(),
  arrive_at           timestamptz NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT NOW(),
  CHECK (origin_city_id <> destination_city_id)  -- prevent self-dispatch
);

ALTER TABLE public.unit_movements ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.unit_movements REPLICA IDENTITY FULL;

-- Owner can see their own movements; defenders can see incoming armies (needed for Phase 5 combat)
CREATE POLICY "unit_movements_select_relevant"
  ON public.unit_movements FOR SELECT
  TO authenticated
  USING (
    owner_id = auth.uid()
    OR destination_city_id IN (SELECT id FROM public.cities WHERE owner_id = auth.uid())
  );

-- No INSERT/UPDATE/DELETE policies — all mutations via SECURITY DEFINER functions

ALTER PUBLICATION supabase_realtime ADD TABLE public.unit_movements;
