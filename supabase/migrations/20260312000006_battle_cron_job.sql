-- Migration: register battle-tick pg_cron job
-- Fires every minute. resolve_battles() skips turns whose next_turn_at > NOW(),
-- so running every minute with 5-minute turns is safe and idempotent.

SELECT cron.schedule(
  'battle-tick',
  '* * * * *',
  'SELECT public.resolve_battles()'
);
