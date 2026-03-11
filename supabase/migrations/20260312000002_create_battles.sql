-- Migration: create battles table with RLS and Realtime
-- Stores active and completed battle state.
-- One active battle per defender city enforced via partial unique index.
-- All writes are server-side only (SECURITY DEFINER functions).

CREATE TABLE public.battles (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  defender_city_id   uuid        NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  attacker_city_id   uuid        NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  attacker_id        uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  defender_id        uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  attacker_units     jsonb       NOT NULL,
  defender_units     jsonb       NOT NULL,
  status             text        NOT NULL DEFAULT 'active'
                     CHECK (status IN ('active', 'attacker_won', 'defender_won')),
  turn_number        integer     NOT NULL DEFAULT 0,
  next_turn_at       timestamptz NOT NULL,
  created_at         timestamptz NOT NULL DEFAULT NOW(),
  updated_at         timestamptz NOT NULL DEFAULT NOW()
);

-- Only one active battle per defender city at a time.
-- Completed battles (status != 'active') may remain as history.
CREATE UNIQUE INDEX battles_one_active_per_city
  ON public.battles (defender_city_id)
  WHERE status = 'active';

ALTER TABLE public.battles ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.battles REPLICA IDENTITY FULL;

-- Both attacker and defender can read their own battles
CREATE POLICY "battles_select_participant"
  ON public.battles FOR SELECT
  TO authenticated
  USING (attacker_id = auth.uid() OR defender_id = auth.uid());

-- No INSERT/UPDATE/DELETE policies — all mutations via SECURITY DEFINER functions

ALTER PUBLICATION supabase_realtime ADD TABLE public.battles;
