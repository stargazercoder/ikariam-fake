#!/usr/bin/env bash
# Unified test automation: reset DB, seed data, run Deno and Flutter tests.
# Usage: bash scripts/test_all.sh
# Exit codes: 0 = all passed, non-zero = failure in any step.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "========================================="
echo "  Ikariam Test Suite"
echo "========================================="

echo ""
echo "[1/3] Resetting database (migrations + seed)..."
npx supabase db reset --local
echo "  Database reset complete."

echo ""
echo "[2/3] Running Deno unit tests..."
deno test supabase/functions/tests/
echo "  Deno tests complete."

echo ""
echo "[3/3] Running Flutter tests..."
set +e
flutter test --reporter expanded
FLUTTER_EXIT=$?
set -e

echo ""
echo "========================================="
if [ $FLUTTER_EXIT -eq 0 ]; then
  echo "  ALL TESTS PASSED"
else
  echo "  TESTS FAILED (exit code: $FLUTTER_EXIT)"
fi
echo "========================================="

exit $FLUTTER_EXIT
