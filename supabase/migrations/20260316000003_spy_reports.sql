-- Spy reports table — stores espionage results for each player
CREATE TABLE public.spy_reports (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_city_id uuid NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  report_data    jsonb NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);

-- Index for spy log queries (player's own reports, most recent first)
CREATE INDEX spy_reports_player_id_created_at_idx
  ON public.spy_reports (player_id, created_at DESC);

-- RLS: players can only read their own reports
ALTER TABLE public.spy_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "players read own spy reports"
  ON public.spy_reports FOR SELECT
  USING (player_id = auth.uid());
-- Edge Function inserts with service_role (bypasses RLS)
