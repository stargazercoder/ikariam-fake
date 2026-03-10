-- Migration: create islands table with RLS
-- Islands represent the map grid. Only server-side functions can mutate this table.

CREATE TABLE public.islands (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  grid_x          integer NOT NULL,
  grid_y          integer NOT NULL,
  max_city_slots  integer NOT NULL DEFAULT 16,
  wood_level      integer NOT NULL DEFAULT 1,
  luxury_type     text NOT NULL CHECK (luxury_type IN ('marble', 'crystal', 'sulfur')),
  luxury_level    integer NOT NULL DEFAULT 1,
  created_at      timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (grid_x, grid_y)
);

ALTER TABLE public.islands ENABLE ROW LEVEL SECURITY;

-- Players can read all islands (needed for map display)
CREATE POLICY "islands_select_authenticated"
  ON public.islands FOR SELECT
  TO authenticated
  USING (true);

-- No INSERT/UPDATE/DELETE policies — Flutter client cannot mutate islands
-- Server functions use SECURITY DEFINER (bypasses RLS) to write
