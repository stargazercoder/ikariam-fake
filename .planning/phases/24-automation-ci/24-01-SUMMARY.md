---
phase: 24-automation-ci
plan: 01
subsystem: infra
tags: [bash, powershell, deno, flutter, supabase, automation, scripts]

# Dependency graph
requires: []
provides:
  - scripts/dev_setup.sh — one-command dev bootstrap with prerequisite checks, db reset, background Edge Functions serve, Flutter web build
  - scripts/dev_setup.ps1 — PowerShell equivalent of dev_setup.sh
  - scripts/test_all.sh — updated 3-step test runner: db reset + deno test + flutter test
  - scripts/test_all.ps1 — PowerShell equivalent of test_all.sh
affects: [ci-pipeline, onboarding, developer-workflow]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bash scripts use set -euo pipefail + SCRIPT_DIR/PROJECT_DIR pattern from run_local.sh"
    - "PowerShell scripts use $ErrorActionPreference = Stop + Split-Path pattern from run_local.ps1"
    - "Prerequisite check function (check_command / Test-Command) runs before any long-running work"
    - "Edge Functions serve backgrounded with & (bash) / Start-Job (PowerShell)"

key-files:
  created:
    - scripts/dev_setup.sh
    - scripts/dev_setup.ps1
  modified:
    - scripts/test_all.sh
    - scripts/test_all.ps1

key-decisions:
  - "Step numbering is [1/3] across all four scripts — db reset includes seed automatically so no separate seed step needed"
  - "Prerequisite checks (flutter, deno, npx) run before any work to give clear error messages and avoid partial setup states"
  - "Background serve uses & / Start-Job to allow Flutter build to proceed; PID/Job ID printed for manual cleanup"
  - ".env.local loading and SUPABASE_URL/SUPABASE_ANON_KEY fallback follows run_local.sh pattern exactly"

patterns-established:
  - "check_command pattern: verify tool presence with clear error before starting work"
  - "deno test supabase/functions/tests/ as step [2/3] in all test runners"

requirements-completed: [AUTO-01]

# Metrics
duration: 1min
completed: 2026-03-18
---

# Phase 24 Plan 01: Dev Setup Scripts and Test Runner Update Summary

**Bash and PowerShell dev setup scripts with prerequisite checks + test runners updated to 3-step coverage (db reset, Deno, Flutter)**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-18T12:35:10Z
- **Completed:** 2026-03-18T12:36:22Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Created scripts/dev_setup.sh: one-command dev bootstrap with flutter/deno/npx prerequisite checks, db reset, background Edge Functions serve, and Flutter web build
- Created scripts/dev_setup.ps1: PowerShell equivalent following existing run_local.ps1 conventions
- Updated scripts/test_all.sh from 2-step to 3-step with `deno test supabase/functions/tests/` as step [2/3]
- Updated scripts/test_all.ps1 to match, with $LASTEXITCODE check after deno step ensuring immediate exit on failure

## Task Commits

Each task was committed atomically:

1. **Task 1: Create dev_setup.sh and dev_setup.ps1** - `1643ce8` (feat)
2. **Task 2: Update test_all.sh and test_all.ps1 with Deno test step** - `c1c5040` (feat)

## Files Created/Modified
- `scripts/dev_setup.sh` - Bash dev bootstrap: prerequisite checks, db reset, background serve, Flutter web build
- `scripts/dev_setup.ps1` - PowerShell dev bootstrap: same as bash variant using PowerShell idioms
- `scripts/test_all.sh` - Updated: 3-step runner with Deno unit tests as step [2/3]
- `scripts/test_all.ps1` - Updated: 3-step runner with Deno unit tests as step [2/3]

## Decisions Made
- Step numbering is [1/3] in all scripts — supabase db reset runs seed.sql automatically so no separate seed step needed
- Prerequisite checks run before any work to surface missing tools immediately with actionable error messages
- .env.local loading pattern copied verbatim from run_local.sh / run_local.ps1 for consistency

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All four automation scripts ready for Phase 24 plan 02 (CI pipeline setup)
- test_all scripts now cover db reset + Deno unit tests + Flutter tests in a single command
- dev_setup scripts enable one-command project bootstrap for new developers

---
*Phase: 24-automation-ci*
*Completed: 2026-03-18*
