// Edge Function: upgrade-building
//
// The ONLY client-facing mutation for building upgrades.
// Validates ownership, checks resource sufficiency, enforces one-at-a-time queue,
// deducts resources, and inserts the construction queue entry.
//
// Decision INFR-02: All game mutations go through Edge Functions — no Flutter
// client writes directly to game-state tables.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import {
  BASE_COSTS,
  calcUpgradeCost,
  calcUpgradeDurationMinutes,
} from '../_shared/formulas.ts';

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

  // 6. Check no active construction queue entry
  const { data: queueRow, error: queueCheckError } = await admin
    .from('construction_queue')
    .select('id')
    .eq('city_id', city_id)
    .maybeSingle();

  if (queueCheckError) {
    return errorResponse('Database error checking construction queue', 500);
  }
  if (queueRow) {
    return errorResponse('Construction queue is busy', 409);
  }

  // 7. Get current building level (default 0 if no row)
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
  const targetLevel = currentLevel + 1;

  // 8. Calculate upgrade cost
  const upgradeCost = calcUpgradeCost(building_type, currentLevel);

  // 9. Deduct resources (one at a time — not atomic in v1, see plan note)
  for (const [resourceType, amount] of Object.entries(upgradeCost)) {
    const { error: deductError } = await admin.rpc('deduct_resource', {
      p_city_id: city_id,
      p_resource_type: resourceType,
      p_amount: amount,
    });

    if (deductError) {
      // deduct_resource raises SQLSTATE insufficient_resources on failure
      return errorResponse(`Insufficient ${resourceType}`, 400);
    }
  }

  // 10. Calculate finish_at
  const durationMinutes = calcUpgradeDurationMinutes(building_type, currentLevel);
  const finishAt = new Date(Date.now() + durationMinutes * 60 * 1000).toISOString();

  // 11. Insert into construction_queue
  const { error: insertError } = await admin
    .from('construction_queue')
    .insert({
      city_id,
      building_type,
      target_level: targetLevel,
      finish_at: finishAt,
    });

  if (insertError) {
    return errorResponse('Failed to queue construction', 500);
  }

  // 12. Return success
  return successResponse({
    success: true,
    finish_at: finishAt,
    duration_minutes: durationMinutes,
    target_level: targetLevel,
  });
});
