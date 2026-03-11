-- Migration: create city_buildings table with RLS and Realtime
-- Stores building levels and assigned workers for each city.
-- 14 building types: 10 city buildings + 4 production buildings.
-- Production buildings (sawmill, quarry, glassblower, sulfur_pit) are required so
-- that process_resource_tick() can find a matching production building for all 5
-- resource types. Without them, only gold would produce via town_hall.
-- All writes are server-side only (SECURITY DEFINER functions / triggers).

CREATE TABLE public.city_buildings (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id          uuid NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  building_type    text NOT NULL CHECK (building_type IN (
                     -- City buildings (10)
                     'town_hall',
                     'warehouse',
                     'barracks',
                     'shipyard',
                     'academy',
                     'embassy',
                     'trading_port',
                     'town_wall',
                     'hideout',
                     'tavern',
                     -- Production buildings (4)
                     'sawmill',
                     'quarry',
                     'glassblower',
                     'sulfur_pit'
                   )),
  level            integer NOT NULL DEFAULT 0 CHECK (level >= 0),
  assigned_workers integer NOT NULL DEFAULT 0 CHECK (assigned_workers >= 0),
  updated_at       timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (city_id, building_type)
);

ALTER TABLE public.city_buildings ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.city_buildings REPLICA IDENTITY FULL;

-- Owner can read their city's buildings only
CREATE POLICY "city_buildings_select_owner"
  ON public.city_buildings FOR SELECT
  TO authenticated
  USING (city_id IN (SELECT id FROM public.cities WHERE owner_id = auth.uid()));

-- No INSERT/UPDATE/DELETE policies — all mutations via SECURITY DEFINER functions

ALTER PUBLICATION supabase_realtime ADD TABLE public.city_buildings;
