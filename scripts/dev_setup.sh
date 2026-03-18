#!/usr/bin/env bash
# One-command dev environment setup: db reset, seed, Edge Functions serve, Flutter build.
# Usage: bash scripts/dev_setup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# --- Prerequisite checks ---
check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "ERROR: '$1' not found in PATH. Install it first."
    exit 1
  fi
}
check_command flutter
check_command deno
check_command npx

echo "========================================="
echo "  Ikariam Dev Setup"
echo "========================================="

echo ""
echo "[1/3] Resetting database (migrations + seed)..."
npx supabase db reset --local
echo "  Database reset complete."

echo ""
echo "[2/3] Starting Edge Functions serve (background)..."
npx supabase functions serve &
SERVE_PID=$!
echo "  Edge Functions serve running (PID: $SERVE_PID)"
echo "  Stop with: kill $SERVE_PID"

echo ""
echo "[3/3] Building Flutter web..."
# Load .env.local if it exists
if [ -f .env.local ]; then
  set -a
  source .env.local
  set +a
fi
SUPABASE_URL="${SUPABASE_URL:-http://127.0.0.1:54321}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH}"
flutter build web \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
echo "  Flutter web build complete."

echo ""
echo "========================================="
echo "  DEV SETUP COMPLETE"
echo "========================================="
echo "  Edge Functions serve PID: $SERVE_PID"
echo "  Run: kill $SERVE_PID  to stop serve"
echo "========================================="
