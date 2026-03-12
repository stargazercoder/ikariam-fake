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
