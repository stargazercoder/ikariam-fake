-- Migration: pg_cron job registration
-- CRITICAL: pg_cron extension MUST be created via migration (not dashboard / seed.sql)
-- to avoid "schema cron does not exist" errors during supabase db reset.
-- See: Phase 2 research Pitfall 1.

-- Enable pg_cron extension (idempotent)
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;

-- Grant cron schema access to the postgres superuser role
GRANT USAGE ON SCHEMA cron TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cron TO postgres;

-- Resource tick: every 5 minutes — advances all city resource amounts
-- Calls process_resource_tick() which respects warehouse capacity caps
SELECT cron.schedule(
  'resource-tick',
  '*/5 * * * *',
  'SELECT public.process_resource_tick()'
);

-- Construction tick: every minute — completes any queued building upgrades
-- Calls complete_building_upgrades() which checks finish_at <= NOW()
SELECT cron.schedule(
  'construction-tick',
  '* * * * *',
  'SELECT public.complete_building_upgrades()'
);
