// Edge Function: dispatch-units
//
// The ONLY client-facing mutation for dispatching army units to another city.
// Validates city ownership, unit availability, deducts units from origin city,
// and inserts a unit_movements entry with calculated travel time.
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

// Base travel speed: 1 grid unit = 10 seconds (fast testing mode).
// NOTE: Must stay in sync with baseSecondsPerGridUnit in lib/core/constants/unit_constants.dart
const BASE_SECONDS_PER_GRID_UNIT = 10;

// Base travel speed in minutes: 1 grid unit = 2 minutes.
// NOTE: Must stay in sync with baseMinutesPerGridUnit in lib/core/constants/unit_constants.dart
const BASE_MINUTES_PER_GRID_UNIT = 2;

// Dev acceleration: 1/5 travel time when not in production (Phase 13 DEVT-03)
const APP_ENV = Deno.env.get('APP_ENVIRONMENT') ?? 'development';
const IS_PRODUCTION = APP_ENV === 'production';
const DEV_SPEED_MULTIPLIER = IS_PRODUCTION ? 1.0 : 0.2;

/**
 * Calculates travel time in minutes between two island grid positions.
 * Formula: max(1, ceil(sqrt(dx^2 + dy^2) * baseMinutesPerUnit))
 * Same-island dispatch (distance = 0) always returns minimum 1 minute.
 * NOTE: Must stay in sync with calcTravelMinutes in lib/core/constants/unit_constants.dart
 */
function calcTravelMinutes(
  originIsland: { grid_x: number; grid_y: number },
  destIsland: { grid_x: number; grid_y: number },
  baseMinutesPerUnit = BASE_MINUTES_PER_GRID_UNIT,
): number {
  const dx = destIsland.grid_x - originIsland.grid_x;
  const dy = destIsland.grid_y - originIsland.grid_y;
  const distance = Math.sqrt(dx * dx + dy * dy);
  return Math.max(1, Math.ceil(distance * baseMinutesPerUnit));
}

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
  let body: {
    origin_city_id?: string;
    destination_city_id?: string;
    units?: Record<string, number>;
  };
  try {
    body = await req.json();
  } catch {
    return errorResponse('Invalid JSON body', 400);
  }

  const { origin_city_id, destination_city_id, units } = body;

  if (!origin_city_id || typeof origin_city_id !== 'string') {
    return errorResponse('origin_city_id is required', 400);
  }
  if (!destination_city_id || typeof destination_city_id !== 'string') {
    return errorResponse('destination_city_id is required', 400);
  }
  if (origin_city_id === destination_city_id) {
    return errorResponse('Cannot dispatch to same city', 400);
  }
  if (!units || typeof units !== 'object' || Array.isArray(units)) {
    return errorResponse('units must be a non-empty object', 400);
  }

  const unitEntries = Object.entries(units);
  if (unitEntries.length === 0) {
    return errorResponse('units must be a non-empty object', 400);
  }
  for (const [unitType, qty] of unitEntries) {
    if (typeof qty !== 'number' || !Number.isInteger(qty) || qty <= 0) {
      return errorResponse(`Invalid quantity for ${unitType}: must be a positive integer`, 400);
    }
  }

  // 2. Authenticate the caller via anon key client
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

  // 3. Verify caller owns the origin city
  const { data: originCity, error: originError } = await admin
    .from('cities')
    .select('id, island_id')
    .eq('id', origin_city_id)
    .eq('owner_id', user.id)
    .maybeSingle();

  if (originError) {
    return errorResponse('Database error checking origin city ownership', 500);
  }
  if (!originCity) {
    return errorResponse('Origin city not found or not owned by you', 404);
  }

  // 4. Verify destination city exists
  const { data: destCity, error: destError } = await admin
    .from('cities')
    .select('id, island_id')
    .eq('id', destination_city_id)
    .maybeSingle();

  if (destError) {
    return errorResponse('Database error checking destination city', 500);
  }
  if (!destCity) {
    return errorResponse('Destination city not found', 404);
  }

  // 5. Fetch island coordinates for origin city
  const { data: originIsland, error: originIslandError } = await admin
    .from('islands')
    .select('grid_x, grid_y')
    .eq('id', originCity.island_id)
    .single();

  if (originIslandError || !originIsland) {
    return errorResponse('Database error fetching origin island coordinates', 500);
  }

  // 6. Fetch island coordinates for destination city
  const { data: destIsland, error: destIslandError } = await admin
    .from('islands')
    .select('grid_x, grid_y')
    .eq('id', destCity.island_id)
    .single();

  if (destIslandError || !destIsland) {
    return errorResponse('Database error fetching destination island coordinates', 500);
  }

  // 7. Calculate travel time (1/5 in dev mode, minimum 1 minute floor)
  const rawTravelMinutes = calcTravelMinutes(originIsland, destIsland);
  if (!Number.isFinite(rawTravelMinutes) || rawTravelMinutes <= 0) {
    return errorResponse('Failed to calculate travel time', 500);
  }
  const travelMinutes = Math.max(1, Math.ceil(rawTravelMinutes * DEV_SPEED_MULTIPLIER));

  // 8. Deduct units from origin city (validate + deduct last, right before insert)
  // Note: Non-atomic deduction — acceptable for v1 per project decision.
  // If insert fails after deduction, units are lost. Minimized by validating first.
  for (const [unitType, qty] of unitEntries) {
    const { error: deductError } = await admin.rpc('deduct_units', {
      p_city_id: origin_city_id,
      p_unit_type: unitType,
      p_quantity: qty,
    });

    if (deductError) {
      return errorResponse(`Insufficient ${unitType}`, 400);
    }
  }

  // 9. Calculate arrive_at
  const now = Date.now();
  const arriveAt = new Date(now + travelMinutes * 60 * 1000).toISOString();
  const departAt = new Date(now).toISOString();

  // 10. Insert into unit_movements
  const { error: insertError } = await admin
    .from('unit_movements')
    .insert({
      origin_city_id,
      destination_city_id,
      owner_id: user.id,
      units,
      depart_at: departAt,
      arrive_at: arriveAt,
    });

  if (insertError) {
    return errorResponse('Failed to create unit movement', 500);
  }

  // 11. Return success
  return successResponse({
    success: true,
    arrive_at: arriveAt,
    travel_minutes: travelMinutes,
  });
});
