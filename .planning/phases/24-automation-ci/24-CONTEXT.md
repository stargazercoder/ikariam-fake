# Phase 24: Automation & CI - Context

**Gathered:** 2026-03-18
**Status:** Ready for planning

<domain>
## Phase Boundary

A developer can set up the full project from scratch with one command (`scripts/dev_setup.sh`), and every push to main automatically runs the full quality gate via GitHub Actions. This phase delivers two things: (1) a dev setup script and (2) a CI workflow file.

</domain>

<decisions>
## Implementation Decisions

### Dev setup script (AUTO-01)
- Create `scripts/dev_setup.sh` (bash) and `scripts/dev_setup.ps1` (PowerShell) — matching the existing dual-script pattern
- Script performs: db reset, seed data, edge functions serve (background), flutter build web
- Edge Functions serve runs in background so the script can proceed to flutter build
- Script should verify prerequisites (supabase CLI, flutter, deno) before starting
- Exit non-zero on any step failure (set -euo pipefail / $ErrorActionPreference = 'Stop')

### CI workflow (AUTO-02)
- Single GitHub Actions workflow file: `.github/workflows/ci.yml`
- Triggers on: push to main, pull requests targeting main
- Single job with sequential steps (simpler than matrix — project has one target platform: web)
- Steps in order: checkout → setup Flutter → setup Deno 2.2.x → flutter analyze → deno test → flutter test → flutter build web
- Deno pinned to 2.2.x with inline comment: `# Supabase Edge Runtime does not support Deno 2.3+ lock file v5 (supabase/supabase#33093)`
- No Supabase CLI in CI — Deno tests run against extracted pure functions (no DB needed); Flutter tests use mocked providers
- flutter analyze failure or deno test failure causes non-zero exit (blocks merge)

### Deno test integration in local scripts
- Update `test_all.sh` and `test_all.ps1` to include a Deno test step between db reset and Flutter tests
- Step order: [1/3] db reset → [2/3] deno test → [3/3] flutter test

### Claude's Discretion
- Exact GitHub Actions action versions (e.g., actions/checkout@v4, subosito/flutter-action version)
- Whether to cache Flutter/Deno dependencies in CI (performance optimization)
- Dev setup script output formatting (echo colors, progress indicators)
- Whether dev_setup script waits for Edge Functions serve to be healthy before proceeding

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing scripts
- `scripts/run_local.sh` — Dev run script pattern (bash); shows Supabase URL/key handling
- `scripts/run_local.ps1` — Dev run script pattern (PowerShell); parallel implementation
- `scripts/test_all.sh` — Current test runner (bash); db reset + flutter test only
- `scripts/test_all.ps1` — Current test runner (PowerShell); parallel implementation

### Test locations
- `supabase/functions/tests/` — Deno test files for Edge Function pure functions
- `supabase/functions/_shared/` — Shared modules including extracted formulas
- `test/` — Flutter widget tests directory

### Project config
- `pubspec.yaml` — Flutter project configuration
- `supabase/config.toml` — Supabase project configuration

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/run_local.sh` + `.ps1`: Established pattern for dual bash/PowerShell scripts with .env.local loading and Supabase status checking
- `scripts/test_all.sh` + `.ps1`: Existing test runner to extend with Deno test step

### Established Patterns
- All scripts exist in both bash (.sh) and PowerShell (.ps1) variants
- Scripts use `set -euo pipefail` (bash) / `$ErrorActionPreference = 'Stop'` (PowerShell) for fail-fast
- Scripts navigate to project root via `SCRIPT_DIR`/`PROJECT_DIR` pattern
- Supabase CLI invoked via `npx supabase` (not global install)

### Integration Points
- `.github/workflows/ci.yml` — new file, no existing CI to conflict with
- `scripts/dev_setup.sh` + `.ps1` — new files in existing scripts directory
- `scripts/test_all.sh` + `.ps1` — existing files to be updated with Deno test step

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. Follow existing script patterns.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 24-automation-ci*
*Context gathered: 2026-03-18*
