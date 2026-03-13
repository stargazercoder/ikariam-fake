// Edge Function: set-wine-rate
//
// Updates a city's wine_spending_rate value (0-100 integer).
// Validates auth, city ownership, and rate range before updating.
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
  let body: { city_id?: unknown; wine_spending_rate?: unknown };
  try {
    body = await req.json();
  } catch {
    return errorResponse('Invalid JSON body', 400);
  }

  const { city_id, wine_spending_rate } = body;

  if (!city_id || typeof city_id !== 'string') {
    return errorResponse('city_id is required and must be a string', 400);
  }
  if (wine_spending_rate === undefined || wine_spending_rate === null || typeof wine_spending_rate !== 'number') {
    return errorResponse('wine_spending_rate is required and must be a number', 400);
  }

  // 2. Validate wine_spending_rate: must be integer between 0 and 100
  if (!Number.isInteger(wine_spending_rate)) {
    return errorResponse('wine_spending_rate must be an integer', 400);
  }
  if (wine_spending_rate < 0 || wine_spending_rate > 100) {
    return errorResponse('wine_spending_rate must be between 0 and 100', 400);
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

  // 4. Service role admin client for mutations (bypasses RLS — INFR-02)
  const admin = createClient(supabaseUrl, supabaseServiceKey, {
    auth: { persistSession: false },
  });

  // 5. Verify caller owns the city
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

  // 6. Update wine_spending_rate in cities table
  const { error: updateError } = await admin
    .from('cities')
    .update({ wine_spending_rate })
    .eq('id', city_id);

  if (updateError) {
    return errorResponse('Failed to update wine spending rate', 500);
  }

  // 7. Return success
  return successResponse({
    success: true,
    wine_spending_rate,
  });
});
