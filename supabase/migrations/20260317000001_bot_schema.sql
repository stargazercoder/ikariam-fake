-- Migration: bot schema foundation
-- Adds is_bot and is_admin columns to profiles, creates bot_schedules table with
-- deny-all RLS, and revokes client UPDATE on the new sentinel columns.
--
-- Required by:
--   Phase 19 (bot behavior engine)  — reads bot_schedules for tick scheduling
--   Phase 20 (seed data)            — inserts bot profiles with is_bot = true
--   Phase 21-22 (GodMode)           — reads is_admin to gate GodMode RPCs
--
-- Security model:
--   is_bot / is_admin    : NOT NULL DEFAULT false; clients CANNOT update via RLS
--   bot_schedules        : RLS enabled, zero client policies → deny-all for clients
--                          Only SECURITY DEFINER functions (pg_cron tick, GodMode
--                          RPCs) can read/write bot_schedules.

-- Step 1: Add sentinel boolean columns to profiles
-- NOT NULL DEFAULT false means PostgreSQL backfills all existing rows automatically.
-- No UPDATE migration needed.
ALTER TABLE public.profiles
  ADD COLUMN is_bot   boolean NOT NULL DEFAULT false,
  ADD COLUMN is_admin boolean NOT NULL DEFAULT false;

-- Step 2: Revoke client UPDATE on the sentinel columns (defense-in-depth)
-- Even though profiles_update_own RLS policy permits row-level access, column-level
-- REVOKE prevents any authenticated client from flipping these flags via the
-- Supabase JS/Dart client.  Only SECURITY DEFINER functions can change these values.
REVOKE UPDATE (is_bot, is_admin) ON public.profiles FROM authenticated;

-- Step 3: Create bot_schedules table
-- One row per bot (bot_id is both PK and FK to profiles).
-- ON DELETE CASCADE cleans up when a bot profile is deleted.
-- aggression CHECK enforces 0-3 range (0=passive … 3=aggressive).
-- next_action_at defaults to NOW() so newly inserted bots are immediately eligible
-- for the first pg_cron tick.
CREATE TABLE public.bot_schedules (
  bot_id         uuid        PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  is_paused      boolean     NOT NULL DEFAULT false,
  aggression     integer     NOT NULL DEFAULT 1 CHECK (aggression BETWEEN 0 AND 3),
  next_action_at timestamptz NOT NULL DEFAULT NOW()
);

-- Step 4: Enable RLS with no policies (deny-all for authenticated clients)
-- With RLS on and zero matching policies, authenticated clients receive zero rows
-- on SELECT and zero-row updates on INSERT/UPDATE/DELETE.
-- SECURITY DEFINER functions bypass RLS and are the only writers of this table.
ALTER TABLE public.bot_schedules ENABLE ROW LEVEL SECURITY;
