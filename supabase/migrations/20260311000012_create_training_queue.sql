-- Migration: create training_queue table with RLS and Realtime
-- One active training entry per city enforced at DB level via UNIQUE(city_id).
-- Mirrors construction_queue pattern exactly (migration 20260311000006).
-- All writes are server-side only (SECURITY DEFINER functions / triggers).

CREATE TABLE public.training_queue (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id     uuid        NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  unit_type   text        NOT NULL,
  quantity    integer     NOT NULL CHECK (quantity > 0),
  finish_at   timestamptz NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (city_id),  -- enforces one-at-a-time training per city at DB level (v1 simplicity)
  CHECK (unit_type IN (
    'hoplite', 'phalanx', 'archer', 'cavalry', 'catapult', 'mortar', 'medic', 'cook',
    'cargo_ship', 'ram_ship', 'catapult_ship', 'mortar_ship', 'diving_boat'
  ))
);

ALTER TABLE public.training_queue ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.training_queue REPLICA IDENTITY FULL;

-- Owner can read their city's training queue only
CREATE POLICY "training_queue_select_owner"
  ON public.training_queue FOR SELECT
  TO authenticated
  USING (city_id IN (SELECT id FROM public.cities WHERE owner_id = auth.uid()));

-- No INSERT/UPDATE/DELETE policies — all mutations via SECURITY DEFINER functions

ALTER PUBLICATION supabase_realtime ADD TABLE public.training_queue;
