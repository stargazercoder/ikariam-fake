-- Migration: create city_units table with RLS and Realtime
-- Army roster table: one row per unit type per city.
-- UNIQUE(city_id, unit_type) allows simple upsert when training completes.
-- No INSERT/UPDATE/DELETE policies — all mutations via SECURITY DEFINER functions.

CREATE TABLE public.city_units (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id     uuid        NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  unit_type   text        NOT NULL,
  quantity    integer     NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  updated_at  timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (city_id, unit_type),  -- one row per unit type per city; enables upsert on training completion
  CHECK (unit_type IN (
    'hoplite', 'phalanx', 'archer', 'cavalry', 'catapult', 'mortar', 'medic', 'cook',
    'cargo_ship', 'ram_ship', 'catapult_ship', 'mortar_ship', 'diving_boat'
  ))
);

ALTER TABLE public.city_units ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.city_units REPLICA IDENTITY FULL;

-- Owner reads own army roster only; army composition is private from other players
CREATE POLICY "city_units_select_owner"
  ON public.city_units FOR SELECT
  TO authenticated
  USING (city_id IN (SELECT id FROM public.cities WHERE owner_id = auth.uid()));

-- No INSERT/UPDATE/DELETE policies — all mutations via SECURITY DEFINER functions

ALTER PUBLICATION supabase_realtime ADD TABLE public.city_units;
