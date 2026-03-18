// Pure formula functions and constants shared across Edge Functions.
// This module has NO side effects — no Deno.env, no Deno.serve, no createClient.
// All functions are pure arithmetic suitable for unit testing without a runtime.

// ---------------------------------------------------------------------------
// Building upgrade formulas
// ---------------------------------------------------------------------------

// Base resource costs for each building type at level 0.
// Formula: upgradeCost = ceil(base_cost[resource] * 1.5^currentLevel)
// NOTE: Must stay in sync with lib/core/constants/building_constants.dart buildingBaseCosts
export const BASE_COSTS: Record<string, Record<string, number>> = {
  town_hall:    { gold: 100, wood: 200 },
  warehouse:    { wood: 100, marble: 50 },
  barracks:     { wood: 150, gold: 100 },
  shipyard:     { wood: 200, marble: 100, gold: 150 },
  academy:      { wood: 100, crystal: 100, gold: 200 },
  embassy:      { wood: 80, marble: 80, gold: 100 },
  trading_port: { wood: 150, gold: 120 },
  town_wall:    { wood: 200, marble: 150 },
  hideout:      { wood: 100, gold: 80 },
  tavern:       { wood: 120, gold: 100 },
  sawmill:      { wood: 50, gold: 50 },
  quarry:       { wood: 80, marble: 30 },
  glassblower:  { wood: 80, crystal: 30 },
  sulfur_pit:   { wood: 80, sulfur: 30 },
};

// Base upgrade time in minutes for each building type at level 0.
// Formula: upgradeDurationMinutes = ceil(base_time * 1.2^currentLevel)
// NOTE: Must stay in sync with lib/core/constants/building_constants.dart buildingBaseTimes
// NOTE: Values reduced to 1/10 for faster testing.
export const BASE_TIMES: Record<string, number> = {
  town_hall:    1,
  warehouse:    1,
  barracks:     1,
  shipyard:     1,
  academy:      1,
  embassy:      1,
  trading_port: 1,
  town_wall:    1,
  hideout:      1,
  tavern:       1,
  sawmill:      1,
  quarry:       1,
  glassblower:  1,
  sulfur_pit:   1,
};

export const COST_GROWTH_FACTOR = 1.5;
export const TIME_GROWTH_FACTOR = 1.2;

/** Returns the upgrade cost for a building at the given current level. */
export function calcUpgradeCost(buildingType: string, currentLevel: number): Record<string, number> {
  const baseCost = BASE_COSTS[buildingType];
  const multiplier = Math.pow(COST_GROWTH_FACTOR, currentLevel);
  const result: Record<string, number> = {};
  for (const [resource, amount] of Object.entries(baseCost)) {
    result[resource] = Math.ceil(amount * multiplier);
  }
  return result;
}

/** Returns the upgrade duration in minutes for a building at the given current level. */
export function calcUpgradeDurationMinutes(buildingType: string, currentLevel: number): number {
  return Math.ceil(BASE_TIMES[buildingType] * Math.pow(TIME_GROWTH_FACTOR, currentLevel));
}

// ---------------------------------------------------------------------------
// Unit training formulas
// ---------------------------------------------------------------------------

// Unit type to required building and minimum building level.
// NOTE: Must stay in sync with lib/core/constants/unit_constants.dart unitUnlockLevels
export const UNIT_UNLOCK_LEVELS: Record<string, { building: string; minLevel: number }> = {
  // Land units (Barracks)
  hoplite:  { building: 'barracks', minLevel: 1 },
  phalanx:  { building: 'barracks', minLevel: 2 },
  archer:   { building: 'barracks', minLevel: 2 },
  cavalry:  { building: 'barracks', minLevel: 3 },
  catapult: { building: 'barracks', minLevel: 4 },
  mortar:   { building: 'barracks', minLevel: 5 },
  medic:    { building: 'barracks', minLevel: 3 },
  cook:     { building: 'barracks', minLevel: 1 },
  // Naval units (Shipyard)
  cargo_ship:    { building: 'shipyard', minLevel: 1 },
  ram_ship:      { building: 'shipyard', minLevel: 2 },
  catapult_ship: { building: 'shipyard', minLevel: 3 },
  mortar_ship:   { building: 'shipyard', minLevel: 4 },
  diving_boat:   { building: 'shipyard', minLevel: 3 },
};

// Base resource costs per unit (total cost = base_cost * quantity for each resource).
// NOTE: Must stay in sync with lib/core/constants/unit_constants.dart unitBaseCosts
export const UNIT_BASE_COSTS: Record<string, Record<string, number>> = {
  hoplite:       { wood: 40, gold: 30 },
  phalanx:       { wood: 60, marble: 20, gold: 50 },
  archer:        { wood: 50, crystal: 20, gold: 40 },
  cavalry:       { wood: 80, gold: 100 },
  catapult:      { wood: 120, sulfur: 30, gold: 80 },
  mortar:        { wood: 100, sulfur: 50, gold: 120 },
  medic:         { wood: 30, crystal: 30, gold: 60 },
  cook:          { wood: 20, gold: 20 },
  cargo_ship:    { wood: 200, gold: 100 },
  ram_ship:      { wood: 250, marble: 100, gold: 150 },
  catapult_ship: { wood: 300, sulfur: 50, gold: 200 },
  mortar_ship:   { wood: 350, sulfur: 80, gold: 250 },
  diving_boat:   { wood: 200, crystal: 80, gold: 180 },
};

// Base training time in minutes per unit (total time = base_time * quantity).
// NOTE: Must stay in sync with lib/core/constants/unit_constants.dart unitBaseTimes
export const UNIT_BASE_TIMES: Record<string, number> = {
  hoplite: 1, phalanx: 1, archer: 1, cavalry: 2,
  catapult: 2, mortar: 3, medic: 1, cook: 1,
  cargo_ship: 2, ram_ship: 3, catapult_ship: 4,
  mortar_ship: 5, diving_boat: 4,
};

/**
 * Returns the total training cost for training `quantity` of `unitType`.
 * Pure function — no Deno.env access.
 */
export function calcTrainingCost(unitType: string, quantity: number): Record<string, number> {
  const baseCosts = UNIT_BASE_COSTS[unitType];
  const result: Record<string, number> = {};
  for (const [resourceType, baseAmount] of Object.entries(baseCosts)) {
    result[resourceType] = baseAmount * quantity;
  }
  return result;
}

/**
 * Returns the training duration in minutes for `quantity` of `unitType`.
 * `devSpeedMultiplier` must be passed in (1.0 for production, 0.2 for dev).
 * Pure function — caller reads Deno.env and passes the value.
 */
export function calcTrainingDurationMinutes(
  unitType: string,
  quantity: number,
  devSpeedMultiplier: number,
): number {
  return UNIT_BASE_TIMES[unitType] * quantity * devSpeedMultiplier;
}
