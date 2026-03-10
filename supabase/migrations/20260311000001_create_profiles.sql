-- Migration: create profiles table with RLS
-- Profiles are created by the handle_new_user trigger (SECURITY DEFINER).
-- Players can update only their own profile. No client INSERT policy.

CREATE TABLE public.profiles (
  id              uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name    text UNIQUE CHECK (
                    display_name IS NULL OR (
                      char_length(display_name) BETWEEN 3 AND 20
                      AND display_name ~ '^[a-zA-Z0-9_]+$'
                    )
                  ),
  avatar_id       integer NOT NULL DEFAULT 1
                    CHECK (avatar_id BETWEEN 1 AND 20),
  created_at      timestamptz NOT NULL DEFAULT NOW(),
  updated_at      timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- All authenticated players can read any profile (needed for leaderboard/social)
CREATE POLICY "profiles_select_all"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (true);

-- Players can only update their own profile
CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- No INSERT policy — profile is created by handle_new_user trigger (SECURITY DEFINER)
-- Note: display_name allows NULL because trigger creates a stub with NULL display_name.
--       User fills it in on the profile creation screen.
