-- Migration: create cities table with RLS
-- Cities are placed by the handle_new_user trigger. Client cannot mutate this table.

CREATE TABLE public.cities (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id        uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  island_id       uuid NOT NULL REFERENCES public.islands(id),
  slot_number     integer NOT NULL CHECK (slot_number BETWEEN 1 AND 17),
  name            text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (island_id, slot_number)
);

ALTER TABLE public.cities ENABLE ROW LEVEL SECURITY;

-- All authenticated players can read any city (needed for map display)
CREATE POLICY "cities_select_authenticated"
  ON public.cities FOR SELECT
  TO authenticated
  USING (true);

-- No INSERT/UPDATE/DELETE policies — Flutter client cannot mutate cities
-- The handle_new_user trigger (SECURITY DEFINER) places the initial city
