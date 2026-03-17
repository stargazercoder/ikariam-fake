-- Migration: bot decisions orchestrator and pg_cron job registration
-- run_bot_decisions(): iterates all eligible bots and dispatches the highest-priority action.
--
-- Priority chain (first action that succeeds wins; lower priorities are skipped):
--   1. bot_decide_upgrade(city_id) — queue a building upgrade or island donation
--   2. bot_decide_train(city_id)   — queue unit training
--   3. bot_decide_attack(city_id, aggression) — dispatch an attack (aggression-gated)
--
-- Architecture decision (STATE.md):
--   Single consolidated bot-think-tick at */15 * * * * — not per-behavior cron jobs.
--   Avoids pg_cron worker pool exhaustion (max 32 workers).
--   Bot actions write directly to training_queue / construction_queue / unit_movements —
--   same tables as Edge Functions; no pg_net HTTP round-trips from pg_cron.
--
-- Scheduling:
--   next_action_at staggered by 15 min base + 0-5 min random jitter after each bot action.
--   Prevents thundering herd when multiple bots share the same next_action_at.
--
-- Security model: SECURITY DEFINER SET search_path = '' (same pattern as all cron functions)
-- All table references are fully qualified with public. prefix.

-- ============================================================
-- run_bot_decisions
-- ============================================================

CREATE OR REPLACE FUNCTION public.run_bot_decisions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  bot RECORD;
BEGIN
  FOR bot IN
    SELECT p.id AS bot_id, c.id AS city_id, bs.aggression
    FROM public.profiles p
    JOIN public.cities c ON c.owner_id = p.id
    JOIN public.bot_schedules bs ON bs.bot_id = p.id
    WHERE p.is_bot = true
      AND bs.is_paused = false
      AND bs.next_action_at <= NOW()
  LOOP
    -- Priority chain: upgrade -> train -> attack (aggression-gated)
    -- One action per tick per bot. If higher priority succeeds, skip lower.
    IF NOT public.bot_decide_upgrade(bot.city_id) THEN
      IF NOT public.bot_decide_train(bot.city_id) THEN
        IF bot.aggression > 0 THEN
          PERFORM public.bot_decide_attack(bot.city_id, bot.aggression);
        END IF;
      END IF;
    END IF;

    -- Stagger next action: 15 min base + 0-5 min random jitter
    -- Prevents thundering herd when multiple bots have same next_action_at
    UPDATE public.bot_schedules
      SET next_action_at = NOW() + INTERVAL '15 minutes'
                           + (random() * INTERVAL '5 minutes')
      WHERE bot_id = bot.bot_id;
  END LOOP;
END;
$$;

-- ============================================================
-- pg_cron job registration: bot-think-tick
-- ============================================================
-- NOTE: pg_cron extension already enabled in migration 20260311000010 — do NOT create again.
--
-- Bot think tick: every 15 minutes — runs one decision per eligible bot.
-- Single consolidated job avoids pg_cron worker pool exhaustion (max 32 workers).
-- See: STATE.md architecture decision (v1.3 decisions section).
SELECT cron.schedule(
  'bot-think-tick',
  '*/15 * * * *',
  'SELECT public.run_bot_decisions()'
);
