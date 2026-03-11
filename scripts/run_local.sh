#!/usr/bin/env bash
# Start Supabase local dev and run Flutter with correct dart-defines.
# Usage: ./scripts/run_local.sh [flutter-run-args...]
# Examples:
#   ./scripts/run_local.sh                    # default: flutter run -d chrome
#   ./scripts/run_local.sh -d windows         # run on Windows desktop
#   ./scripts/run_local.sh -d emulator-5554   # run on Android emulator
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Load .env.local if it exists
if [ -f .env.local ]; then
  set -a
  source .env.local
  set +a
fi

# Fallback defaults (standard local Supabase values)
SUPABASE_URL="${SUPABASE_URL:-http://127.0.0.1:54321}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH}"

# Ensure Supabase is running
echo "Checking Supabase status..."
if ! npx supabase status > /dev/null 2>&1; then
  echo "Supabase not running. Starting..."
  npx supabase start
  echo "Waiting for services to be healthy..."
  sleep 5
else
  echo "Supabase is already running."
fi

# Default device: chrome (web)
DEVICE_ARGS="${@:--d chrome}"

echo ""
echo "Running Flutter with local Supabase:"
echo "  URL:  $SUPABASE_URL"
echo "  Key:  ${SUPABASE_ANON_KEY:0:20}..."
echo ""

flutter run \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  $DEVICE_ARGS
