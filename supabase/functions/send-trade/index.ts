// Edge Function: send-trade
//
// The ONLY client-facing mutation for sending resources to another city.
// Validates city ownership, cargo validity, warehouse capacity, deducts
// resources from the origin city, and inserts a trade movement.
//
// Decision INFR-02: All game mutations go through Edge Functions — no Flutter
// client writes directly to game-state tables.
//
// Self-trade (origin == destination) is explicitly allowed.

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

// Only these resource types may be traded. Gold and wine are excluded.
const TRADEABLE_TYPES = ['wood', 'marble', 'crystal', 'sulfur'];

/**
 * Calculates travel time in minutes between two island grid positions.
 * Formula: max(1, ceil(sqrt(dx^2 + dy^2) * baseMinutesPerUnit))
 * Same-island trade (distance = 0) always returns minimum 1 minute.
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
    cargo?: Record<string, number>;
  };
  try {
    body = await req.json();
  } catch {
    return errorResponse('Invalid JSON body', 400);
  }

  const { origin_city_id, destination_city_id, cargo } = body;

  if (!origin_city_id || typeof origin_city_id !== 'string') {
    return errorResponse('origin_city_id is required', 400);
  }
  if (!destination_city_id || typeof destination_city_id !== 'string') {
    return errorResponse('destination_city_id is required', 400);
  }
  // NOTE: origin_city_id === destination_city_id is intentionally allowed (self-trade)
  if (!cargo || typeof cargo !== 'object' || Array.isArray(cargo)) {
    return errorResponse('cargo must be a non-empty object', 400);
  }

  const cargoEntries = Object.entries(cargo);
  if (cargoEntries.length === 0) {
    return errorResponse('cargo must be a non-empty object', 400);
  }
  for (const [resourceType, amount] of cargoEntries) {
    if (!TRADEABLE_TYPES.includes(resourceType)) {
      return errorResponse(`Resource type ${resourceType} is not tradeable`, 400);
    }
    if (typeof amount !== 'number' || !Number.isInteger(amount) || amount <= 0) {
      return errorResponse(
        `Invalid amount for ${resourceType}: must be a positive integer`,
        400,
      );
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

  // 5. Server-side resource balance check (double-check before deduction)
  for (const [resourceType, amount] of cargoEntries) {
    const { data: senderResource, error: balanceError } = await admin
      .from('city_resources')
      .select('amount')
      .eq('city_id', origin_city_id)
      .eq('resource_type', resourceType)
      .maybeSingle();

    if (balanceError) {
      return errorResponse(`Database error checking ${resourceType} balance`, 500);
    }

    const currentAmount = senderResource?.amount ?? 0;
    if (currentAmount < amount) {
      return errorResponse(`Insufficient ${resourceType}`, 400);
    }
  }

  // 6. Warehouse capacity check — ensure recipient can hold the incoming resources
  const { data: recipientWarehouse, error: warehouseError } = await admin
    .from('city_buildings')
    .select('level')
    .eq('city_id', destination_city_id)
    .eq('building_type', 'warehouse')
    .maybeSingle();

  if (warehouseError) {
    return errorResponse('Database error checking recipient warehouse', 500);
  }

  const warehouseLevel = recipientWarehouse?.level ?? 0;
  const capacity = 500 * Math.pow(1.5, warehouseLevel);

  for (const [resourceType, amount] of cargoEntries) {
    const { data: recipientResource, error: recipientResError } = await admin
      .from('city_resources')
      .select('amount')
      .eq('city_id', destination_city_id)
      .eq('resource_type', resourceType)
      .maybeSingle();

    if (recipientResError) {
      return errorResponse(`Database error checking recipient ${resourceType}`, 500);
    }

    const currentAmount = recipientResource?.amount ?? 0;
    if (currentAmount + amount > capacity) {
      return errorResponse(
        `Recipient warehouse would overflow for ${resourceType}`,
        400,
      );
    }
  }

  // 7. Fetch island coordinates for origin city
  const { data: originIsland, error: originIslandError } = await admin
    .from('islands')
    .select('grid_x, grid_y')
    .eq('id', originCity.island_id)
    .single();

  if (originIslandError || !originIsland) {
    return errorResponse('Database error fetching origin island coordinates', 500);
  }

  // 8. Fetch island coordinates for destination city
  const { data: destIsland, error: destIslandError } = await admin
    .from('islands')
    .select('grid_x, grid_y')
    .eq('id', destCity.island_id)
    .single();

  if (destIslandError || !destIsland) {
    return errorResponse('Database error fetching destination island coordinates', 500);
  }

  // 9. Calculate travel time (1/5 in dev mode, minimum 1 minute floor)
  const rawTravelMinutes = calcTravelMinutes(originIsland, destIsland);
  if (!Number.isFinite(rawTravelMinutes) || rawTravelMinutes <= 0) {
    return errorResponse('Failed to calculate travel time', 500);
  }
  const travelMinutes = Math.max(1, Math.ceil(rawTravelMinutes * DEV_SPEED_MULTIPLIER));

  // 10. Deduct resources from origin city (atomic via RPC — raises on insufficient balance)
  for (const [resourceType, amount] of cargoEntries) {
    const { error: deductError } = await admin.rpc('deduct_resources', {
      p_city_id: origin_city_id,
      p_resource_type: resourceType,
      p_amount: amount,
    });

    if (deductError) {
      return errorResponse(`Insufficient ${resourceType}`, 400);
    }
  }

  // 11. Calculate arrive_at and depart_at timestamps
  const now = Date.now();
  const arriveAt = new Date(now + travelMinutes * 60 * 1000).toISOString();
  const departAt = new Date(now).toISOString();

  // 12. Insert trade movement into unit_movements
  // units is empty — trade movements carry no army units
  const { error: insertError } = await admin
    .from('unit_movements')
    .insert({
      origin_city_id,
      destination_city_id,
      owner_id: user.id,
      units: {},
      depart_at: departAt,
      arrive_at: arriveAt,
      movement_type: 'trade',
      cargo,
    });

  if (insertError) {
    return errorResponse('Failed to create trade movement', 500);
  }

  // 13. Return success
  return successResponse({
    success: true,
    arrive_at: arriveAt,
    travel_minutes: travelMinutes,
  });
});
