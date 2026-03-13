// Edge Function: donate-island-wood
//
// Allows a player to donate wood from one of their cities to upgrade the shared
// island resource level (0-10). Each level increases production multiplier by 10%
// for all cities on that island.
//
// Decision INFR-02: All game mutations go through Edge Functions — no Flutter
// client writes directly to game-state tables.
//
// Wood cost formula: Math.ceil(300 * 1.5^currentLevel)
// Level 0→1: 300 wood, Level 5→6: 2279 wood, Level 9→10: 11537 wood

import { createClient } from 'jsr:@supabase/supabase-js@2';

// CORS headers for browser requests
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Wood cost per level upgrade. Key = current level before upgrade.
// Formula: Math.ceil(300 * 1.5^currentLevel)
const DONATION_COSTS: Record<number, number> = {
  0: 300,
  1: 450,
  2: 675,
  3: 1013,
  4: 1519,
  5: 2279,
  6: 3418,
  7: 5128,
  8: 7691,
  9: 11537,
};

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
  let body: { city_id?: string };
  try {
    body = await req.json();
  } catch {
    return errorResponse('Invalid JSON body', 400);
  }

  const { city_id } = body;

  if (!city_id || typeof city_id !== 'string') {
    return errorResponse('city_id is required', 400);
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

  // 3. Service role admin client for mutations (bypasses RLS — INFR-02)
  const admin = createClient(supabaseUrl, supabaseServiceKey, {
    auth: { persistSession: false },
  });

  // 4. Verify caller owns the city and get island_id
  const { data: cityRow, error: cityError } = await admin
    .from('cities')
    .select('id, island_id')
    .eq('id', city_id)
    .eq('owner_id', user.id)
    .maybeSingle();

  if (cityError) {
    return errorResponse('Database error checking city ownership', 500);
  }
  if (!cityRow) {
    return errorResponse('City not found or not owned by you', 403);
  }

  const islandId: string = cityRow.island_id;

  // 5. Read current island resource_level
  const { data: islandRow, error: islandError } = await admin
    .from('islands')
    .select('resource_level')
    .eq('id', islandId)
    .single();

  if (islandError || !islandRow) {
    return errorResponse('Island not found', 400);
  }

  const currentLevel: number = islandRow.resource_level as number;

  // 6. Enforce max level 10
  if (currentLevel >= 10) {
    return errorResponse('Island is already at maximum level (10)', 409);
  }

  // 7. Compute wood cost for this level
  const woodCost: number = DONATION_COSTS[currentLevel];

  // 8. Deduct wood from the donating city
  const { error: deductError } = await admin.rpc('deduct_resource', {
    p_city_id: city_id,
    p_resource_type: 'wood',
    p_amount: woodCost,
  });

  if (deductError) {
    return errorResponse('Insufficient wood', 400);
  }

  // 9. Atomic conditional UPDATE: only increment if level hasn't changed since we read it
  //    This prevents race conditions where two players simultaneously upgrade the same island.
  const { data: updatedIsland, error: updateError } = await admin
    .from('islands')
    .update({ resource_level: currentLevel + 1 })
    .eq('id', islandId)
    .eq('resource_level', currentLevel)
    .select('resource_level')
    .single();

  if (updateError || !updatedIsland) {
    // Race condition: another player upgraded the island between our read and this update.
    // The wood has already been deducted — this is an edge case the design accepts for v1.
    return errorResponse('Island already upgraded by another player', 409);
  }

  // 10. Return success with new level and cost paid
  return successResponse({
    success: true,
    new_level: currentLevel + 1,
    wood_cost: woodCost,
  });
});
