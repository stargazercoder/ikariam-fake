-- Migration: Island resource level column + process_resource_tick() extension
--
-- Phase 11 Plan 01:
-- Part 1: Adds resource_level column to islands table (INTEGER 0-10, default 0).
-- Part 2: Rewrites process_resource_tick() to apply island-level production multiplier
--         to Step 1 (resource production). All other steps (2-5) are identical to
--         20260313000001_economy_schema_and_tick.sql.

-- ============================================================
-- Part 1: Add resource_level column to islands table
-- ============================================================
ALTER TABLE public.islands
  ADD COLUMN resource_level INTEGER NOT NULL DEFAULT 0
    CHECK (resource_level BETWEEN 0 AND 10);

-- ============================================================
-- Part 2: Rewrite process_resource_tick() with island multiplier
--
-- Changes from Phase 10 version:
--   - Outer city loop now LEFT JOINs islands ON i.id = c.island_id
--   - Cities table aliased as 'c'; all column refs updated to c.*
--   - New variable: v_island_mult NUMERIC
--   - Step 1 formula: workers * prod_level * 5.0 * v_production_mult * v_island_mult
--   - v_island_mult = 1.0 + COALESCE(c.island_resource_level, 0) * 0.10
--     (Level 0 = 1.0x, Level 5 = 1.5x, Level 10 = 2.0x)
--
-- Steps 2-5 (wine, happiness, population, tax) are IDENTICAL to Phase 10 version.
-- ============================================================
CREATE OR REPLACE FUNCTION public.process_resource_tick()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  c                RECORD;   -- city row (with island_resource_level)
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
  v_island_mult     NUMERIC;
BEGIN
  FOR c IN
    SELECT
      c.id,
      c.population,
      c.happiness,
      c.wine_spending_rate,
      COALESCE(i.resource_level, 0) AS island_resource_level
    FROM public.cities c
    LEFT JOIN public.islands i ON i.id = c.island_id
  LOOP

    -- --------------------------------------------------------
    -- Step 1: Resource production (wood, marble, crystal, sulfur)
    --         Gold is NOT produced here — only via tax (Step 5)
    --         Happiness penalty: multiply production by 0.5 when happiness < 0
    --         Island multiplier: 1.0 + island_resource_level * 0.10
    -- --------------------------------------------------------
    IF c.happiness < 0 THEN
      v_production_mult := 0.5;
    ELSE
      v_production_mult := 1.0;
    END IF;

    v_island_mult := 1.0 + (c.island_resource_level * 0.10);

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
                       r.current_amount + (r.workers * r.prod_level * 5.0 * v_production_mult * v_island_mult),
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
