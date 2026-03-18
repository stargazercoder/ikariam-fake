// Unit tests for upgrade-building formula functions.
// Tests pure arithmetic only — no Supabase client, no Deno.serve, no Deno.env.

import { assertEquals } from 'jsr:@std/assert';
import {
  BASE_COSTS,
  calcUpgradeCost,
  calcUpgradeDurationMinutes,
} from '../_shared/formulas.ts';

// ---------------------------------------------------------------------------
// calcUpgradeCost tests
// ---------------------------------------------------------------------------

Deno.test('calcUpgradeCost: town_hall level 0 returns base cost', () => {
  const cost = calcUpgradeCost('town_hall', 0);
  assertEquals(cost['gold'], 100);
  assertEquals(cost['wood'], 200);
});

Deno.test('calcUpgradeCost: town_hall level 1 returns ceil(base * 1.5)', () => {
  const cost = calcUpgradeCost('town_hall', 1);
  assertEquals(cost['gold'], 150); // ceil(100 * 1.5) = 150
  assertEquals(cost['wood'], 300); // ceil(200 * 1.5) = 300
});

Deno.test('calcUpgradeCost: barracks level 5 returns costs greater than base', () => {
  const baseCost = calcUpgradeCost('barracks', 0);
  const level5Cost = calcUpgradeCost('barracks', 5);
  for (const [resource, baseAmount] of Object.entries(baseCost)) {
    assertEquals(
      level5Cost[resource] > baseAmount,
      true,
      `Expected ${resource} cost at level 5 to exceed base cost`,
    );
  }
});

Deno.test('calcUpgradeCost: every building type at level 0 returns non-empty resource object', () => {
  for (const buildingType of Object.keys(BASE_COSTS)) {
    const cost = calcUpgradeCost(buildingType, 0);
    assertEquals(
      Object.keys(cost).length > 0,
      true,
      `Expected non-empty cost for building type: ${buildingType}`,
    );
  }
});

// ---------------------------------------------------------------------------
// calcUpgradeDurationMinutes tests
// ---------------------------------------------------------------------------

Deno.test('calcUpgradeDurationMinutes: town_hall level 0 returns 1 (base time)', () => {
  const duration = calcUpgradeDurationMinutes('town_hall', 0);
  assertEquals(duration, 1);
});

Deno.test('calcUpgradeDurationMinutes: town_hall level 5 returns ceil(1 * 1.2^5) = 3', () => {
  // 1.2^5 = 2.48832 → ceil = 3
  const duration = calcUpgradeDurationMinutes('town_hall', 5);
  assertEquals(duration, 3);
});

Deno.test('calcUpgradeDurationMinutes: town_hall level 20 returns ceil(1 * 1.2^20) = 39', () => {
  // 1.2^20 ≈ 38.3375... → ceil = 39
  const duration = calcUpgradeDurationMinutes('town_hall', 20);
  assertEquals(duration, 39);
});
