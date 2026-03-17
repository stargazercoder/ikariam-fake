-- Seed: 25 islands in a 5x5 grid
-- Luxury types distributed cyclically: marble, crystal, sulfur (~8-9 each)
-- max_city_slots: 16 for most, 17 for every 5th island (idx % 5 == 0)

DO $$
DECLARE
  x             int;
  y             int;
  luxury_types  text[] := ARRAY['marble', 'crystal', 'sulfur'];
  idx           int := 0;
BEGIN
  FOR x IN 0..4 LOOP
    FOR y IN 0..4 LOOP
      INSERT INTO public.islands (grid_x, grid_y, luxury_type, max_city_slots)
      VALUES (
        x,
        y,
        luxury_types[1 + (idx % 3)],
        16 + (CASE WHEN (idx % 5) = 0 THEN 1 ELSE 0 END)
      );
      idx := idx + 1;
    END LOOP;
  END LOOP;
END;
$$;

-- ============================================================
-- Seed: 7 test accounts for local dev (all passwords: "test1234")
-- Inserting into auth.users fires handle_new_user trigger which
-- auto-creates profile + city for each user.
-- ============================================================

-- === Account 1-3: Leonidas, Xerxes, Pericles (existing) ===

INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  confirmation_token, raw_app_meta_data, raw_user_meta_data
) VALUES
  (
    '00000000-0000-0000-0000-000000000000',
    'a1111111-1111-1111-1111-111111111111',
    'authenticated', 'authenticated',
    'dummy1@test.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'a2222222-2222-2222-2222-222222222222',
    'authenticated', 'authenticated',
    'dummy2@test.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'a3333333-3333-3333-3333-333333333333',
    'authenticated', 'authenticated',
    'dummy3@test.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  );

-- === Account 4: Themistocles — MILITARY-READY ===
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  confirmation_token, raw_app_meta_data, raw_user_meta_data
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'a4444444-4444-4444-4444-444444444444',
  'authenticated', 'authenticated',
  'military@test.local',
  crypt('test1234', gen_salt('bf')),
  NOW(), NOW(), NOW(), '',
  '{"provider":"email","providers":["email"]}',
  '{}'
);

-- === Account 5: Alcibiades — ACTIVE ATTACKER ===
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  confirmation_token, raw_app_meta_data, raw_user_meta_data
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'a5555555-5555-5555-5555-555555555555',
  'authenticated', 'authenticated',
  'attacker@test.local',
  crypt('test1234', gen_salt('bf')),
  NOW(), NOW(), NOW(), '',
  '{"provider":"email","providers":["email"]}',
  '{}'
);

-- === Account 6: Darius — ACTIVE DEFENDER ===
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  confirmation_token, raw_app_meta_data, raw_user_meta_data
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'a6666666-6666-6666-6666-666666666666',
  'authenticated', 'authenticated',
  'defender@test.local',
  crypt('test1234', gen_salt('bf')),
  NOW(), NOW(), NOW(), '',
  '{"provider":"email","providers":["email"]}',
  '{}'
);

-- === Account 7: Cleopatra — CONSTRUCTION ACTIVE ===
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  confirmation_token, raw_app_meta_data, raw_user_meta_data
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'a7777777-7777-7777-7777-777777777777',
  'authenticated', 'authenticated',
  'builder@test.local',
  crypt('test1234', gen_salt('bf')),
  NOW(), NOW(), NOW(), '',
  '{"provider":"email","providers":["email"]}',
  '{}'
);

-- ============================================================
-- Set display names for all 7 profiles
-- ============================================================

UPDATE public.profiles SET display_name = 'Leonidas'    WHERE id = 'a1111111-1111-1111-1111-111111111111';
UPDATE public.profiles SET display_name = 'Xerxes'      WHERE id = 'a2222222-2222-2222-2222-222222222222';
UPDATE public.profiles SET display_name = 'Pericles'    WHERE id = 'a3333333-3333-3333-3333-333333333333';
UPDATE public.profiles SET display_name = 'Themistocles' WHERE id = 'a4444444-4444-4444-4444-444444444444';
UPDATE public.profiles SET display_name = 'Alcibiades'  WHERE id = 'a5555555-5555-5555-5555-555555555555';
UPDATE public.profiles SET display_name = 'Darius'      WHERE id = 'a6666666-6666-6666-6666-666666666666';
UPDATE public.profiles SET display_name = 'Cleopatra'   WHERE id = 'a7777777-7777-7777-7777-777777777777';

-- ============================================================
-- Add auth.identities for all 7 accounts (required for email login)
-- ============================================================

INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
VALUES
  (
    'a1111111-1111-1111-1111-111111111111',
    'a1111111-1111-1111-1111-111111111111',
    jsonb_build_object('sub', 'a1111111-1111-1111-1111-111111111111', 'email', 'dummy1@test.local'),
    'email',
    'a1111111-1111-1111-1111-111111111111',
    NOW(), NOW(), NOW()
  ),
  (
    'a2222222-2222-2222-2222-222222222222',
    'a2222222-2222-2222-2222-222222222222',
    jsonb_build_object('sub', 'a2222222-2222-2222-2222-222222222222', 'email', 'dummy2@test.local'),
    'email',
    'a2222222-2222-2222-2222-222222222222',
    NOW(), NOW(), NOW()
  ),
  (
    'a3333333-3333-3333-3333-333333333333',
    'a3333333-3333-3333-3333-333333333333',
    jsonb_build_object('sub', 'a3333333-3333-3333-3333-333333333333', 'email', 'dummy3@test.local'),
    'email',
    'a3333333-3333-3333-3333-333333333333',
    NOW(), NOW(), NOW()
  ),
  (
    'a4444444-4444-4444-4444-444444444444',
    'a4444444-4444-4444-4444-444444444444',
    jsonb_build_object('sub', 'a4444444-4444-4444-4444-444444444444', 'email', 'military@test.local'),
    'email',
    'a4444444-4444-4444-4444-444444444444',
    NOW(), NOW(), NOW()
  ),
  (
    'a5555555-5555-5555-5555-555555555555',
    'a5555555-5555-5555-5555-555555555555',
    jsonb_build_object('sub', 'a5555555-5555-5555-5555-555555555555', 'email', 'attacker@test.local'),
    'email',
    'a5555555-5555-5555-5555-555555555555',
    NOW(), NOW(), NOW()
  ),
  (
    'a6666666-6666-6666-6666-666666666666',
    'a6666666-6666-6666-6666-666666666666',
    jsonb_build_object('sub', 'a6666666-6666-6666-6666-666666666666', 'email', 'defender@test.local'),
    'email',
    'a6666666-6666-6666-6666-666666666666',
    NOW(), NOW(), NOW()
  ),
  (
    'a7777777-7777-7777-7777-777777777777',
    'a7777777-7777-7777-7777-777777777777',
    jsonb_build_object('sub', 'a7777777-7777-7777-7777-777777777777', 'email', 'builder@test.local'),
    'email',
    'a7777777-7777-7777-7777-777777777777',
    NOW(), NOW(), NOW()
  );

-- ============================================================
-- === Account 2: Xerxes — MID-GAME BUILDER ===
-- town_hall=3, warehouse=2, sawmill=2
-- Resources: wood=2000, marble=1000, crystal=500, sulfur=500, gold=1500
-- ============================================================

UPDATE public.city_buildings
  SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a2222222-2222-2222-2222-222222222222')
    AND building_type = 'town_hall';

UPDATE public.city_buildings
  SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a2222222-2222-2222-2222-222222222222')
    AND building_type = 'warehouse';

UPDATE public.city_buildings
  SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a2222222-2222-2222-2222-222222222222')
    AND building_type = 'sawmill';

UPDATE public.city_resources
  SET amount = 2000
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a2222222-2222-2222-2222-222222222222')
    AND resource_type = 'wood';

UPDATE public.city_resources
  SET amount = 1000
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a2222222-2222-2222-2222-222222222222')
    AND resource_type = 'marble';

UPDATE public.city_resources
  SET amount = 500
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a2222222-2222-2222-2222-222222222222')
    AND resource_type = 'crystal';

UPDATE public.city_resources
  SET amount = 500
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a2222222-2222-2222-2222-222222222222')
    AND resource_type = 'sulfur';

UPDATE public.city_resources
  SET amount = 1500
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a2222222-2222-2222-2222-222222222222')
    AND resource_type = 'gold';

-- ============================================================
-- === Account 3: Pericles — MID-GAME ECONOMY ===
-- town_hall=2, warehouse=3, academy=2
-- Resources: wood=3000, marble=2000, crystal=1000, sulfur=800, gold=2000
-- ============================================================

UPDATE public.city_buildings
  SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a3333333-3333-3333-3333-333333333333')
    AND building_type = 'town_hall';

UPDATE public.city_buildings
  SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a3333333-3333-3333-3333-333333333333')
    AND building_type = 'warehouse';

UPDATE public.city_buildings
  SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a3333333-3333-3333-3333-333333333333')
    AND building_type = 'academy';

UPDATE public.city_resources
  SET amount = 3000
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a3333333-3333-3333-3333-333333333333')
    AND resource_type = 'wood';

UPDATE public.city_resources
  SET amount = 2000
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a3333333-3333-3333-3333-333333333333')
    AND resource_type = 'marble';

UPDATE public.city_resources
  SET amount = 1000
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a3333333-3333-3333-3333-333333333333')
    AND resource_type = 'crystal';

UPDATE public.city_resources
  SET amount = 800
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a3333333-3333-3333-3333-333333333333')
    AND resource_type = 'sulfur';

UPDATE public.city_resources
  SET amount = 2000
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a3333333-3333-3333-3333-333333333333')
    AND resource_type = 'gold';

-- ============================================================
-- === Account 4: Themistocles — MILITARY-READY ===
-- barracks=3; units: hoplite=50, archer=20, phalanx=10
-- ============================================================

UPDATE public.city_buildings
  SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a4444444-4444-4444-4444-444444444444')
    AND building_type = 'barracks';

INSERT INTO public.city_units (city_id, unit_type, quantity)
VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'a4444444-4444-4444-4444-444444444444'), 'hoplite', 50),
  ((SELECT id FROM public.cities WHERE owner_id = 'a4444444-4444-4444-4444-444444444444'), 'archer',  20),
  ((SELECT id FROM public.cities WHERE owner_id = 'a4444444-4444-4444-4444-444444444444'), 'phalanx', 10);

-- ============================================================
-- === Account 5: Alcibiades — ACTIVE ATTACKER ===
-- barracks=3, shipyard=2; units: hoplite=30, ram_ship=5
-- Dispatching 20 hoplites toward account 6, arriving in 10 minutes
-- ============================================================

UPDATE public.city_buildings
  SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a5555555-5555-5555-5555-555555555555')
    AND building_type = 'barracks';

UPDATE public.city_buildings
  SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a5555555-5555-5555-5555-555555555555')
    AND building_type = 'shipyard';

INSERT INTO public.city_units (city_id, unit_type, quantity)
VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'a5555555-5555-5555-5555-555555555555'), 'hoplite',  30),
  ((SELECT id FROM public.cities WHERE owner_id = 'a5555555-5555-5555-5555-555555555555'), 'ram_ship',  5);

INSERT INTO public.unit_movements (
  origin_city_id,
  destination_city_id,
  owner_id,
  units,
  depart_at,
  arrive_at,
  movement_type
)
VALUES (
  (SELECT id FROM public.cities WHERE owner_id = 'a5555555-5555-5555-5555-555555555555'),
  (SELECT id FROM public.cities WHERE owner_id = 'a6666666-6666-6666-6666-666666666666'),
  'a5555555-5555-5555-5555-555555555555',
  '{"hoplite": 20}',
  NOW(),
  NOW() + INTERVAL '10 minutes',
  'attack'
);

-- ============================================================
-- === Account 6: Darius — ACTIVE DEFENDER ===
-- barracks=2, town_wall=2; units: hoplite=40, archer=15
-- Active battle against account 5 (inserted directly, bypassing process_arrivals)
-- ============================================================

UPDATE public.city_buildings
  SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a6666666-6666-6666-6666-666666666666')
    AND building_type = 'barracks';

UPDATE public.city_buildings
  SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a6666666-6666-6666-6666-666666666666')
    AND building_type = 'town_wall';

INSERT INTO public.city_units (city_id, unit_type, quantity)
VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'a6666666-6666-6666-6666-666666666666'), 'hoplite', 40),
  ((SELECT id FROM public.cities WHERE owner_id = 'a6666666-6666-6666-6666-666666666666'), 'archer',  15);

-- Insert active battle between account 5 (attacker) and account 6 (defender)
-- Inserted directly — no unit_movements row needed (bypasses process_arrivals)
INSERT INTO public.battles (
  attacker_id,
  defender_id,
  attacker_city_id,
  defender_city_id,
  attacker_units,
  defender_units,
  status,
  turn_number,
  next_turn_at
)
VALUES (
  'a5555555-5555-5555-5555-555555555555',
  'a6666666-6666-6666-6666-666666666666',
  (SELECT id FROM public.cities WHERE owner_id = 'a5555555-5555-5555-5555-555555555555'),
  (SELECT id FROM public.cities WHERE owner_id = 'a6666666-6666-6666-6666-666666666666'),
  '{"hoplite": 25}',
  '{"hoplite": 40, "archer": 15}',
  'active',
  1,
  NOW() + INTERVAL '30 seconds'
);

-- Insert turn 1 battle_turns row for the active battle
INSERT INTO public.battle_turns (
  battle_id,
  turn_number,
  naval_outcome,
  land_attacker_casualties,
  land_defender_casualties,
  land_outcome,
  attacker_survivors,
  defender_survivors
)
VALUES (
  (SELECT id FROM public.battles
    WHERE attacker_id = 'a5555555-5555-5555-5555-555555555555'
      AND defender_id = 'a6666666-6666-6666-6666-666666666666'
      AND status = 'active'),
  1,
  'skipped',
  '{"hoplite": 5}',
  '{"hoplite": 8, "archer": 3}',
  'ongoing',
  '{"hoplite": 20}',
  '{"hoplite": 32, "archer": 12}'
);

-- ============================================================
-- === Account 7: Cleopatra — CONSTRUCTION ACTIVE ===
-- town_hall=2; construction queue: warehouse upgrade to level 2
-- ============================================================

UPDATE public.city_buildings
  SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'a7777777-7777-7777-7777-777777777777')
    AND building_type = 'town_hall';

INSERT INTO public.construction_queue (city_id, building_type, target_level, finish_at)
VALUES (
  (SELECT id FROM public.cities WHERE owner_id = 'a7777777-7777-7777-7777-777777777777'),
  'warehouse',
  2,
  NOW() + INTERVAL '15 minutes'
);

-- ============================================================
-- Admin flag for GodMode testing (Phases 21-22)
-- ============================================================
UPDATE public.profiles SET is_admin = true WHERE id = 'a1111111-1111-1111-1111-111111111111';

-- ============================================================
-- Bot accounts (20 bots for v1.3)
-- All passwords: "test1234". handle_new_user trigger auto-creates profile + city.
-- ON CONFLICT (id) DO NOTHING for idempotency.
-- ============================================================

-- === LOW TIER bots (1-7): building levels 1-2, basic armies ===
-- === MID TIER bots (8-14): building levels 3-4, mixed armies ===
-- === HIGH TIER bots (15-20): building levels 5-6, full armies ===

INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  confirmation_token, raw_app_meta_data, raw_user_meta_data
) VALUES
  -- LOW TIER (bots 1-7)
  (
    '00000000-0000-0000-0000-000000000000',
    'b0100000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot1@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b0200000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot2@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b0300000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot3@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b0400000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot4@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b0500000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot5@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b0600000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot6@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b0700000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot7@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  -- MID TIER (bots 8-14)
  (
    '00000000-0000-0000-0000-000000000000',
    'b0800000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot8@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b0900000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot9@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b1000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot10@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b1100000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot11@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b1200000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot12@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b1300000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot13@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b1400000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot14@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  -- HIGH TIER (bots 15-20)
  (
    '00000000-0000-0000-0000-000000000000',
    'b1500000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot15@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b1600000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot16@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b1700000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot17@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b1800000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot18@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b1900000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot19@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b2000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'bot20@bot.local',
    crypt('test1234', gen_salt('bf')),
    NOW(), NOW(), NOW(), '',
    '{"provider":"email","providers":["email"]}',
    '{}'
  )
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Bot auth.identities (required for email login)
-- ============================================================

INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
VALUES
  (
    'b0100000-0000-0000-0000-000000000000',
    'b0100000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b0100000-0000-0000-0000-000000000000', 'email', 'bot1@bot.local'),
    'email', 'b0100000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  ),
  (
    'b0200000-0000-0000-0000-000000000000',
    'b0200000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b0200000-0000-0000-0000-000000000000', 'email', 'bot2@bot.local'),
    'email', 'b0200000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  ),
  (
    'b0300000-0000-0000-0000-000000000000',
    'b0300000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b0300000-0000-0000-0000-000000000000', 'email', 'bot3@bot.local'),
    'email', 'b0300000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  ),
  (
    'b0400000-0000-0000-0000-000000000000',
    'b0400000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b0400000-0000-0000-0000-000000000000', 'email', 'bot4@bot.local'),
    'email', 'b0400000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  ),
  (
    'b0500000-0000-0000-0000-000000000000',
    'b0500000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b0500000-0000-0000-0000-000000000000', 'email', 'bot5@bot.local'),
    'email', 'b0500000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  ),
  (
    'b0600000-0000-0000-0000-000000000000',
    'b0600000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b0600000-0000-0000-0000-000000000000', 'email', 'bot6@bot.local'),
    'email', 'b0600000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  ),
  (
    'b0700000-0000-0000-0000-000000000000',
    'b0700000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b0700000-0000-0000-0000-000000000000', 'email', 'bot7@bot.local'),
    'email', 'b0700000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  ),
  (
    'b0800000-0000-0000-0000-000000000000',
    'b0800000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b0800000-0000-0000-0000-000000000000', 'email', 'bot8@bot.local'),
    'email', 'b0800000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  ),
  (
    'b0900000-0000-0000-0000-000000000000',
    'b0900000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b0900000-0000-0000-0000-000000000000', 'email', 'bot9@bot.local'),
    'email', 'b0900000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  ),
  (
    'b1000000-0000-0000-0000-000000000000',
    'b1000000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b1000000-0000-0000-0000-000000000000', 'email', 'bot10@bot.local'),
    'email', 'b1000000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  ),
  (
    'b1100000-0000-0000-0000-000000000000',
    'b1100000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b1100000-0000-0000-0000-000000000000', 'email', 'bot11@bot.local'),
    'email', 'b1100000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  ),
  (
    'b1200000-0000-0000-0000-000000000000',
    'b1200000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b1200000-0000-0000-0000-000000000000', 'email', 'bot12@bot.local'),
    'email', 'b1200000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  ),
  (
    'b1300000-0000-0000-0000-000000000000',
    'b1300000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b1300000-0000-0000-0000-000000000000', 'email', 'bot13@bot.local'),
    'email', 'b1300000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  ),
  (
    'b1400000-0000-0000-0000-000000000000',
    'b1400000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b1400000-0000-0000-0000-000000000000', 'email', 'bot14@bot.local'),
    'email', 'b1400000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  ),
  (
    'b1500000-0000-0000-0000-000000000000',
    'b1500000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b1500000-0000-0000-0000-000000000000', 'email', 'bot15@bot.local'),
    'email', 'b1500000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  ),
  (
    'b1600000-0000-0000-0000-000000000000',
    'b1600000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b1600000-0000-0000-0000-000000000000', 'email', 'bot16@bot.local'),
    'email', 'b1600000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  ),
  (
    'b1700000-0000-0000-0000-000000000000',
    'b1700000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b1700000-0000-0000-0000-000000000000', 'email', 'bot17@bot.local'),
    'email', 'b1700000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  ),
  (
    'b1800000-0000-0000-0000-000000000000',
    'b1800000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b1800000-0000-0000-0000-000000000000', 'email', 'bot18@bot.local'),
    'email', 'b1800000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  ),
  (
    'b1900000-0000-0000-0000-000000000000',
    'b1900000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b1900000-0000-0000-0000-000000000000', 'email', 'bot19@bot.local'),
    'email', 'b1900000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  ),
  (
    'b2000000-0000-0000-0000-000000000000',
    'b2000000-0000-0000-0000-000000000000',
    jsonb_build_object('sub', 'b2000000-0000-0000-0000-000000000000', 'email', 'bot20@bot.local'),
    'email', 'b2000000-0000-0000-0000-000000000000',
    NOW(), NOW(), NOW()
  )
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Bot profile UPDATEs: display_name + is_bot = true
-- ============================================================

UPDATE public.profiles SET display_name = 'Achilles',     is_bot = true WHERE id = 'b0100000-0000-0000-0000-000000000000';
UPDATE public.profiles SET display_name = 'Hector',       is_bot = true WHERE id = 'b0200000-0000-0000-0000-000000000000';
UPDATE public.profiles SET display_name = 'Odysseus',     is_bot = true WHERE id = 'b0300000-0000-0000-0000-000000000000';
UPDATE public.profiles SET display_name = 'Ajax',         is_bot = true WHERE id = 'b0400000-0000-0000-0000-000000000000';
UPDATE public.profiles SET display_name = 'Nestor',       is_bot = true WHERE id = 'b0500000-0000-0000-0000-000000000000';
UPDATE public.profiles SET display_name = 'Agamemnon',    is_bot = true WHERE id = 'b0600000-0000-0000-0000-000000000000';
UPDATE public.profiles SET display_name = 'Patroclus',    is_bot = true WHERE id = 'b0700000-0000-0000-0000-000000000000';
UPDATE public.profiles SET display_name = 'Diomedes',     is_bot = true WHERE id = 'b0800000-0000-0000-0000-000000000000';
UPDATE public.profiles SET display_name = 'Menelaus',     is_bot = true WHERE id = 'b0900000-0000-0000-0000-000000000000';
UPDATE public.profiles SET display_name = 'Heracles',     is_bot = true WHERE id = 'b1000000-0000-0000-0000-000000000000';
UPDATE public.profiles SET display_name = 'Theseus',      is_bot = true WHERE id = 'b1100000-0000-0000-0000-000000000000';
UPDATE public.profiles SET display_name = 'Perseus',      is_bot = true WHERE id = 'b1200000-0000-0000-0000-000000000000';
UPDATE public.profiles SET display_name = 'Ares',         is_bot = true WHERE id = 'b1300000-0000-0000-0000-000000000000';
UPDATE public.profiles SET display_name = 'Prometheus',   is_bot = true WHERE id = 'b1400000-0000-0000-0000-000000000000';
UPDATE public.profiles SET display_name = 'Alexander',    is_bot = true WHERE id = 'b1500000-0000-0000-0000-000000000000';
UPDATE public.profiles SET display_name = 'Hannibal',     is_bot = true WHERE id = 'b1600000-0000-0000-0000-000000000000';
UPDATE public.profiles SET display_name = 'Spartacus',    is_bot = true WHERE id = 'b1700000-0000-0000-0000-000000000000';
UPDATE public.profiles SET display_name = 'Pyrrhus',      is_bot = true WHERE id = 'b1800000-0000-0000-0000-000000000000';
UPDATE public.profiles SET display_name = 'Miltiades',    is_bot = true WHERE id = 'b1900000-0000-0000-0000-000000000000';
UPDATE public.profiles SET display_name = 'Epaminondas',  is_bot = true WHERE id = 'b2000000-0000-0000-0000-000000000000';

-- ============================================================
-- Bot city_buildings UPDATEs (only override trigger defaults)
-- Trigger defaults: town_hall=1, sawmill=1, quarry=1, glassblower=1, sulfur_pit=1, all others=0
-- ============================================================

-- === Bot 1: Achilles — LOW, military-light ===
-- town_hall=1 (default), warehouse=1, barracks=1
UPDATE public.city_buildings SET level = 1
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0100000-0000-0000-0000-000000000000')
    AND building_type = 'warehouse';
UPDATE public.city_buildings SET level = 1
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0100000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';

-- === Bot 2: Hector — LOW, economy ===
-- town_hall=2, warehouse=1, sawmill=2 (default=1, update to 2), barracks=1
UPDATE public.city_buildings SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0200000-0000-0000-0000-000000000000')
    AND building_type = 'town_hall';
UPDATE public.city_buildings SET level = 1
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0200000-0000-0000-0000-000000000000')
    AND building_type = 'warehouse';
UPDATE public.city_buildings SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0200000-0000-0000-0000-000000000000')
    AND building_type = 'sawmill';
UPDATE public.city_buildings SET level = 1
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0200000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';

-- === Bot 3: Odysseus — LOW, balanced ===
-- town_hall=1 (default), barracks=1, academy=1
UPDATE public.city_buildings SET level = 1
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0300000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';
UPDATE public.city_buildings SET level = 1
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0300000-0000-0000-0000-000000000000')
    AND building_type = 'academy';

-- === Bot 4: Ajax — LOW, defensive ===
-- town_hall=2, barracks=1, town_wall=1
UPDATE public.city_buildings SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0400000-0000-0000-0000-000000000000')
    AND building_type = 'town_hall';
UPDATE public.city_buildings SET level = 1
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0400000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';
UPDATE public.city_buildings SET level = 1
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0400000-0000-0000-0000-000000000000')
    AND building_type = 'town_wall';

-- === Bot 5: Nestor — LOW, economy ===
-- town_hall=1 (default), warehouse=2, trading_port=1, barracks=1
UPDATE public.city_buildings SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0500000-0000-0000-0000-000000000000')
    AND building_type = 'warehouse';
UPDATE public.city_buildings SET level = 1
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0500000-0000-0000-0000-000000000000')
    AND building_type = 'trading_port';
UPDATE public.city_buildings SET level = 1
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0500000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';

-- === Bot 6: Agamemnon — LOW, resource ===
-- town_hall=2, sawmill=2 (default=1, update to 2), quarry=1 (default), barracks=1
UPDATE public.city_buildings SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0600000-0000-0000-0000-000000000000')
    AND building_type = 'town_hall';
UPDATE public.city_buildings SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0600000-0000-0000-0000-000000000000')
    AND building_type = 'sawmill';
UPDATE public.city_buildings SET level = 1
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0600000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';

-- === Bot 7: Patroclus — LOW, naval ===
-- town_hall=1 (default), barracks=1, shipyard=1
UPDATE public.city_buildings SET level = 1
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0700000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';
UPDATE public.city_buildings SET level = 1
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0700000-0000-0000-0000-000000000000')
    AND building_type = 'shipyard';

-- === Bot 8: Diomedes — MID, military ===
-- town_hall=3, barracks=3, warehouse=2
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0800000-0000-0000-0000-000000000000')
    AND building_type = 'town_hall';
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0800000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';
UPDATE public.city_buildings SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0800000-0000-0000-0000-000000000000')
    AND building_type = 'warehouse';

-- === Bot 9: Menelaus — MID, balanced ===
-- town_hall=3, barracks=2, academy=3, warehouse=2
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0900000-0000-0000-0000-000000000000')
    AND building_type = 'town_hall';
UPDATE public.city_buildings SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0900000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0900000-0000-0000-0000-000000000000')
    AND building_type = 'academy';
UPDATE public.city_buildings SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0900000-0000-0000-0000-000000000000')
    AND building_type = 'warehouse';

-- === Bot 10: Heracles — MID, military ===
-- town_hall=4, barracks=3, town_wall=2, warehouse=3
UPDATE public.city_buildings SET level = 4
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1000000-0000-0000-0000-000000000000')
    AND building_type = 'town_hall';
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1000000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';
UPDATE public.city_buildings SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1000000-0000-0000-0000-000000000000')
    AND building_type = 'town_wall';
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1000000-0000-0000-0000-000000000000')
    AND building_type = 'warehouse';

-- === Bot 11: Theseus — MID, naval ===
-- town_hall=3, barracks=2, shipyard=3, warehouse=2
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1100000-0000-0000-0000-000000000000')
    AND building_type = 'town_hall';
UPDATE public.city_buildings SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1100000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1100000-0000-0000-0000-000000000000')
    AND building_type = 'shipyard';
UPDATE public.city_buildings SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1100000-0000-0000-0000-000000000000')
    AND building_type = 'warehouse';

-- === Bot 12: Perseus — MID, economy ===
-- town_hall=4, warehouse=4, sawmill=3, quarry=3, barracks=2
UPDATE public.city_buildings SET level = 4
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1200000-0000-0000-0000-000000000000')
    AND building_type = 'town_hall';
UPDATE public.city_buildings SET level = 4
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1200000-0000-0000-0000-000000000000')
    AND building_type = 'warehouse';
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1200000-0000-0000-0000-000000000000')
    AND building_type = 'sawmill';
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1200000-0000-0000-0000-000000000000')
    AND building_type = 'quarry';
UPDATE public.city_buildings SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1200000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';

-- === Bot 13: Ares — MID, defensive ===
-- town_hall=3, barracks=3, town_wall=3
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1300000-0000-0000-0000-000000000000')
    AND building_type = 'town_hall';
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1300000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1300000-0000-0000-0000-000000000000')
    AND building_type = 'town_wall';

-- === Bot 14: Prometheus — MID, economy ===
-- town_hall=4, academy=4, warehouse=3, trading_port=2, barracks=2
UPDATE public.city_buildings SET level = 4
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1400000-0000-0000-0000-000000000000')
    AND building_type = 'town_hall';
UPDATE public.city_buildings SET level = 4
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1400000-0000-0000-0000-000000000000')
    AND building_type = 'academy';
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1400000-0000-0000-0000-000000000000')
    AND building_type = 'warehouse';
UPDATE public.city_buildings SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1400000-0000-0000-0000-000000000000')
    AND building_type = 'trading_port';
UPDATE public.city_buildings SET level = 2
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1400000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';

-- === Bot 15: Alexander — HIGH, military ===
-- town_hall=6, barracks=5, warehouse=4, town_wall=3, shipyard=3
UPDATE public.city_buildings SET level = 6
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1500000-0000-0000-0000-000000000000')
    AND building_type = 'town_hall';
UPDATE public.city_buildings SET level = 5
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1500000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';
UPDATE public.city_buildings SET level = 4
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1500000-0000-0000-0000-000000000000')
    AND building_type = 'warehouse';
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1500000-0000-0000-0000-000000000000')
    AND building_type = 'town_wall';
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1500000-0000-0000-0000-000000000000')
    AND building_type = 'shipyard';

-- === Bot 16: Hannibal — HIGH, military ===
-- town_hall=5, barracks=5, town_wall=4, warehouse=3
UPDATE public.city_buildings SET level = 5
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1600000-0000-0000-0000-000000000000')
    AND building_type = 'town_hall';
UPDATE public.city_buildings SET level = 5
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1600000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';
UPDATE public.city_buildings SET level = 4
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1600000-0000-0000-0000-000000000000')
    AND building_type = 'town_wall';
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1600000-0000-0000-0000-000000000000')
    AND building_type = 'warehouse';

-- === Bot 17: Spartacus — HIGH, balanced ===
-- town_hall=5, barracks=4, warehouse=5, academy=3
UPDATE public.city_buildings SET level = 5
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1700000-0000-0000-0000-000000000000')
    AND building_type = 'town_hall';
UPDATE public.city_buildings SET level = 4
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1700000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';
UPDATE public.city_buildings SET level = 5
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1700000-0000-0000-0000-000000000000')
    AND building_type = 'warehouse';
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1700000-0000-0000-0000-000000000000')
    AND building_type = 'academy';

-- === Bot 18: Pyrrhus — HIGH, naval ===
-- town_hall=6, barracks=4, shipyard=4, warehouse=4
UPDATE public.city_buildings SET level = 6
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1800000-0000-0000-0000-000000000000')
    AND building_type = 'town_hall';
UPDATE public.city_buildings SET level = 4
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1800000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';
UPDATE public.city_buildings SET level = 4
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1800000-0000-0000-0000-000000000000')
    AND building_type = 'shipyard';
UPDATE public.city_buildings SET level = 4
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1800000-0000-0000-0000-000000000000')
    AND building_type = 'warehouse';

-- === Bot 19: Miltiades — HIGH, defensive ===
-- town_hall=5, barracks=5, town_wall=5, hideout=3
UPDATE public.city_buildings SET level = 5
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1900000-0000-0000-0000-000000000000')
    AND building_type = 'town_hall';
UPDATE public.city_buildings SET level = 5
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1900000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';
UPDATE public.city_buildings SET level = 5
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1900000-0000-0000-0000-000000000000')
    AND building_type = 'town_wall';
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1900000-0000-0000-0000-000000000000')
    AND building_type = 'hideout';

-- === Bot 20: Epaminondas — HIGH, economy ===
-- town_hall=6, warehouse=5, sawmill=5, quarry=4, academy=4, barracks=3
UPDATE public.city_buildings SET level = 6
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b2000000-0000-0000-0000-000000000000')
    AND building_type = 'town_hall';
UPDATE public.city_buildings SET level = 5
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b2000000-0000-0000-0000-000000000000')
    AND building_type = 'warehouse';
UPDATE public.city_buildings SET level = 5
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b2000000-0000-0000-0000-000000000000')
    AND building_type = 'sawmill';
UPDATE public.city_buildings SET level = 4
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b2000000-0000-0000-0000-000000000000')
    AND building_type = 'quarry';
UPDATE public.city_buildings SET level = 4
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b2000000-0000-0000-0000-000000000000')
    AND building_type = 'academy';
UPDATE public.city_buildings SET level = 3
  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b2000000-0000-0000-0000-000000000000')
    AND building_type = 'barracks';

-- ============================================================
-- Bot city_resources UPDATEs (all 5 resource types per bot)
-- ============================================================

-- === LOW TIER bots (1-7): resources 500-1500 ===

-- Bot 1: Achilles
UPDATE public.city_resources SET amount = 800   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0100000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 500   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0100000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 200   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0100000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 100   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0100000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 600   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0100000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- Bot 2: Hector
UPDATE public.city_resources SET amount = 1200  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0200000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 300   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0200000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 100   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0200000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 100   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0200000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 900   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0200000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- Bot 3: Odysseus
UPDATE public.city_resources SET amount = 700   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0300000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 400   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0300000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 300   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0300000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 200   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0300000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 500   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0300000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- Bot 4: Ajax
UPDATE public.city_resources SET amount = 1000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0400000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 600   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0400000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 150   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0400000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 150   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0400000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 700   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0400000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- Bot 5: Nestor
UPDATE public.city_resources SET amount = 1500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0500000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 800   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0500000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 400   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0500000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 300   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0500000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 1200  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0500000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- Bot 6: Agamemnon
UPDATE public.city_resources SET amount = 1300  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0600000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 700   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0600000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 250   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0600000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 200   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0600000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 1000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0600000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- Bot 7: Patroclus
UPDATE public.city_resources SET amount = 900   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0700000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 500   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0700000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 200   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0700000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 150   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0700000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 800   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0700000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- === MID TIER bots (8-14): resources 2000-5000 ===

-- Bot 8: Diomedes
UPDATE public.city_resources SET amount = 3000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0800000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 2000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0800000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 1000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0800000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 800   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0800000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 2500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0800000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- Bot 9: Menelaus
UPDATE public.city_resources SET amount = 2500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0900000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 2500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0900000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 1500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0900000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 1000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0900000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 3000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b0900000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- Bot 10: Heracles
UPDATE public.city_resources SET amount = 4000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1000000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 2500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1000000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 1200  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1000000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 1500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1000000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 3500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1000000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- Bot 11: Theseus
UPDATE public.city_resources SET amount = 3500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1100000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 2000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1100000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 2000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1100000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 1000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1100000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 2800  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1100000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- Bot 12: Perseus
UPDATE public.city_resources SET amount = 5000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1200000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 4000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1200000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 2500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1200000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 2000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1200000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 4500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1200000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- Bot 13: Ares
UPDATE public.city_resources SET amount = 2500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1300000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 2000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1300000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 800   WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1300000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 1200  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1300000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 2000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1300000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- Bot 14: Prometheus
UPDATE public.city_resources SET amount = 4500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1400000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 3500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1400000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 3000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1400000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 2500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1400000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 5000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1400000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- === HIGH TIER bots (15-20): resources 5000-15000 ===

-- Bot 15: Alexander
UPDATE public.city_resources SET amount = 10000 WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1500000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 8000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1500000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 5000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1500000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 6000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1500000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 12000 WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1500000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- Bot 16: Hannibal
UPDATE public.city_resources SET amount = 8000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1600000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 7000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1600000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 4000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1600000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 5000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1600000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 9000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1600000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- Bot 17: Spartacus
UPDATE public.city_resources SET amount = 12000 WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1700000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 6000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1700000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 5500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1700000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 4500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1700000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 10000 WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1700000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- Bot 18: Pyrrhus
UPDATE public.city_resources SET amount = 9000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1800000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 7500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1800000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 6000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1800000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 3500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1800000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 11000 WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1800000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- Bot 19: Miltiades
UPDATE public.city_resources SET amount = 7000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1900000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 6000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1900000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 3500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1900000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 5500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1900000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 8000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b1900000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- Bot 20: Epaminondas
UPDATE public.city_resources SET amount = 15000 WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b2000000-0000-0000-0000-000000000000') AND resource_type = 'wood';
UPDATE public.city_resources SET amount = 10000 WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b2000000-0000-0000-0000-000000000000') AND resource_type = 'marble';
UPDATE public.city_resources SET amount = 7000  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b2000000-0000-0000-0000-000000000000') AND resource_type = 'crystal';
UPDATE public.city_resources SET amount = 6500  WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b2000000-0000-0000-0000-000000000000') AND resource_type = 'sulfur';
UPDATE public.city_resources SET amount = 14000 WHERE city_id = (SELECT id FROM public.cities WHERE owner_id = 'b2000000-0000-0000-0000-000000000000') AND resource_type = 'gold';

-- ============================================================
-- Bot city_units UPSERTs
-- ON CONFLICT (city_id, unit_type) DO UPDATE for idempotency
-- ============================================================

-- === LOW TIER (bots 1-7): hoplite + cook only (barracks=1) ===

-- Bot 1: Achilles
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b0100000-0000-0000-0000-000000000000'), 'hoplite', 10),
  ((SELECT id FROM public.cities WHERE owner_id = 'b0100000-0000-0000-0000-000000000000'), 'cook',    2)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- Bot 2: Hector
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b0200000-0000-0000-0000-000000000000'), 'hoplite', 5),
  ((SELECT id FROM public.cities WHERE owner_id = 'b0200000-0000-0000-0000-000000000000'), 'cook',    3)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- Bot 3: Odysseus
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b0300000-0000-0000-0000-000000000000'), 'hoplite', 8),
  ((SELECT id FROM public.cities WHERE owner_id = 'b0300000-0000-0000-0000-000000000000'), 'cook',    2)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- Bot 4: Ajax
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b0400000-0000-0000-0000-000000000000'), 'hoplite', 12),
  ((SELECT id FROM public.cities WHERE owner_id = 'b0400000-0000-0000-0000-000000000000'), 'cook',    3)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- Bot 5: Nestor
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b0500000-0000-0000-0000-000000000000'), 'hoplite', 6),
  ((SELECT id FROM public.cities WHERE owner_id = 'b0500000-0000-0000-0000-000000000000'), 'cook',    2)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- Bot 6: Agamemnon
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b0600000-0000-0000-0000-000000000000'), 'hoplite', 15),
  ((SELECT id FROM public.cities WHERE owner_id = 'b0600000-0000-0000-0000-000000000000'), 'cook',    2)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- Bot 7: Patroclus
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b0700000-0000-0000-0000-000000000000'), 'hoplite', 7),
  ((SELECT id FROM public.cities WHERE owner_id = 'b0700000-0000-0000-0000-000000000000'), 'cook',    2)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- === MID TIER (bots 8-14): adds archer, phalanx, cavalry (barracks=2-3) ===

-- Bot 8: Diomedes (barracks=3: hoplite, archer, phalanx, cavalry all ok)
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b0800000-0000-0000-0000-000000000000'), 'hoplite', 25),
  ((SELECT id FROM public.cities WHERE owner_id = 'b0800000-0000-0000-0000-000000000000'), 'archer',  10),
  ((SELECT id FROM public.cities WHERE owner_id = 'b0800000-0000-0000-0000-000000000000'), 'phalanx',  8),
  ((SELECT id FROM public.cities WHERE owner_id = 'b0800000-0000-0000-0000-000000000000'), 'cook',     3)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- Bot 9: Menelaus (barracks=2: hoplite, archer, phalanx ok)
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b0900000-0000-0000-0000-000000000000'), 'hoplite', 20),
  ((SELECT id FROM public.cities WHERE owner_id = 'b0900000-0000-0000-0000-000000000000'), 'archer',  15),
  ((SELECT id FROM public.cities WHERE owner_id = 'b0900000-0000-0000-0000-000000000000'), 'phalanx',  5),
  ((SELECT id FROM public.cities WHERE owner_id = 'b0900000-0000-0000-0000-000000000000'), 'cook',     4)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- Bot 10: Heracles (barracks=3: includes cavalry)
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b1000000-0000-0000-0000-000000000000'), 'hoplite',  30),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1000000-0000-0000-0000-000000000000'), 'archer',   10),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1000000-0000-0000-0000-000000000000'), 'phalanx',  10),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1000000-0000-0000-0000-000000000000'), 'cavalry',   5),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1000000-0000-0000-0000-000000000000'), 'cook',      3)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- Bot 11: Theseus (barracks=2: archer, phalanx ok; also naval)
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b1100000-0000-0000-0000-000000000000'), 'hoplite',    20),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1100000-0000-0000-0000-000000000000'), 'archer',     10),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1100000-0000-0000-0000-000000000000'), 'phalanx',     5),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1100000-0000-0000-0000-000000000000'), 'cook',        3),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1100000-0000-0000-0000-000000000000'), 'cargo_ship',  5),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1100000-0000-0000-0000-000000000000'), 'ram_ship',    3)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- Bot 12: Perseus (barracks=2: archer ok)
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b1200000-0000-0000-0000-000000000000'), 'hoplite', 15),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1200000-0000-0000-0000-000000000000'), 'archer',  10),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1200000-0000-0000-0000-000000000000'), 'cook',     5)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- Bot 13: Ares (barracks=3: includes cavalry)
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b1300000-0000-0000-0000-000000000000'), 'hoplite',  35),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1300000-0000-0000-0000-000000000000'), 'phalanx',  15),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1300000-0000-0000-0000-000000000000'), 'cavalry',   5),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1300000-0000-0000-0000-000000000000'), 'cook',      3)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- Bot 14: Prometheus (barracks=2: archer, phalanx ok)
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b1400000-0000-0000-0000-000000000000'), 'hoplite', 20),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1400000-0000-0000-0000-000000000000'), 'archer',  15),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1400000-0000-0000-0000-000000000000'), 'phalanx', 10),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1400000-0000-0000-0000-000000000000'), 'cook',     4)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- === HIGH TIER (bots 15-20): full unit mix including catapult/mortar ===

-- Bot 15: Alexander (barracks=5: catapult=4, mortar=5 both ok)
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b1500000-0000-0000-0000-000000000000'), 'hoplite',  50),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1500000-0000-0000-0000-000000000000'), 'archer',   25),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1500000-0000-0000-0000-000000000000'), 'phalanx',  20),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1500000-0000-0000-0000-000000000000'), 'cavalry',  15),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1500000-0000-0000-0000-000000000000'), 'catapult',  5),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1500000-0000-0000-0000-000000000000'), 'mortar',    3),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1500000-0000-0000-0000-000000000000'), 'cook',      5),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1500000-0000-0000-0000-000000000000'), 'ram_ship',  5)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- Bot 16: Hannibal (barracks=5: catapult ok, no mortar)
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b1600000-0000-0000-0000-000000000000'), 'hoplite',  60),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1600000-0000-0000-0000-000000000000'), 'archer',   20),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1600000-0000-0000-0000-000000000000'), 'phalanx',  15),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1600000-0000-0000-0000-000000000000'), 'cavalry',  10),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1600000-0000-0000-0000-000000000000'), 'catapult',  8),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1600000-0000-0000-0000-000000000000'), 'cook',      5)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- Bot 17: Spartacus (barracks=4: catapult ok, no mortar)
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b1700000-0000-0000-0000-000000000000'), 'hoplite',  40),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1700000-0000-0000-0000-000000000000'), 'archer',   30),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1700000-0000-0000-0000-000000000000'), 'phalanx',  15),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1700000-0000-0000-0000-000000000000'), 'cavalry',  10),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1700000-0000-0000-0000-000000000000'), 'catapult',  3),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1700000-0000-0000-0000-000000000000'), 'cook',      5)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- Bot 18: Pyrrhus (barracks=4: catapult ok, also naval)
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b1800000-0000-0000-0000-000000000000'), 'hoplite',       35),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1800000-0000-0000-0000-000000000000'), 'archer',        15),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1800000-0000-0000-0000-000000000000'), 'phalanx',       10),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1800000-0000-0000-0000-000000000000'), 'cavalry',        8),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1800000-0000-0000-0000-000000000000'), 'cook',           4),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1800000-0000-0000-0000-000000000000'), 'cargo_ship',     8),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1800000-0000-0000-0000-000000000000'), 'ram_ship',       5),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1800000-0000-0000-0000-000000000000'), 'catapult_ship',  3)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- Bot 19: Miltiades (barracks=5: catapult and mortar ok)
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b1900000-0000-0000-0000-000000000000'), 'hoplite',  55),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1900000-0000-0000-0000-000000000000'), 'archer',   20),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1900000-0000-0000-0000-000000000000'), 'phalanx',  20),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1900000-0000-0000-0000-000000000000'), 'cavalry',  12),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1900000-0000-0000-0000-000000000000'), 'catapult',  6),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1900000-0000-0000-0000-000000000000'), 'mortar',    4),
  ((SELECT id FROM public.cities WHERE owner_id = 'b1900000-0000-0000-0000-000000000000'), 'cook',      5)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- Bot 20: Epaminondas (barracks=3: cavalry ok, no catapult/mortar)
INSERT INTO public.city_units (city_id, unit_type, quantity) VALUES
  ((SELECT id FROM public.cities WHERE owner_id = 'b2000000-0000-0000-0000-000000000000'), 'hoplite',  30),
  ((SELECT id FROM public.cities WHERE owner_id = 'b2000000-0000-0000-0000-000000000000'), 'archer',   25),
  ((SELECT id FROM public.cities WHERE owner_id = 'b2000000-0000-0000-0000-000000000000'), 'phalanx',  10),
  ((SELECT id FROM public.cities WHERE owner_id = 'b2000000-0000-0000-0000-000000000000'), 'cavalry',   5),
  ((SELECT id FROM public.cities WHERE owner_id = 'b2000000-0000-0000-0000-000000000000'), 'cook',      6)
ON CONFLICT (city_id, unit_type) DO UPDATE SET quantity = EXCLUDED.quantity;

-- ============================================================
-- Bot schedules: staggered next_action_at (45-second intervals)
-- Aggression distribution: 5 at 0, 5 at 1, 5 at 2, 5 at 3
-- ============================================================

INSERT INTO public.bot_schedules (bot_id, is_paused, aggression, next_action_at)
VALUES
  ('b0100000-0000-0000-0000-000000000000', false, 0, NOW() + (0  * INTERVAL '45 seconds')),
  ('b0200000-0000-0000-0000-000000000000', false, 0, NOW() + (1  * INTERVAL '45 seconds')),
  ('b0300000-0000-0000-0000-000000000000', false, 1, NOW() + (2  * INTERVAL '45 seconds')),
  ('b0400000-0000-0000-0000-000000000000', false, 1, NOW() + (3  * INTERVAL '45 seconds')),
  ('b0500000-0000-0000-0000-000000000000', false, 0, NOW() + (4  * INTERVAL '45 seconds')),
  ('b0600000-0000-0000-0000-000000000000', false, 0, NOW() + (5  * INTERVAL '45 seconds')),
  ('b0700000-0000-0000-0000-000000000000', false, 1, NOW() + (6  * INTERVAL '45 seconds')),
  ('b0800000-0000-0000-0000-000000000000', false, 1, NOW() + (7  * INTERVAL '45 seconds')),
  ('b0900000-0000-0000-0000-000000000000', false, 1, NOW() + (8  * INTERVAL '45 seconds')),
  ('b1000000-0000-0000-0000-000000000000', false, 2, NOW() + (9  * INTERVAL '45 seconds')),
  ('b1100000-0000-0000-0000-000000000000', false, 2, NOW() + (10 * INTERVAL '45 seconds')),
  ('b1200000-0000-0000-0000-000000000000', false, 2, NOW() + (11 * INTERVAL '45 seconds')),
  ('b1300000-0000-0000-0000-000000000000', false, 0, NOW() + (12 * INTERVAL '45 seconds')),
  ('b1400000-0000-0000-0000-000000000000', false, 2, NOW() + (13 * INTERVAL '45 seconds')),
  ('b1500000-0000-0000-0000-000000000000', false, 3, NOW() + (14 * INTERVAL '45 seconds')),
  ('b1600000-0000-0000-0000-000000000000', false, 3, NOW() + (15 * INTERVAL '45 seconds')),
  ('b1700000-0000-0000-0000-000000000000', false, 3, NOW() + (16 * INTERVAL '45 seconds')),
  ('b1800000-0000-0000-0000-000000000000', false, 2, NOW() + (17 * INTERVAL '45 seconds')),
  ('b1900000-0000-0000-0000-000000000000', false, 3, NOW() + (18 * INTERVAL '45 seconds')),
  ('b2000000-0000-0000-0000-000000000000', false, 3, NOW() + (19 * INTERVAL '45 seconds'))
ON CONFLICT (bot_id) DO UPDATE SET
  aggression     = EXCLUDED.aggression,
  is_paused      = EXCLUDED.is_paused,
  next_action_at = EXCLUDED.next_action_at;
