-- Migration: create construction_queue table with RLS and Realtime
-- One active construction entry per city enforced at DB level via UNIQUE(city_id).
-- All writes are server-side only (SECURITY DEFINER functions / triggers).

CREATE TABLE public.construction_queue (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id      uuid NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  building_type text NOT NULL,
  target_level integer NOT NULL,
  finish_at    timestamptz NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (city_id)  -- enforces one-at-a-time construction per city at DB level
);

ALTER TABLE public.construction_queue ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.construction_queue REPLICA IDENTITY FULL;

-- Owner can read their city's construction queue only
CREATE POLICY "construction_queue_select_owner"
  ON public.construction_queue FOR SELECT
  TO authenticated
  USING (city_id IN (SELECT id FROM public.cities WHERE owner_id = auth.uid()));

-- No INSERT/UPDATE/DELETE policies — all mutations via SECURITY DEFINER functions

ALTER PUBLICATION supabase_realtime ADD TABLE public.construction_queue;
