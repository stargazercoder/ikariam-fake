-- Migration: create city_resources table with RLS and Realtime
-- Stores per-resource amounts for each city.
-- All writes are server-side only (SECURITY DEFINER functions / triggers).
-- REPLICA IDENTITY FULL required for Supabase Realtime to send full row on UPDATE.

CREATE TABLE public.city_resources (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id       uuid NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  resource_type text NOT NULL CHECK (resource_type IN ('wood','marble','crystal','sulfur','gold')),
  amount        numeric NOT NULL DEFAULT 0 CHECK (amount >= 0),
  updated_at    timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (city_id, resource_type)
);

ALTER TABLE public.city_resources ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.city_resources REPLICA IDENTITY FULL;

-- Owner can read their city's resources only
CREATE POLICY "city_resources_select_owner"
  ON public.city_resources FOR SELECT
  TO authenticated
  USING (city_id IN (SELECT id FROM public.cities WHERE owner_id = auth.uid()));

-- No INSERT/UPDATE/DELETE policies — all mutations via SECURITY DEFINER functions

ALTER PUBLICATION supabase_realtime ADD TABLE public.city_resources;
