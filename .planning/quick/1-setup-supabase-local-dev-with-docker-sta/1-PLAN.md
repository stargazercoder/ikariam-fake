---
phase: quick
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/run_local.sh
  - scripts/run_local.ps1
  - .env.local
  - .gitignore
autonomous: true
must_haves:
  truths:
    - "Flutter app can connect to local Supabase via dart-define env vars"
    - "All Supabase services are healthy and migrations applied"
    - "Developer has a single command to start Supabase + run Flutter with correct env"
  artifacts:
    - path: "scripts/run_local.sh"
      provides: "Bash helper script for local dev (start supabase + flutter run with dart-defines)"
    - path: "scripts/run_local.ps1"
      provides: "PowerShell helper script for local dev (Windows native)"
    - path: ".env.local"
      provides: "Local Supabase env vars for reference and tooling"
  key_links:
    - from: "scripts/run_local.sh"
      to: "lib/main.dart"
      via: "--dart-define passes SUPABASE_URL and SUPABASE_ANON_KEY"
      pattern: "dart-define.*SUPABASE_URL"
---

<objective>
Set up local development scripts so the Flutter app connects to the local Supabase instance.

Purpose: The Flutter app uses `String.fromEnvironment('SUPABASE_URL')` and `String.fromEnvironment('SUPABASE_ANON_KEY')` in main.dart. Developers need a simple way to start Supabase services and launch Flutter with the correct dart-define values pointing to the local instance.

Output: Helper scripts (bash + PowerShell), .env.local reference file, updated .gitignore
</objective>

<execution_context>
@C:/Users/Bilal/.claude/get-shit-done/workflows/execute-plan.md
@C:/Users/Bilal/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

Current state (verified during planning):
- Docker is running, all Supabase containers healthy (supabase_db_ikariam, supabase_auth_ikariam, etc.)
- Migrations applied: islands, profiles, cities tables exist
- Seed data: 100 islands present
- Supabase local URLs and keys:
  - API URL: http://127.0.0.1:54321
  - Publishable (anon) key: sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH
  - Secret (service_role) key: <REDACTED_LOCAL_SECRET>
  - DB URL: postgresql://postgres:postgres@127.0.0.1:54322/postgres
- main.dart reads: `String.fromEnvironment('SUPABASE_URL')` and `String.fromEnvironment('SUPABASE_ANON_KEY')`
- Supabase CLI available via `npx supabase` (v2.78.1)
- No .env files or scripts/ directory exist yet
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create .env.local and update .gitignore</name>
  <files>.env.local, .gitignore</files>
  <action>
1. Create `.env.local` with the local Supabase credentials:
   ```
   # Local Supabase Development Environment
   # These values are from `npx supabase status` and are NOT secrets —
   # they are deterministic local dev keys safe to commit.
   # However, .env.local is gitignored to allow per-developer overrides.

   SUPABASE_URL=http://127.0.0.1:54321
   SUPABASE_ANON_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH
   SUPABASE_SERVICE_ROLE_KEY=<REDACTED_LOCAL_SECRET>
   SUPABASE_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres
   ```

2. Append to `.gitignore` (do NOT overwrite, append after existing content):
   ```
   # Environment files
   .env
   .env.*
   !.env.example
   ```

Note: The local Supabase keys are deterministic (same for everyone running `supabase start`) so they are not true secrets. The .env.local file is gitignored to allow per-developer overrides (e.g., if someone uses different ports).
  </action>
  <verify>
    <automated>test -f .env.local && grep "SUPABASE_URL" .env.local && grep ".env" .gitignore</automated>
  </verify>
  <done>.env.local exists with all 4 Supabase vars, .gitignore includes .env.* pattern</done>
</task>

<task type="auto">
  <name>Task 2: Create local dev helper scripts</name>
  <files>scripts/run_local.sh, scripts/run_local.ps1</files>
  <action>
1. Create `scripts/` directory.

2. Create `scripts/run_local.sh` (Bash script for Git Bash / WSL / macOS / Linux):
   ```bash
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
   ```

3. Create `scripts/run_local.ps1` (PowerShell script for native Windows):
   ```powershell
   # Start Supabase local dev and run Flutter with correct dart-defines.
   # Usage: .\scripts\run_local.ps1 [flutter-run-args...]
   # Examples:
   #   .\scripts\run_local.ps1                    # default: flutter run -d chrome
   #   .\scripts\run_local.ps1 -d windows         # run on Windows desktop
   #   .\scripts\run_local.ps1 -d emulator-5554   # run on Android emulator
   param(
       [Parameter(ValueFromRemainingArguments = $true)]
       [string[]]$FlutterArgs
   )

   $ErrorActionPreference = "Stop"

   $ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
   Set-Location $ProjectDir

   # Load .env.local if it exists
   if (Test-Path ".env.local") {
       Get-Content ".env.local" | ForEach-Object {
           if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
               [System.Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), "Process")
           }
       }
   }

   # Fallback defaults (standard local Supabase values)
   $SupabaseUrl = if ($env:SUPABASE_URL) { $env:SUPABASE_URL } else { "http://127.0.0.1:54321" }
   $SupabaseAnonKey = if ($env:SUPABASE_ANON_KEY) { $env:SUPABASE_ANON_KEY } else { "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH" }

   # Ensure Supabase is running
   Write-Host "Checking Supabase status..."
   $statusResult = npx supabase status 2>&1
   if ($LASTEXITCODE -ne 0) {
       Write-Host "Supabase not running. Starting..."
       npx supabase start
       Write-Host "Waiting for services to be healthy..."
       Start-Sleep -Seconds 5
   } else {
       Write-Host "Supabase is already running."
   }

   # Default device: chrome (web)
   if (-not $FlutterArgs) {
       $FlutterArgs = @("-d", "chrome")
   }

   Write-Host ""
   Write-Host "Running Flutter with local Supabase:"
   Write-Host "  URL:  $SupabaseUrl"
   Write-Host "  Key:  $($SupabaseAnonKey.Substring(0, 20))..."
   Write-Host ""

   flutter run `
       --dart-define=SUPABASE_URL="$SupabaseUrl" `
       --dart-define=SUPABASE_ANON_KEY="$SupabaseAnonKey" `
       @FlutterArgs
   ```

4. Make the bash script executable: `chmod +x scripts/run_local.sh`
  </action>
  <verify>
    <automated>test -f scripts/run_local.sh && test -f scripts/run_local.ps1 && test -x scripts/run_local.sh && grep "dart-define" scripts/run_local.sh && grep "dart-define" scripts/run_local.ps1</automated>
  </verify>
  <done>Both scripts exist, bash script is executable, both pass SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define to flutter run</done>
</task>

<task type="auto">
  <name>Task 3: Verify full local dev stack health</name>
  <files></files>
  <action>
Run a comprehensive health check of the local development stack:

1. Verify Docker containers are running:
   ```
   docker ps --filter "name=supabase_" --format "{{.Names}} {{.Status}}" | grep -c "healthy\|Up"
   ```
   Expect: At least 10 containers (db, auth, rest, kong, storage, realtime, studio, inbucket, analytics, pg_meta)

2. Verify Supabase API is responding:
   ```
   curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:54321/rest/v1/ -H "apikey: sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"
   ```
   Expect: HTTP 200

3. Verify tables exist via REST API:
   ```
   curl -s http://127.0.0.1:54321/rest/v1/islands?select=count -H "apikey: sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH" -H "Authorization: Bearer sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH" -H "Prefer: count=exact" -I | grep -i "content-range"
   ```
   Expect: Content-Range header showing 100 islands

4. Verify auth endpoint is responsive:
   ```
   curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:54321/auth/v1/settings -H "apikey: sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"
   ```
   Expect: HTTP 200

5. Print a summary table of all verified services and their status.

If any check fails, report the specific failure but do NOT attempt to fix — the task is diagnostic only.
  </action>
  <verify>
    <automated>curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:54321/rest/v1/ -H "apikey: sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH" | grep -q "200"</automated>
  </verify>
  <done>All Supabase services respond correctly: REST API returns 200, auth endpoint returns 200, islands table has 100 rows via REST, Docker containers are healthy</done>
</task>

</tasks>

<verification>
- `.env.local` exists with SUPABASE_URL and SUPABASE_ANON_KEY
- `.gitignore` includes `.env.*` pattern
- `scripts/run_local.sh` and `scripts/run_local.ps1` exist with dart-define flags
- Supabase REST API responds at http://127.0.0.1:54321
- Auth endpoint responds at http://127.0.0.1:54321/auth/v1/settings
- Database has islands (100), profiles, cities tables
</verification>

<success_criteria>
- Developer can run `./scripts/run_local.sh` (or `.\scripts\run_local.ps1` on PowerShell) to start Flutter connected to local Supabase
- All Supabase services are verified healthy via REST API calls
- Environment configuration is clean: .env.local for values, .gitignore for safety, scripts for convenience
</success_criteria>

<output>
After completion, create `.planning/quick/1-setup-supabase-local-dev-with-docker-sta/1-SUMMARY.md`
</output>
