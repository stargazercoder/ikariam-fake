-- Migration: military pg_cron job registration
-- Registers training-tick and arrivals-tick alongside existing resource-tick and construction-tick.
-- NOTE: pg_cron extension already enabled in migration 20260311000010 — do NOT create again.

-- Training tick: every minute — completes any queued unit training
-- Calls complete_training() which checks finish_at <= NOW() and upserts into city_units
SELECT cron.schedule(
  'training-tick',
  '* * * * *',
  'SELECT public.complete_training()'
);

-- Arrivals tick: every minute — delivers in-transit armies to destination cities
-- Calls process_arrivals() which checks arrive_at <= NOW() and upserts into city_units
SELECT cron.schedule(
  'arrivals-tick',
  '* * * * *',
  'SELECT public.process_arrivals()'
);
