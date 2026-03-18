// Unit tests for train-units formula functions.
// Tests pure arithmetic only — no Supabase client, no Deno.serve, no Deno.env.

import { assertEquals } from 'jsr:@std/assert';
import {
  UNIT_BASE_COSTS,
  calcTrainingCost,
  calcTrainingDurationMinutes,
} from '../_shared/formulas.ts';

// ---------------------------------------------------------------------------
// calcTrainingCost tests
// ---------------------------------------------------------------------------

Deno.test('calcTrainingCost: hoplite quantity 1 returns base cost', () => {
  const cost = calcTrainingCost('hoplite', 1);
  assertEquals(cost['wood'], 40);
  assertEquals(cost['gold'], 30);
});

Deno.test('calcTrainingCost: hoplite quantity 5 returns base cost * 5', () => {
  const cost = calcTrainingCost('hoplite', 5);
  assertEquals(cost['wood'], 200); // 40 * 5
  assertEquals(cost['gold'], 150); // 30 * 5
});

Deno.test('calcTrainingCost: every unit type at quantity 1 returns non-empty resource object', () => {
  for (const unitType of Object.keys(UNIT_BASE_COSTS)) {
    const cost = calcTrainingCost(unitType, 1);
    assertEquals(
      Object.keys(cost).length > 0,
      true,
      `Expected non-empty cost for unit type: ${unitType}`,
    );
  }
});

// ---------------------------------------------------------------------------
// calcTrainingDurationMinutes tests
// ---------------------------------------------------------------------------

Deno.test('calcTrainingDurationMinutes: hoplite quantity 1 multiplier 1.0 returns 1', () => {
  // hoplite base_time = 1; 1 * 1 * 1.0 = 1
  const duration = calcTrainingDurationMinutes('hoplite', 1, 1.0);
  assertEquals(duration, 1);
});

Deno.test('calcTrainingDurationMinutes: hoplite quantity 1 multiplier 0.2 returns 0.2', () => {
  // hoplite base_time = 1; 1 * 1 * 0.2 = 0.2
  const duration = calcTrainingDurationMinutes('hoplite', 1, 0.2);
  assertEquals(duration, 0.2);
});

Deno.test('calcTrainingDurationMinutes: hoplite quantity 10 multiplier 1.0 returns 10', () => {
  // hoplite base_time = 1; 1 * 10 * 1.0 = 10
  const duration = calcTrainingDurationMinutes('hoplite', 10, 1.0);
  assertEquals(duration, 10);
});

Deno.test('calcTrainingDurationMinutes: cavalry quantity 5 multiplier 0.2 returns 2', () => {
  // cavalry base_time = 2; 2 * 5 * 0.2 = 2
  const duration = calcTrainingDurationMinutes('cavalry', 5, 0.2);
  assertEquals(duration, 2);
});
