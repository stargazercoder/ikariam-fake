// Edge Function: downgrade-building
//
// Reduces a building's level by 1 and refunds 50% of the upgrade cost.
// Downgrade is instant — no construction queue entry is created.
//
// Decision: Downgrade is always available (no queue check) and refunds 50%
// of the cost to upgrade from (currentLevel-1) to currentLevel.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { BASE_COSTS, calcUpgradeCost } from '../_shared/formulas.ts';

// CORS headers for browser requests
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const VALID_BUILDING_TYPES = new Set(Object.keys(BASE_COSTS));

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
  let body: { city_id?: string; building_type?: string };
  try {
    body = await req.json();
  } catch {
    return errorResponse('Invalid JSON body', 400);
  }

  const { city_id, building_type } = body;

  if (!city_id || typeof city_id !== 'string') {
    return errorResponse('city_id is required', 400);
  }
  if (!building_type || typeof building_type !== 'string') {
    return errorResponse('building_type is required', 400);
  }

  // 2. Validate building_type
  if (!VALID_BUILDING_TYPES.has(building_type)) {
    return errorResponse(`Invalid building_type: ${building_type}`, 400);
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

  // 5. Service role admin client for mutations (bypasses RLS — INFR-02)
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
    return errorResponse('City not found or not owned by you', 403);
  }

  // 6. Get current building level
  const { data: buildingRow, error: buildingError } = await admin
    .from('city_buildings')
    .select('level')
    .eq('city_id', city_id)
    .eq('building_type', building_type)
    .maybeSingle();

  if (buildingError) {
    return errorResponse('Database error fetching building level', 500);
  }

  const currentLevel: number = buildingRow?.level ?? 0;

  // 7. Validate level > 1 — cannot downgrade below level 1
  if (currentLevel <= 1) {
    return errorResponse('Cannot downgrade below level 1', 400);
  }

  // 8. Calculate 50% refund: cost to go from (currentLevel-1) to currentLevel,
  //    then refund floor(amount * 0.5) of each resource.
  const fullCost = calcUpgradeCost(building_type, currentLevel - 1);
  const refund: Record<string, number> = {};
  for (const [resourceType, amount] of Object.entries(fullCost)) {
    refund[resourceType] = Math.floor(amount * 0.5);
  }

  // 9. Decrement building level
  const { error: updateError } = await admin
    .from('city_buildings')
    .update({ level: currentLevel - 1 })
    .eq('city_id', city_id)
    .eq('building_type', building_type);

  if (updateError) {
    return errorResponse('Failed to downgrade building', 500);
  }

  // 10. Credit refund resources (negative p_amount adds resources)
  for (const [resourceType, refundAmount] of Object.entries(refund)) {
    if (refundAmount > 0) {
      const { error: refundError } = await admin.rpc('deduct_resource', {
        p_city_id: city_id,
        p_resource_type: resourceType,
        p_amount: -refundAmount,
      });

      if (refundError) {
        // Non-fatal: building was already downgraded, log the error but continue.
        console.error(`Failed to refund ${resourceType}: ${refundError.message}`);
      }
    }
  }

  // 11. Return success
  return successResponse({
    success: true,
    new_level: currentLevel - 1,
    refund,
  });
});
