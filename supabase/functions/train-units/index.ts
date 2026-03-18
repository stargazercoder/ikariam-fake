// Edge Function: train-units
//
// The ONLY client-facing mutation for training military units.
// Validates city ownership, building level, training queue vacancy,
// deducts resources, and inserts the training queue entry.
//
// Decision INFR-02: All game mutations go through Edge Functions — no Flutter
// client writes directly to game-state tables.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import {
  UNIT_UNLOCK_LEVELS,
  calcTrainingCost,
  calcTrainingDurationMinutes,
} from '../_shared/formulas.ts';

// CORS headers for browser requests
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const VALID_UNIT_TYPES = new Set(Object.keys(UNIT_UNLOCK_LEVELS));
const MAX_QUANTITY = 50;

// Dev acceleration: 1/5 training time when not in production (Phase 13 DEVT-02)
const APP_ENV = Deno.env.get('APP_ENVIRONMENT') ?? 'development';
const IS_PRODUCTION = APP_ENV === 'production';
const DEV_SPEED_MULTIPLIER = IS_PRODUCTION ? 1.0 : 0.2;

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
  const totalCost = calcTrainingCost(unit_type, quantity);
  for (const [resourceType, totalAmount] of Object.entries(totalCost)) {
    const { error: deductError } = await admin.rpc('deduct_resource', {
      p_city_id: city_id,
      p_resource_type: resourceType,
      p_amount: totalAmount,
    });

    if (deductError) {
      return errorResponse(`Insufficient ${resourceType}`, 400);
    }
  }

  // 9. Calculate finish_at: NOW() + base_time * quantity minutes (1/5 in dev mode)
  const durationMinutes = calcTrainingDurationMinutes(unit_type, quantity, DEV_SPEED_MULTIPLIER);
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
