// Edge Function: spy-city
//
// The ONLY client-facing mutation for espionage actions.
// Validates auth, checks gold balance, deducts 100 gold via RPC,
// queries target city resources/buildings/army, inserts a spy_report,
// and returns the report JSON to the caller.
//
// Decision INFR-02: All game mutations go through Edge Functions — no Flutter
// client writes directly to game-state tables.
//
// Espionage is instant (no spy unit type, no travel time) — ESPY-01 spec.

import { createClient } from 'jsr:@supabase/supabase-js@2';

// CORS headers for browser requests
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
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
  let body: { target_city_id?: string };
  try {
    body = await req.json();
  } catch {
    return errorResponse('Invalid JSON body', 400);
  }

  const { target_city_id } = body;

  if (!target_city_id || typeof target_city_id !== 'string') {
    return errorResponse('target_city_id is required', 400);
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

  // 3. Find caller's city
  const { data: playerCity, error: playerCityError } = await admin
    .from('cities')
    .select('id')
    .eq('owner_id', user.id)
    .limit(1)
    .maybeSingle();

  if (playerCityError) {
    return errorResponse('Database error finding player city', 500);
  }
  if (!playerCity) {
    return errorResponse('Player city not found', 404);
  }

  const playerCityId = playerCity.id as string;

  // 4. Verify target city exists and get owner info
  const { data: targetCity, error: targetCityError } = await admin
    .from('cities')
    .select('id, name, owner_id')
    .eq('id', target_city_id)
    .maybeSingle();

  if (targetCityError) {
    return errorResponse('Database error checking target city', 500);
  }
  if (!targetCity) {
    return errorResponse('Target city not found', 404);
  }

  // 5. Guard: cannot spy on own city
  if (targetCity.owner_id === user.id) {
    return errorResponse('You cannot spy on your own city', 400);
  }

  // 6. Check gold balance (must have at least 100 gold)
  const { data: goldResource, error: goldError } = await admin
    .from('city_resources')
    .select('amount')
    .eq('city_id', playerCityId)
    .eq('resource_type', 'gold')
    .maybeSingle();

  if (goldError) {
    return errorResponse('Database error checking gold balance', 500);
  }

  const goldAmount = (goldResource?.amount as number) ?? 0;
  if (goldAmount < 100) {
    return errorResponse('Not enough gold. You need 100 gold to spy.', 400);
  }

  // 7. Get target owner display_name
  const { data: ownerProfile, error: profileError } = await admin
    .from('profiles')
    .select('display_name')
    .eq('id', targetCity.owner_id)
    .maybeSingle();

  if (profileError) {
    return errorResponse('Database error fetching target owner profile', 500);
  }

  const ownerName = (ownerProfile?.display_name as string | null) ?? 'Unknown';

  // 8. Deduct 100 gold atomically via RPC (raises exception on insufficient balance)
  const { error: deductError } = await admin.rpc('deduct_resources', {
    p_city_id: playerCityId,
    p_resource_type: 'gold',
    p_amount: 100,
  });

  if (deductError) {
    return errorResponse('Not enough gold. You need 100 gold to spy.', 400);
  }

  // 9. Query target city resources
  const { data: resourceRows, error: resourcesError } = await admin
    .from('city_resources')
    .select('resource_type, amount')
    .eq('city_id', target_city_id);

  if (resourcesError) {
    return errorResponse('Database error reading target city resources', 500);
  }

  // Build resources object with all 5 types defaulting to 0
  const resources: Record<string, number> = {
    wood: 0,
    marble: 0,
    crystal: 0,
    sulfur: 0,
    gold: 0,
  };
  for (const row of (resourceRows ?? [])) {
    const rt = row.resource_type as string;
    if (rt in resources) {
      resources[rt] = Math.floor(row.amount as number);
    }
  }

  // 10. Query target city buildings
  const { data: buildingRows, error: buildingsError } = await admin
    .from('city_buildings')
    .select('building_type, level')
    .eq('city_id', target_city_id);

  if (buildingsError) {
    return errorResponse('Database error reading target city buildings', 500);
  }

  // Build buildings object
  const buildings: Record<string, number> = {};
  for (const row of (buildingRows ?? [])) {
    buildings[row.building_type as string] = row.level as number;
  }

  // 11. Query total army count
  const { data: armyRow, error: armyError } = await admin
    .from('city_units')
    .select('quantity.sum()')
    .eq('city_id', target_city_id)
    .maybeSingle();

  if (armyError) {
    return errorResponse('Database error reading target city army', 500);
  }

  const armyCount = (armyRow?.sum as number) ?? 0;

  // 12. Build report_data JSONB
  const reportData = {
    city_name: targetCity.name as string,
    owner_name: ownerName,
    resources,
    buildings,
    army_count: armyCount,
  };

  // 13. Insert spy_report using service_role (bypasses RLS)
  const { data: insertedReport, error: insertError } = await admin
    .from('spy_reports')
    .insert({
      player_id: user.id,
      target_city_id,
      report_data: reportData,
    })
    .select('id, target_city_id, report_data, created_at')
    .single();

  if (insertError || !insertedReport) {
    return errorResponse('Failed to save spy report', 500);
  }

  // 14. Return the report
  return successResponse({
    report: {
      id: insertedReport.id,
      target_city_id: insertedReport.target_city_id,
      report_data: insertedReport.report_data,
      created_at: insertedReport.created_at,
    },
  });
});
