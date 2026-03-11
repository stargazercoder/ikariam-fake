// Edge Function: train-units
//
// The ONLY client-facing mutation for training military units.
// Validates city ownership, building level, training queue vacancy,
// deducts resources, and inserts the training queue entry.
//
// Decision INFR-02: All game mutations go through Edge Functions — no Flutter
// client writes directly to game-state tables.

import { createClient } from 'jsr:@supabase/supabase-js@2';

// CORS headers for browser requests
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Unit type to required building and minimum building level.
// NOTE: Must stay in sync with lib/core/constants/unit_constants.dart unitUnlockLevels
const UNIT_UNLOCK_LEVELS: Record<string, { building: string; minLevel: number }> = {
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
const UNIT_BASE_COSTS: Record<string, Record<string, number>> = {
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
const UNIT_BASE_TIMES: Record<string, number> = {
  hoplite: 1, phalanx: 1, archer: 1, cavalry: 2,
  catapult: 2, mortar: 3, medic: 1, cook: 1,
  cargo_ship: 2, ram_ship: 3, catapult_ship: 4,
  mortar_ship: 5, diving_boat: 4,
};

const VALID_UNIT_TYPES = new Set(Object.keys(UNIT_UNLOCK_LEVELS));
const MAX_QUANTITY = 50;

/** Returns a JSON error response with the given status code. */
function errorResponse(message: string, status: number): Response {
  return new Response(
    JSON.stringify({ error: message }),
    {
      status,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    },
  );
}

/** Returns a JSON success response. */
function successResponse(body: Record<string, unknown>): Response {
  return new Response(
    JSON.stringify(body),
    {
      status: 200,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    },
  );
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  if (req.method !== 'POST') {
    return errorResponse('Method not allowed', 405);
  }

  // 1. Parse request body
  let body: { city_id?: string; unit_type?: string; quantity?: number };
  try {
    body = await req.json();
  } catch {
    return errorResponse('Invalid JSON body', 400);
  }

  const { city_id, unit_type, quantity } = body;

  if (!city_id || typeof city_id !== 'string') {
    return errorResponse('city_id is required', 400);
  }
  if (!unit_type || typeof unit_type !== 'string') {
    return errorResponse('unit_type is required', 400);
  }
  if (typeof quantity !== 'number' || !Number.isInteger(quantity)) {
    return errorResponse('quantity must be an integer', 400);
  }
  if (quantity <= 0) {
    return errorResponse('quantity must be greater than 0', 400);
  }
  if (quantity > MAX_QUANTITY) {
    return errorResponse(`quantity must be at most ${MAX_QUANTITY}`, 400);
  }

  // 2. Validate unit_type
  if (!VALID_UNIT_TYPES.has(unit_type)) {
    return errorResponse(`Invalid unit_type: ${unit_type}`, 400);
  }

  // 3. Authenticate the caller via anon key client
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return errorResponse('Authorization header required', 401);
  }

  // Anon client for auth verification (respects RLS)
  const anonClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: authError } = await anonClient.auth.getUser();
  if (authError || !user) {
    return errorResponse('Not authenticated', 401);
  }

  // Service role admin client for mutations (bypasses RLS — INFR-02)
  const admin = createClient(supabaseUrl, supabaseServiceKey, {
    auth: { persistSession: false },
  });

  // 4. Verify caller owns the city
  const { data: cityRow, error: cityError } = await admin
    .from('cities')
    .select('id')
    .eq('id', city_id)
    .eq('owner_id', user.id)
    .maybeSingle();

  if (cityError) {
    return errorResponse('Database error checking city ownership', 500);
  }
  if (!cityRow) {
    return errorResponse('City not found or not owned by you', 404);
  }

  // 5. Get required building and minimum level for this unit type
  const { building, minLevel } = UNIT_UNLOCK_LEVELS[unit_type];

  // 6. Fetch building level
  const { data: buildingRow, error: buildingError } = await admin
    .from('city_buildings')
    .select('level')
    .eq('city_id', city_id)
    .eq('building_type', building)
    .maybeSingle();

  if (buildingError) {
    return errorResponse('Database error fetching building level', 500);
  }
  if (!buildingRow) {
    return errorResponse(`${building} not found in city`, 404);
  }

  const currentLevel: number = buildingRow.level ?? 0;
  if (currentLevel < minLevel) {
    return errorResponse(`Requires ${building} level ${minLevel}`, 400);
  }

  // 7. Check training queue vacancy (UNIQUE(city_id) constraint — one training at a time)
  const { data: queueRow, error: queueCheckError } = await admin
    .from('training_queue')
    .select('id')
    .eq('city_id', city_id)
    .maybeSingle();

  if (queueCheckError) {
    return errorResponse('Database error checking training queue', 500);
  }
  if (queueRow) {
    return errorResponse('Training queue is busy', 409);
  }

  // 8. Calculate total cost and deduct resources
  const baseCosts = UNIT_BASE_COSTS[unit_type];
  for (const [resourceType, baseAmount] of Object.entries(baseCosts)) {
    const totalAmount = baseAmount * quantity;
    const { error: deductError } = await admin.rpc('deduct_resource', {
      p_city_id: city_id,
      p_resource_type: resourceType,
      p_amount: totalAmount,
    });

    if (deductError) {
      return errorResponse(`Insufficient ${resourceType}`, 400);
    }
  }

  // 9. Calculate finish_at: NOW() + base_time * quantity minutes
  const durationMinutes = UNIT_BASE_TIMES[unit_type] * quantity;
  const finishAt = new Date(Date.now() + durationMinutes * 60 * 1000).toISOString();

  // 10. Insert into training_queue
  const { error: insertError } = await admin
    .from('training_queue')
    .insert({
      city_id,
      unit_type,
      quantity,
      finish_at: finishAt,
    });

  if (insertError) {
    // Catch unique_violation (23505) from UNIQUE(city_id) constraint race condition
    if (insertError.code === '23505') {
      return errorResponse('Training queue is busy', 409);
    }
    return errorResponse('Failed to queue training', 500);
  }

  // 11. Return success
  return successResponse({
    success: true,
    finish_at: finishAt,
    unit_type,
    quantity,
  });
});
