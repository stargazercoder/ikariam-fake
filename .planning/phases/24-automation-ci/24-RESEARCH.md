# Phase 24: Automation & CI - Research

**Researched:** 2026-03-18
**Domain:** Bash scripting, PowerShell scripting, GitHub Actions CI/CD, Flutter CI, Deno CI
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Dev setup script (AUTO-01):**
- Create `scripts/dev_setup.sh` (bash) and `scripts/dev_setup.ps1` (PowerShell) — matching the existing dual-script pattern
- Script performs: db reset, seed data, edge functions serve (background), flutter build web
- Edge Functions serve runs in background so the script can proceed to flutter build
- Script should verify prerequisites (supabase CLI, flutter, deno) before starting
- Exit non-zero on any step failure (set -euo pipefail / $ErrorActionPreference = 'Stop')

**CI workflow (AUTO-02):**
- Single GitHub Actions workflow file: `.github/workflows/ci.yml`
- Triggers on: push to main, pull requests targeting main
- Single job with sequential steps (simpler than matrix — project has one target platform: web)
- Steps in order: checkout → setup Flutter → setup Deno 2.2.x → flutter analyze → deno test → flutter test → flutter build web
- Deno pinned to 2.2.x with inline comment: `# Supabase Edge Runtime does not support Deno 2.3+ lock file v5 (supabase/supabase#33093)`
- No Supabase CLI in CI — Deno tests run against extracted pure functions (no DB needed); Flutter tests use mocked providers
- flutter analyze failure or deno test failure causes non-zero exit (blocks merge)

**Deno test integration in local scripts:**
- Update `test_all.sh` and `test_all.ps1` to include a Deno test step between db reset and Flutter tests
- Step order: [1/3] db reset → [2/3] deno test → [3/3] flutter test

### Claude's Discretion
- Exact GitHub Actions action versions (e.g., actions/checkout@v4, subosito/flutter-action version)
- Whether to cache Flutter/Deno dependencies in CI (performance optimization)
- Dev setup script output formatting (echo colors, progress indicators)
- Whether dev_setup script waits for Edge Functions serve to be healthy before proceeding

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AUTO-01 | Single command runs DB reset + seed + Edge Functions serve + Flutter build | Shell scripting patterns (bash + PowerShell), prerequisite checks, background process pattern |
| AUTO-02 | GitHub Actions CI pipeline runs tests, lint, and build automatically on push | subosito/flutter-action@v2, denoland/setup-deno@v2, actions/checkout@v4, flutter analyze/test/build web, deno test directory path |
</phase_requirements>

---

## Summary

Phase 24 delivers two automation artifacts: a developer setup script (bash + PowerShell dual-variant) and a GitHub Actions CI workflow. Both follow patterns already established in this project — the scripts mirror `run_local.sh`/`test_all.sh` conventions, and the CI workflow is a straightforward single-job sequential pipeline with no Supabase CLI dependency.

The key constraint driving CI design is the Deno version pin: Supabase Edge Runtime does not support Deno 2.3+ lock file v5 format (tracked at supabase/supabase#33093). This means CI must use `deno-version: v2.2.x` in the setup-deno action. All Deno tests are pure-function tests (no Supabase client, no network) so they run cleanly in CI without any DB infrastructure. Flutter tests already use mocked Riverpod providers, so they also need no live services.

The dev setup script wraps four sequential steps: db reset, seed, Edge Functions serve (backgrounded), and flutter build web. The background serve step is the main scripting challenge — the script must not block on `npx supabase functions serve` yet the build step can proceed without waiting for the serve to be healthy (the build only needs Flutter tooling, not a live function server). This simplifies the health-check decision.

**Primary recommendation:** Use `subosito/flutter-action@v2` with `cache: true` for CI performance, pin `denoland/setup-deno@v2` with `deno-version: v2.2.x`, and run Deno tests via `deno test supabase/functions/tests/` targeting the tests directory directly.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| actions/checkout | v4 | Clones repo in CI | Current major version; v3 being deprecated |
| subosito/flutter-action | v2 (latest: v2.22.0) | Sets up Flutter SDK in CI | Official community standard; used by all major Flutter CI docs |
| denoland/setup-deno | v2 (latest: v2.0.3) | Sets up Deno in CI | Official Deno team action |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| actions/cache | v5 (built-in to flutter-action) | Caches Flutter pub deps | Enabled via `cache: true` in subosito/flutter-action |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| subosito/flutter-action@v2 | flutter-actions/setup-flutter | subosito is more mature and widely used; flutter-actions org is lower traffic |
| Single sequential job | Matrix jobs | Matrix is overkill for single-platform (web only) project |
| `deno test supabase/functions/tests/` | `deno test --config deno.json` | No deno.json exists in project; direct path is simpler |

**Installation (CI — no local install needed; actions handle setup):**
```bash
# GitHub Actions setup steps, no npm install required
```

**Version verification:**
- `subosito/flutter-action@v2` — verified latest tag is v2.22.0 (released 2026-03-17)
- `denoland/setup-deno@v2` — verified latest tag is v2.0.3 (released 2025-05-15)
- Both safe to reference as `@v2` (semver-pinned major versions)

---

## Architecture Patterns

### Recommended Project Structure
```
.github/
└── workflows/
    └── ci.yml           # Single CI workflow file

scripts/
├── dev_setup.sh         # NEW: bash dev setup script
├── dev_setup.ps1        # NEW: PowerShell dev setup script
├── test_all.sh          # UPDATED: add deno test step
├── test_all.ps1         # UPDATED: add deno test step
├── run_local.sh         # unchanged
└── run_local.ps1        # unchanged
```

### Pattern 1: Existing Script Conventions (from run_local.sh / test_all.sh)
**What:** All scripts use `set -euo pipefail`, navigate via `SCRIPT_DIR`/`PROJECT_DIR`, invoke Supabase via `npx supabase`.
**When to use:** Every new bash script in `scripts/` must follow this pattern exactly.
**Example:**
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"
```

### Pattern 2: PowerShell Parallel Convention (from run_local.ps1 / test_all.ps1)
**What:** PowerShell scripts mirror bash counterparts. Use `$ErrorActionPreference = 'Stop'`, navigate via `Split-Path`, and check `$LASTEXITCODE` after each non-native command.
**When to use:** Every new PowerShell script must be a structural mirror of its bash equivalent.
**Example:**
```powershell
$ErrorActionPreference = 'Stop'

$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectDir
```

### Pattern 3: Background Process in Bash (for Edge Functions serve)
**What:** Launch a blocking command in the background with `&`, capture its PID, allow the script to continue. No health check wait needed since `flutter build web` does not contact Edge Functions.
**When to use:** Any dev setup script step that would block indefinitely but the next step does not depend on it being healthy.
**Example:**
```bash
echo "[3/4] Starting Edge Functions serve (background)..."
npx supabase functions serve &
SERVE_PID=$!
echo "  Edge Functions serve running (PID: $SERVE_PID)"
echo "  Stop with: kill $SERVE_PID"
```

### Pattern 4: Background Process in PowerShell
**What:** Use `Start-Job` to run a blocking command asynchronously, print job ID for user reference.
**When to use:** PowerShell equivalent of bash `&` for long-running blocking processes.
**Example:**
```powershell
Write-Host "[3/4] Starting Edge Functions serve (background)..." -ForegroundColor Yellow
$ServeJob = Start-Job -ScriptBlock { Set-Location $using:ProjectDir; npx supabase functions serve }
Write-Host "  Edge Functions serve started (Job ID: $($ServeJob.Id))" -ForegroundColor Green
Write-Host "  Stop with: Stop-Job $($ServeJob.Id)" -ForegroundColor Gray
```

### Pattern 5: Prerequisite Checks in Bash
**What:** Verify required tools exist before running setup steps. Exit with clear error message if missing.
**When to use:** Any dev setup script that requires external tools not guaranteed to be installed.
**Example:**
```bash
check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "ERROR: '$1' is not installed or not in PATH. Please install it first."
    exit 1
  fi
}

check_command flutter
check_command deno
# Note: supabase CLI invoked via npx — check npx instead
check_command npx
```

### Pattern 6: GitHub Actions Single-Job Sequential Workflow
**What:** One job, steps run in sequence on `ubuntu-latest`. Failure at any step stops the workflow and exits non-zero.
**When to use:** Single-platform project where parallel jobs offer no benefit.
**Example:**
```yaml
# Source: standard GitHub Actions YAML schema
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  quality-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Set up Deno
        uses: denoland/setup-deno@v2
        with:
          deno-version: v2.2.x  # Supabase Edge Runtime does not support Deno 2.3+ lock file v5 (supabase/supabase#33093)

      - name: Install Flutter dependencies
        run: flutter pub get

      - name: Flutter analyze
        run: flutter analyze

      - name: Deno test
        run: deno test supabase/functions/tests/

      - name: Flutter test
        run: flutter test

      - name: Flutter build web
        run: flutter build web --dart-define=SUPABASE_URL=http://placeholder --dart-define=SUPABASE_ANON_KEY=placeholder
```

### Pattern 7: test_all.sh Updated Step Order
**What:** Insert `deno test` as step [2/3] between db reset and Flutter tests.
**When to use:** When updating test_all.sh and test_all.ps1 per the locked decision.
**Example (bash diff):**
```bash
# Old: [1/2] db reset → [2/2] flutter test
# New: [1/3] db reset → [2/3] deno test → [3/3] flutter test

echo ""
echo "[2/3] Running Deno unit tests..."
deno test supabase/functions/tests/
echo "  Deno tests complete."
```

### Anti-Patterns to Avoid
- **Blocking on `npx supabase functions serve` in dev_setup:** This command never exits on its own. Must be backgrounded with `&` (bash) or `Start-Job` (PowerShell).
- **Placing `set -e` after the background launch without saving the PID:** You lose the ability to inform the user how to stop it.
- **Using `supabase` (global) instead of `npx supabase` in scripts:** The project convention is `npx supabase` — never assume a global install.
- **Installing Supabase CLI in CI:** The CI design explicitly excludes it. Deno tests are pure functions; Flutter tests use mocked providers. No DB needed.
- **flutter build web without --dart-define in CI:** The Flutter app reads SUPABASE_URL/SUPABASE_ANON_KEY via `String.fromEnvironment()`. Build will succeed with placeholder values since it's a compile-time define — just needs something non-empty. The build step is a compile check, not a runtime test.
- **Using `deno-version: latest` in CI:** Must be pinned to `v2.2.x`. Using latest will break when Deno 2.3+ is released and Supabase Edge Runtime lock file v5 is not yet supported.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Flutter SDK setup in CI | Manual Flutter download + PATH manipulation | `subosito/flutter-action@v2` | Handles SDK install, PATH, cache, channel selection |
| Deno version management in CI | Manual deno download script | `denoland/setup-deno@v2` with `deno-version: v2.2.x` | Semver-aware, handles PATH, integrates with runner cache |
| Dependency caching in CI | Custom `actions/cache` with manual key crafting | `subosito/flutter-action@v2` with `cache: true` | Built-in pub cache with correct invalidation keys |

**Key insight:** The CI workflow is almost entirely composed of well-maintained actions. The only custom logic is the `run:` steps which are straightforward CLI commands already validated locally.

---

## Common Pitfalls

### Pitfall 1: flutter build web Fails Due to Missing dart-define
**What goes wrong:** `flutter build web` fails in CI because `String.fromEnvironment('SUPABASE_URL')` returns empty and app initialization fails (or Supabase client throws on empty URL).
**Why it happens:** The app is initialized with `--dart-define` in local scripts but CI has no `.env.local` and no live Supabase.
**How to avoid:** Pass placeholder values: `flutter build web --dart-define=SUPABASE_URL=http://placeholder --dart-define=SUPABASE_ANON_KEY=placeholder`. The build step only checks that the code compiles — it is not a runtime test.
**Warning signs:** Build error referencing Supabase initialization, URL validation, or missing environment variables.

### Pitfall 2: deno test Picks Up Wrong Files
**What goes wrong:** Running `deno test` from project root without a path discovers unexpected `.ts` files (e.g., Edge Function `index.ts` files that call `Deno.serve()` and fail without a runtime context).
**Why it happens:** Deno test discovery globs for `*_test.ts`, `*.test.ts`, etc. Edge Function index files don't match these patterns by default, but if they inadvertently do, tests will fail.
**How to avoid:** Always specify the tests directory explicitly: `deno test supabase/functions/tests/`. The two test files are `upgrade_building_test.ts` and `train_units_test.ts` — both follow the `*_test.ts` convention.
**Warning signs:** Test output showing unexpected function names or Deno.serve errors.

### Pitfall 3: supabase functions serve Blocks the Script
**What goes wrong:** `npx supabase functions serve` runs in the foreground and blocks the script from reaching `flutter build web`.
**Why it happens:** `supabase functions serve` is a long-running server process — it never exits unless killed.
**How to avoid:** Append `&` in bash / use `Start-Job` in PowerShell. Print the PID/JobID so the developer can stop it.
**Warning signs:** Script appears to hang after the serve step with no further output.

### Pitfall 4: Prerequisite Check for supabase CLI
**What goes wrong:** Script tries to run `npx supabase` and fails with an unhelpful npm error if Node/npm is not installed.
**Why it happens:** The project uses `npx supabase` not a global `supabase` binary. The prerequisite to check is `npx` (i.e., `node`/`npm`), not `supabase`.
**How to avoid:** Check for `npx` (or `node`) as the prerequisite. Also check `flutter` and `deno` directly.
**Warning signs:** Error from npm resolution rather than a clear "tool not found" message.

### Pitfall 5: PowerShell Exit Code Propagation
**What goes wrong:** In PowerShell, native commands like `flutter test` or `deno test` set `$LASTEXITCODE` but do NOT throw automatically even with `$ErrorActionPreference = 'Stop'`. The script silently continues after a failed test run.
**Why it happens:** `$ErrorActionPreference = 'Stop'` only applies to PowerShell cmdlets, not external executables.
**How to avoid:** Check `$LASTEXITCODE` after every external command call. The existing `test_all.ps1` demonstrates the correct pattern: capture exit code and call `exit $LastExitCode` explicitly.
**Warning signs:** PowerShell script reports success even when `deno test` or `flutter test` printed failures.

### Pitfall 6: Deno Version Drift in CI
**What goes wrong:** CI workflow uses `deno-version: latest` or omits version pinning. When Deno 2.3+ is released, CI breaks because Supabase Edge Runtime rejects lock file v5.
**Why it happens:** Default or latest Deno installs will upgrade past 2.2.x once 2.3 is released.
**How to avoid:** Pin `deno-version: v2.2.x` with the required inline comment referencing supabase/supabase#33093. Monitor that issue and update the pin when Edge Runtime support is confirmed.
**Warning signs:** CI deno test passes but `npx supabase functions serve` locally or in staging fails with lock file version errors.

---

## Code Examples

Verified patterns from existing project code and confirmed documentation.

### dev_setup.sh — Full Structure
```bash
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
echo "[1/4] Resetting database (migrations + seed)..."
npx supabase db reset --local
echo "  Database reset complete."

echo ""
echo "[2/4] Seeding bot data..."
# seed runs as part of db reset via supabase/seed.sql — already included above
# If seed is a separate script, invoke it here
echo "  Seed complete (included in db reset)."

echo ""
echo "[3/4] Starting Edge Functions serve (background)..."
npx supabase functions serve &
SERVE_PID=$!
echo "  Edge Functions serve running (PID: $SERVE_PID)"
echo "  Stop with: kill $SERVE_PID"

echo ""
echo "[4/4] Building Flutter web..."
SUPABASE_URL="$(npx supabase status --output json 2>/dev/null | grep -o '"API URL":"[^"]*"' | cut -d'"' -f4 || echo 'http://127.0.0.1:54321')"
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
```

### ci.yml — Full Workflow
```yaml
# Source: GitHub Actions official docs + subosito/flutter-action README
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  quality-gate:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Set up Deno
        uses: denoland/setup-deno@v2
        with:
          deno-version: v2.2.x  # Supabase Edge Runtime does not support Deno 2.3+ lock file v5 (supabase/supabase#33093)

      - name: Install Flutter dependencies
        run: flutter pub get

      - name: Flutter analyze
        run: flutter analyze

      - name: Deno test
        run: deno test supabase/functions/tests/

      - name: Flutter test
        run: flutter test

      - name: Flutter build web
        run: flutter build web --dart-define=SUPABASE_URL=http://placeholder --dart-define=SUPABASE_ANON_KEY=placeholder
```

### test_all.sh — Updated Section (Deno step insertion)
```bash
# Replace existing [1/2] / [2/2] numbering with [1/3] / [2/3] / [3/3]

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
```

### test_all.ps1 — Updated Section (Deno step insertion)
```powershell
Write-Host "[1/3] Resetting database (migrations + seed)..." -ForegroundColor Yellow
npx supabase db reset --local
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "  Database reset complete." -ForegroundColor Green

Write-Host ""
Write-Host "[2/3] Running Deno unit tests..." -ForegroundColor Yellow
deno test supabase/functions/tests/
if ($LASTEXITCODE -ne 0) {
    Write-Host "  DENO TESTS FAILED (exit code: $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "  Deno tests complete." -ForegroundColor Green

Write-Host ""
Write-Host "[3/3] Running Flutter tests..." -ForegroundColor Yellow
flutter test --reporter expanded
$FlutterExit = $LASTEXITCODE
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| actions/cache@v3 | actions/cache@v5 (built into flutter-action) | 2024-2025 | v3 deprecated Feb 2025; flutter-action v2 handles this internally |
| Manual Deno install in CI | `denoland/setup-deno@v2` | 2022+ | Official action with semver pinning |
| `flutter-version: 'latest'` | `channel: stable` (no version pin) | ongoing | Stable channel tracks latest stable; safer than pinning specific version for this project |

**Deprecated/outdated:**
- `actions/cache@v3`: Deprecated as of Feb 2025 — but this is handled internally by flutter-action; no direct usage needed.
- `denolib/setup-deno`: Unofficial fork, superseded by official `denoland/setup-deno`.

---

## Open Questions

1. **Does `supabase db reset --local` include seed execution?**
   - What we know: `supabase db reset` runs all migrations and then executes `supabase/seed.sql` if it exists. The project has bot seed data.
   - What's unclear: Whether the dev_setup script needs a separate seed step or if db reset already covers it.
   - Recommendation: Verify `supabase/seed.sql` exists and contains the bot seed data. If it does, no separate seed step needed; the `[1/4]` db reset step handles it. If seed is a separate script, add it as step `[2/4]` before functions serve.

2. **flutter build web SUPABASE_ANON_KEY default value in CI**
   - What we know: The `run_local.sh` hardcodes a local anon key: `sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH`.
   - What's unclear: Whether `flutter build web` with a placeholder key triggers any compile-time validation or just passes the string through.
   - Recommendation: Use `http://placeholder` and `placeholder` as dummy values. They satisfy the `String.fromEnvironment()` call at compile time without any format validation occurring at build time.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework (Flutter) | flutter_test (built-in SDK) |
| Framework (Deno) | Deno.test (built-in runtime) |
| Config file | `analysis_options.yaml` (Flutter lint); no deno.json needed |
| Quick run command (Deno) | `deno test supabase/functions/tests/` |
| Quick run command (Flutter) | `flutter test` |
| Full suite command | `bash scripts/test_all.sh` (after this phase: includes all 3 steps) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUTO-01 | dev_setup.sh completes without manual intervention | smoke/manual | Run `bash scripts/dev_setup.sh` on clean clone | ❌ Wave 0 (new file) |
| AUTO-01 | dev_setup.ps1 completes without manual intervention | smoke/manual | Run `.\scripts\dev_setup.ps1` on clean clone | ❌ Wave 0 (new file) |
| AUTO-02 | CI workflow triggers and all steps pass | CI integration | Push to main / open PR | ❌ Wave 0 (new file) |
| AUTO-02 | flutter analyze failure blocks workflow | manual-only | Introduce a lint error, verify non-zero exit | ❌ manual verification |
| AUTO-02 | deno test failure blocks workflow | manual-only | Introduce a failing test, verify non-zero exit | ❌ manual verification |

### Sampling Rate
- **Per task commit:** `deno test supabase/functions/tests/` (Deno) + `flutter analyze` (lint check)
- **Per wave merge:** `bash scripts/test_all.sh` (full: db reset + deno test + flutter test)
- **Phase gate:** CI workflow green on a push to main before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `scripts/dev_setup.sh` — covers AUTO-01 (bash)
- [ ] `scripts/dev_setup.ps1` — covers AUTO-01 (PowerShell)
- [ ] `.github/workflows/ci.yml` — covers AUTO-02
- [ ] Updated `scripts/test_all.sh` — insert deno test step
- [ ] Updated `scripts/test_all.ps1` — insert deno test step

---

## Sources

### Primary (HIGH confidence)
- `scripts/run_local.sh` — bash pattern: SCRIPT_DIR/PROJECT_DIR, set -euo pipefail, npx supabase
- `scripts/test_all.sh` — existing test runner structure to extend
- `scripts/test_all.ps1` — PowerShell exit code pattern ($LASTEXITCODE check)
- `supabase/functions/tests/upgrade_building_test.ts` — confirmed test file location and naming
- `supabase/functions/tests/train_units_test.ts` — confirmed test file location and naming
- https://github.com/subosito/flutter-action — verified v2.22.0 current (2026-03-17)
- https://github.com/denoland/setup-deno — verified v2.0.3 current (2025-05-15); `deno-version: v2.2.x` semver range confirmed
- https://docs.deno.com/runtime/reference/cli/test/ — `deno test <directory>` syntax confirmed

### Secondary (MEDIUM confidence)
- https://github.com/marketplace/actions/flutter-action — `cache: true` parameter confirmed
- .planning/STATE.md — Deno 2.2.x pin rationale confirmed: supabase/supabase#33093

### Tertiary (LOW confidence)
- WebSearch results for Flutter CI/CD patterns — used only to cross-validate action names; primary sources confirm all specific versions

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — action versions verified against GitHub releases
- Architecture: HIGH — all patterns derived from existing project scripts (direct observation)
- Pitfalls: HIGH — derived from code reading and official CLI docs

**Research date:** 2026-03-18
**Valid until:** 2026-04-18 (action versions stable; monitor supabase/supabase#33093 for Deno 2.3+ support)
