-- Migration: Economy foundation — cities schema extension + rewritten process_resource_tick()
--
-- Phase 10 Plan 01: Adds population, happiness, wine_spending_rate columns to cities.
-- Adds 'wine' to city_resources CHECK constraint.
-- Seeds wine resource for existing cities.
-- Rewrites on_city_created() to include wine seed.
-- Rewrites process_resource_tick() with 5-step economy loop (no gold via town_hall).
-- Enables Realtime on cities table.

-- ============================================================
-- 1a. Add economy columns to cities table
-- ============================================================
ALTER TABLE public.cities
  ADD COLUMN population         NUMERIC  NOT NULL DEFAULT 100,
  ADD COLUMN happiness          NUMERIC  NOT NULL DEFAULT 0,
  ADD COLUMN wine_spending_rate INTEGER  NOT NULL DEFAULT 0
    CHECK (wine_spending_rate BETWEEN 0 AND 100);

-- ============================================================
-- 1b. Update city_resources CHECK constraint to include 'wine'
-- ============================================================
ALTER TABLE public.city_resources
  DROP CONSTRAINT city_resources_resource_type_check;

ALTER TABLE public.city_resources
  ADD CONSTRAINT city_resources_resource_type_check
    CHECK (resource_type IN ('wood', 'marble', 'crystal', 'sulfur', 'gold', 'wine'));

-- ============================================================
-- 1c. Seed wine resource for ALL existing cities (500 to start)
-- ============================================================
INSERT INTO public.city_resources (city_id, resource_type, amount)
SELECT id, 'wine', 500 FROM public.cities
ON CONFLICT (city_id, resource_type) DO NOTHING;

-- ============================================================
-- 1d. Rewrite on_city_created() — adds wine seed, keeps everything else
-- ============================================================
CREATE OR REPLACE FUNCTION public.on_city_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  -- Seed starting resources: wood and gold have 2500, others have 1000, wine has 500
  INSERT INTO public.city_resources (city_id, resource_type, amount) VALUES
    (NEW.id, 'wood',    2500),
    (NEW.id, 'marble',  1000),
    (NEW.id, 'crystal', 1000),
    (NEW.id, 'sulfur',  1000),
    (NEW.id, 'gold',    2500),
    (NEW.id, 'wine',     500);

  INSERT INTO public.city_buildings (city_id, building_type, level, assigned_workers) VALUES
    (NEW.id, 'town_hall',    1, 3),
    (NEW.id, 'sawmill',      1, 3),
    (NEW.id, 'quarry',       1, 3),
    (NEW.id, 'glassblower',  1, 3),
    (NEW.id, 'sulfur_pit',   1, 3),
    (NEW.id, 'warehouse',    0, 0),
    (NEW.id, 'barracks',     0, 0),
    (NEW.id, 'shipyard',     0, 0),
    (NEW.id, 'academy',      0, 0),
    (NEW.id, 'embassy',      0, 0),
    (NEW.id, 'trading_port', 0, 0),
    (NEW.id, 'town_wall',    0, 0),
    (NEW.id, 'hideout',      0, 0),
    (NEW.id, 'tavern',       0, 0);

  -- Population defaults to 100 via column DEFAULT — no explicit SET needed

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'on_city_created: % %', SQLERRM, SQLSTATE;
    RETURN NEW;
END;
$$;

-- ============================================================
-- 1e. Enable Realtime on cities table
-- ============================================================
ALTER TABLE public.cities REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.cities;

-- ============================================================
-- 1f. Rewrite process_resource_tick() — 5-step economy loop
--
-- Step 1: Resource production (wood, marble, crystal, sulfur ONLY — no gold)
--   - If happiness < 0 → apply 50% production penalty
-- Step 2: Wine consumption (tavern level * wine_spending_rate fraction * 5.0 per tick)
-- Step 3: Happiness calculation (effective_rate * tavern_level) - (population * 0.02)
-- Step 4: Population growth — population * 0.01 * (happiness / 100) per tick when happiness > 0
-- Step 5: Tax collection — idle_citizens * 0.05 gold/tick (= 3 gold/hr at 60s tick)
-- ============================================================
CREATE OR REPLACE FUNCTION public.process_resource_tick()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  c                RECORD;   -- city row
  r                RECORD;   -- inner resource production row
  v_tavern_level   INTEGER;
  v_wine_amount    NUMERIC;
  v_wine_per_tick  NUMERIC;
  v_actual_consumed NUMERIC;
  v_effective_rate NUMERIC;
  v_new_happiness  NUMERIC;
  v_growth         NUMERIC;
  v_total_workers  NUMERIC;
  v_idle           NUMERIC;
  v_gold_income    NUMERIC;
  v_warehouse_level INTEGER;
  v_production_mult NUMERIC;
BEGIN
  FOR c IN
    SELECT id, population, happiness, wine_spending_rate
    FROM public.cities
  LOOP

    -- --------------------------------------------------------
    -- Step 1: Resource production (wood, marble, crystal, sulfur)
    --         Gold is NOT produced here — only via tax (Step 5)
    --         Happiness penalty: multiply production by 0.5 when happiness < 0
    -- --------------------------------------------------------
    IF c.happiness < 0 THEN
      v_production_mult := 0.5;
    ELSE
      v_production_mult := 1.0;
    END IF;

    FOR r IN
      SELECT
        cr.id            AS resource_id,
        cr.resource_type,
        cr.amount        AS current_amount,
        COALESCE(pb.level, 0)            AS prod_level,
        COALESCE(pb.assigned_workers, 0) AS workers,
        COALESCE(wh.level, 0)            AS warehouse_level
      FROM public.city_resources cr
      LEFT JOIN public.city_buildings pb
        ON pb.city_id = c.id
        AND pb.building_type = CASE cr.resource_type
              WHEN 'wood'    THEN 'sawmill'
              WHEN 'marble'  THEN 'quarry'
              WHEN 'crystal' THEN 'glassblower'
              WHEN 'sulfur'  THEN 'sulfur_pit'
            END
      LEFT JOIN public.city_buildings wh
        ON wh.city_id = c.id
        AND wh.building_type = 'warehouse'
      WHERE cr.city_id = c.id
        AND cr.resource_type IN ('wood', 'marble', 'crystal', 'sulfur')
    LOOP
      CONTINUE WHEN r.workers = 0 OR r.prod_level = 0;

      UPDATE public.city_resources
      SET
        amount     = LEAST(
                       r.current_amount + (r.workers * r.prod_level * 5.0 * v_production_mult),
                       500.0 * POWER(1.5, r.warehouse_level)
                     ),
        updated_at = NOW()
      WHERE id = r.resource_id;
    END LOOP;

    -- --------------------------------------------------------
    -- Step 2: Wine consumption
    --   wine_per_tick = (wine_spending_rate / 100.0) * tavern_level * 5.0
    --   actual_consumed = LEAST(wine_per_tick, current_wine_stock)
    -- --------------------------------------------------------
    SELECT COALESCE(level, 0)
    INTO v_tavern_level
    FROM public.city_buildings
    WHERE city_id = c.id AND building_type = 'tavern';

    v_tavern_level := COALESCE(v_tavern_level, 0);

    SELECT COALESCE(amount, 0.0)
    INTO v_wine_amount
    FROM public.city_resources
    WHERE city_id = c.id AND resource_type = 'wine';

    v_wine_amount := COALESCE(v_wine_amount, 0.0);

    -- wine_per_tick: max wine that can be consumed at 100% rate at current tavern level
    v_wine_per_tick := (c.wine_spending_rate / 100.0) * v_tavern_level * 5.0;
    v_actual_consumed := LEAST(v_wine_per_tick, v_wine_amount);

    IF v_actual_consumed > 0 THEN
      UPDATE public.city_resources
      SET
        amount     = amount - v_actual_consumed,
        updated_at = NOW()
      WHERE city_id = c.id AND resource_type = 'wine';
    END IF;

    -- --------------------------------------------------------
    -- Step 3: Happiness calculation
    --   effective_rate = actual_consumed / wine_per_tick (ratio of desired wine fulfilled)
    --   happiness = (effective_rate * wine_spending_rate / 100.0 * tavern_level) - (population * 0.02)
    --   Simplified: happiness = (actual_consumed / NULLIF(wine_per_tick_max, 0) * tavern_level) - (population * 0.02)
    --   where wine_per_tick_max = tavern_level * 5.0 (max at 100% rate)
    -- --------------------------------------------------------
    IF v_tavern_level = 0 OR c.wine_spending_rate = 0 THEN
      v_new_happiness := -(c.population * 0.02);
    ELSE
      -- effective_rate = fraction of desired wine actually consumed (0.0 to 1.0)
      v_effective_rate := v_actual_consumed / NULLIF(v_wine_per_tick, 0.0);
      IF v_effective_rate IS NULL THEN
        v_effective_rate := 0.0;
      END IF;
      -- Happiness: scaled by effective_rate * wine_spending_rate * tavern_level, minus population penalty
      v_new_happiness := (v_effective_rate * (c.wine_spending_rate / 100.0) * v_tavern_level)
                         - (c.population * 0.02);
    END IF;

    UPDATE public.cities
    SET
      happiness  = v_new_happiness
    WHERE id = c.id;

    -- --------------------------------------------------------
    -- Step 4: Population growth
    --   IF happiness > 0: growth = population * 0.01 * (happiness / 100.0)
    --   IF happiness <= 0: no growth (no loss — anti-death-spiral per requirements)
    -- --------------------------------------------------------
    IF v_new_happiness > 0 THEN
      v_growth := c.population * 0.01 * (v_new_happiness / 100.0);
      UPDATE public.cities
      SET
        population = population + v_growth
      WHERE id = c.id;
    END IF;

    -- --------------------------------------------------------
    -- Step 5: Tax collection
    --   idle = GREATEST(population - total_assigned_workers, 0)
    --   gold_income = idle * 3.0 * (60.0 / 3600.0) = idle * 0.05 gold/tick
    --   Capped at warehouse capacity.
    -- --------------------------------------------------------
    SELECT COALESCE(SUM(assigned_workers), 0)
    INTO v_total_workers
    FROM public.city_buildings
    WHERE city_id = c.id;

    v_idle := GREATEST(c.population - v_total_workers, 0);
    v_gold_income := v_idle * 0.05;

    IF v_gold_income > 0 THEN
      SELECT COALESCE(level, 0)
      INTO v_warehouse_level
      FROM public.city_buildings
      WHERE city_id = c.id AND building_type = 'warehouse';

      v_warehouse_level := COALESCE(v_warehouse_level, 0);

      UPDATE public.city_resources
      SET
        amount     = LEAST(amount + v_gold_income, 500.0 * POWER(1.5, v_warehouse_level)),
        updated_at = NOW()
      WHERE city_id = c.id AND resource_type = 'gold';
    END IF;

  END LOOP;
END;
$$;
