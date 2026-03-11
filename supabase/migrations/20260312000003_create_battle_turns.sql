-- Migration: create battle_turns table with RLS and Realtime
-- Records the per-turn results of each battle phase (naval + land).
-- Deleted automatically when parent battle is deleted (ON DELETE CASCADE).
-- All writes are server-side only (SECURITY DEFINER functions).

CREATE TABLE public.battle_turns (
  id                         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  battle_id                  uuid        NOT NULL REFERENCES public.battles(id) ON DELETE CASCADE,
  turn_number                integer     NOT NULL,

  -- Naval phase results (nullable when naval phase is skipped)
  naval_attacker_casualties  jsonb,
  naval_defender_casualties  jsonb,
  naval_outcome              text        CHECK (naval_outcome IN (
                               'attacker_won', 'defender_won', 'ongoing', 'skipped'
                             )),

  -- Land phase results (nullable when naval gate-keeper blocks land phase)
  land_attacker_casualties   jsonb,
  land_defender_casualties   jsonb,
  land_outcome               text        CHECK (land_outcome IN (
                               'attacker_won', 'defender_won', 'ongoing', 'blocked'
                             )),

  -- Survivor snapshots at end of this turn
  attacker_survivors         jsonb       NOT NULL,
  defender_survivors         jsonb       NOT NULL,

  resolved_at                timestamptz NOT NULL DEFAULT NOW(),

  UNIQUE (battle_id, turn_number)
);

ALTER TABLE public.battle_turns ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.battle_turns REPLICA IDENTITY FULL;

-- Participants can read their battle's turns
CREATE POLICY "battle_turns_select_participant"
  ON public.battle_turns FOR SELECT
  TO authenticated
  USING (
    battle_id IN (
      SELECT id FROM public.battles
      WHERE attacker_id = auth.uid() OR defender_id = auth.uid()
    )
  );

-- No INSERT/UPDATE/DELETE policies — all mutations via SECURITY DEFINER functions

ALTER PUBLICATION supabase_realtime ADD TABLE public.battle_turns;
