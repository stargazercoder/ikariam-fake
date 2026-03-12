# Phase 6: Production Hardening - Research

**Researched:** 2026-03-12
**Domain:** Flutter web deployment, splash screen loading, Supabase production verification, RLS audit
**Confidence:** HIGH

## Summary

Phase 6 has a narrow, well-defined scope: one open requirement (INFR-01 — splash screen during CanvasKit load), plus production verification of two already-implemented guarantees (INFR-02 server-authority, INFR-03 RLS). There is no new game feature to build.

Flutter web's default renderer is CanvasKit, which downloads ~1.5 MB of Skia-compiled WebAssembly before any Flutter widget renders. Without intervention the browser shows a blank white page for several seconds on a standard connection. The fix is entirely in `web/index.html` and an optional custom `web/flutter_bootstrap.js`: add an HTML/CSS splash element that is visible immediately, then remove it inside the `onEntrypointLoaded` callback once the engine is ready. No Dart code changes are needed.

The production verification work (INFR-02, INFR-03) requires running SQL audit queries against the production Supabase project and smoke-testing that no Dart client call can directly INSERT/UPDATE/DELETE game-state tables. All 10 game-state tables already have RLS enabled in their creation migrations; the audit is confirmatory, not corrective. Edge Function deployment to production via `supabase functions deploy` is also in scope.

**Primary recommendation:** Implement the splash screen entirely in `web/index.html` using the `onEntrypointLoaded` hook in `flutter_bootstrap.js`. Deploy Edge Functions with `supabase functions deploy`. Run the RLS audit SQL to confirm all tables are protected.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| INFR-01 | Flutter web shows splash screen during CanvasKit load instead of blank page | Covered by flutter_bootstrap.js `onEntrypointLoaded` pattern; HTML/CSS visible before JS executes |
</phase_requirements>

## Standard Stack

### Core
| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Flutter web (CanvasKit) | SDK ^3.10.1 (already pinned) | Web renderer, produces build/web output | Default renderer; compatible with all modern browsers |
| flutter_bootstrap.js | Built-in (Flutter 3.22+) | Lifecycle hooks for custom loading UI | Official API for init customization; replaces legacy `_flutter.loader` patterns |
| Supabase CLI | latest (supabase) | Deploy Edge Functions, run migrations | Official deployment tool for Edge Functions |

### Supporting
| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| python -m http.server | stdlib | Local test of production build | Verify build/web output before deploy |
| Firebase Hosting / GitHub Pages | — | Static hosting for Flutter web output | If project needs a public URL; Firebase adds SPA rewrite config automatically |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| CanvasKit (default) | skwasm (--wasm flag) | skwasm is ~0.4 MB lighter and faster but requires WasmGC browser support and COOP/COEP security headers on the server — adds hosting complexity; CanvasKit is sufficient for v1 |
| Custom flutter_bootstrap.js | Inline `<script>` in index.html | Both work; custom file is cleaner to maintain and version-controlled separately |

**Build command:**
```bash
flutter build web --release
```

**Edge Function deploy:**
```bash
supabase functions deploy upgrade-building
supabase functions deploy train-units
supabase functions deploy dispatch-units
```

## Architecture Patterns

### Recommended Project Structure (web/ changes only)
```
web/
├── index.html           # Add splash HTML + link to flutter_bootstrap.js
├── flutter_bootstrap.js # NEW: custom bootstrap with onEntrypointLoaded hook
├── favicon.png          # Unchanged
├── icons/               # Unchanged
└── manifest.json        # Update name/description/theme_color for game branding
```

### Pattern 1: HTML/CSS Splash in index.html + onEntrypointLoaded removal
**What:** An HTML element with CSS styles is placed in `<body>` before `flutter_bootstrap.js` loads. The element is visible immediately (zero JavaScript required). Once the Flutter engine finishes initialising, `onEntrypointLoaded` removes the element.

**When to use:** Always — this is the INFR-01 requirement.

**Example (index.html body):**
```html
<!-- Source: https://docs.flutter.dev/platform-integration/web/initialization -->
<body>
  <div id="splash">
    <style>
      #splash {
        position: fixed; inset: 0;
        display: flex; align-items: center; justify-content: center;
        background: #1a1a2e;  /* dark game theme */
        z-index: 9999;
        transition: opacity 0.4s ease;
      }
      #splash h1 {
        color: #c9a84c; font-family: serif; font-size: 2.5rem;
        letter-spacing: 0.1em;
      }
      #splash p {
        color: #888; font-size: 0.9rem; margin-top: 0.5rem; text-align: center;
      }
    </style>
    <div style="text-align:center">
      <h1>IKARIAM</h1>
      <p>Loading...</p>
    </div>
  </div>
  <script src="flutter_bootstrap.js" async></script>
</body>
```

**Example (web/flutter_bootstrap.js):**
```javascript
// Source: https://docs.flutter.dev/platform-integration/web/initialization
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    // Remove splash only after Flutter app is running
    const splash = document.getElementById('splash');
    if (splash) {
      splash.style.opacity = '0';
      setTimeout(() => splash.remove(), 400);
    }
  }
});
```

**Key detail:** The `{{flutter_js}}` and `{{flutter_build_config}}` tokens are substituted at build time. Both tokens are mandatory in any custom `flutter_bootstrap.js`.

### Pattern 2: RLS Audit SQL Query
**What:** A single SQL query against `pg_tables` confirms RLS is enabled on every public table.

**When to use:** Run once against the production Supabase project via the SQL Editor or `supabase db execute`.

**Example:**
```sql
-- Source: Supabase docs + pg_tables system catalog
SELECT
  tablename,
  rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

Expected: every row has `rls_enabled = true`. Any `false` row is a gap.

### Pattern 3: INFR-02 Verification (no client direct-write path)
**What:** Confirm no Flutter client code calls `.insert()`, `.update()`, or `.delete()` on game-state tables directly. The audit is a code search, not a runtime test.

**When to use:** Once during phase execution as a code review step.

**Search commands:**
```bash
# In project root — find any direct client mutation on game-state tables
grep -r "\.insert\|\.update\|\.delete\|\.upsert" lib/ --include="*.dart" \
  | grep -v "profiles"  # profiles UPDATE is the sole approved exception (profiles_update_own RLS)
```

Expected: zero results except for the approved `ProfileRepository.updateProfile` call.

### Anti-Patterns to Avoid
- **Removing the `<base href>` tag:** Blank-page workarounds suggest this, but it breaks asset paths in subdirectory deployments. Do not remove it.
- **Using `--web-renderer html`:** The HTML renderer was deprecated and is being removed from Flutter. Do not use it.
- **Calling `appRunner.runApp()` then immediately removing the splash:** Add the splash removal inside the same `onEntrypointLoaded` callback after `runApp()` awaits — this guarantees the first Flutter frame is ready.
- **Deploying with `--no-verify-jwt` on Edge Functions:** The three project Edge Functions all validate JWT via `anonClient.auth.getUser()`. Do not strip JWT verification on deploy.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Splash screen timing | Custom JS polling for canvas element | `onEntrypointLoaded` callback | Official lifecycle hook fires at exactly the right moment; polling is fragile |
| RLS verification | Manual table-by-table dashboard inspection | SQL query on `pg_tables.rowsecurity` | One query covers all tables; dashboard inspection is error-prone at 10+ tables |
| Edge Function bundling | Manual Deno bundle commands | `supabase functions deploy` | CLI handles ESZip bundling, dependency graph, and upload automatically |
| Production build testing | Skip local test of build/web | `python -m http.server 8000` on build/web | CanvasKit behaves differently in debug vs release; must verify release build locally |

**Key insight:** INFR-01 is purely a `web/` folder change. Zero Dart changes are required.

## Common Pitfalls

### Pitfall 1: Splash Removed Before First Flutter Frame Paints
**What goes wrong:** Splash element disappears but the canvas is still blank for a fraction of a second, creating a flash of white.
**Why it happens:** `runApp()` returns before the first frame is committed to screen.
**How to avoid:** Remove the splash _after_ `await appRunner.runApp()` — the await guarantees the engine has submitted at least one frame. Adding a short CSS opacity transition (0.3–0.4 s) further masks any residual flash.
**Warning signs:** White flash visible on a fast local connection; more obvious on slow connections.

### Pitfall 2: Missing `{{flutter_js}}` or `{{flutter_build_config}}` Tokens
**What goes wrong:** Custom `flutter_bootstrap.js` causes a runtime error: `_flutter is not defined`.
**Why it happens:** The Flutter build step substitutes these tokens. Without them the loader API is never injected.
**How to avoid:** Both tokens are mandatory. Always include both at the top of `web/flutter_bootstrap.js`.
**Warning signs:** Browser console shows `ReferenceError: _flutter is not defined`.

### Pitfall 3: Production Supabase Project Missing Edge Function Secrets
**What goes wrong:** Edge Functions deployed to production fail with 500 errors because `SUPABASE_URL`, `SUPABASE_ANON_KEY`, or `SUPABASE_SERVICE_ROLE_KEY` env vars are absent.
**Why it happens:** These are injected automatically in local dev but must be set as secrets on the production project.
**How to avoid:** Supabase automatically injects `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` into Edge Functions in production — no manual secret setup needed for these three. Verify by checking Edge Function logs after first invocation.
**Warning signs:** Edge Function returns 500 with `Cannot read properties of undefined` in logs.

### Pitfall 4: Flutter Build Output Served Without SPA Rewrite
**What goes wrong:** Direct navigation to a Flutter route URL (e.g., `/map`) returns a 404.
**Why it happens:** Flutter web is a single-page app; all routes must resolve to `index.html`.
**How to avoid:** Configure the static host to rewrite all 404s to `/index.html`. Firebase Hosting does this automatically. For GitHub Pages, add a `404.html` redirect workaround.
**Warning signs:** Refreshing the browser on any non-root route returns a 404.

### Pitfall 5: `base href` Set to Wrong Value
**What goes wrong:** App loads at root but all assets (CanvasKit WASM, fonts, icons) return 404.
**Why it happens:** The `<base href>` in `index.html` is used by `flutter build web --base-href`. If deploying at root the default `/` is correct; if deploying to a subdirectory (e.g. GitHub Pages at `/repo-name/`) it must match.
**How to avoid:** Pass `--base-href /` for root deployments. For subdirectory deploys: `flutter build web --base-href /ikariam/`.
**Warning signs:** Browser network tab shows asset URLs resolving to wrong paths.

## Code Examples

Verified patterns from official sources:

### Complete flutter_bootstrap.js with Splash Removal
```javascript
// Source: https://docs.flutter.dev/platform-integration/web/initialization
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    const splash = document.getElementById('splash');
    if (splash) {
      splash.style.opacity = '0';
      setTimeout(() => splash.remove(), 400);
    }
  }
});
```

### RLS Verification — All Tables
```sql
-- Source: https://supabase.com/docs/guides/database/postgres/row-level-security
-- Run in Supabase SQL Editor (production project)
SELECT tablename, rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- Expected output: all 10 game tables show rls_enabled = true
-- Tables: battles, battle_turns, cities, city_buildings, city_resources,
--         city_units, construction_queue, islands, profiles,
--         training_queue, unit_movements
```

### RLS Policies Count Check
```sql
-- Confirm each table has at least one policy defined
SELECT tablename, COUNT(*) AS policy_count
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY tablename;

-- Any table with 0 policies (even if RLS is enabled) blocks ALL access
-- including authenticated users — this is a misconfiguration.
```

### Verify No Client Direct-Write to Game Tables (Dart grep)
```bash
# Run from project root
grep -rn "\.insert\b\|\.update\b\|\.delete\b\|\.upsert\b" lib/ --include="*.dart"
```

Expected: only `ProfileRepository` appears (`.update()` on profiles — approved exception per project decisions).

### Production Build + Local Test
```bash
flutter build web --release
cd build/web
python -m http.server 8000
# Open http://localhost:8000 and verify splash shows before Flutter paints
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `_flutter.loader.loadEntrypoint()` | `_flutter.loader.load({ onEntrypointLoaded })` | Flutter 3.22 (2024) | New API provides clean lifecycle hooks; old API still works but is legacy |
| HTML renderer (`--web-renderer html`) | CanvasKit default (remove `--web-renderer` flag) | Flutter 3.24 (2024) | HTML renderer deprecated and being removed |
| `flutter.js` + manual loader setup | `flutter_bootstrap.js` auto-generated | Flutter 3.22 | Bootstrap script now generated automatically; custom override via `web/flutter_bootstrap.js` |

**Deprecated/outdated:**
- `--web-renderer html`: Deprecated as of Flutter 3.24; removal in progress. Do not use.
- `--web-renderer canvaskit`: Flag still works but redundant — CanvasKit is now the default.
- `window.addEventListener('flutter-first-frame', ...)`: Old pattern for splash removal; replaced by `onEntrypointLoaded` callback.

## Open Questions

1. **Hosting target for production**
   - What we know: The project builds to `build/web` static files; any static host works
   - What's unclear: No deployment target specified in requirements or CONTEXT.md
   - Recommendation: Planner should include a deployment step (Firebase Hosting or GitHub Pages); Firebase is easier for SPA routing. If no external host is needed (local only), skip deployment plan and focus on INFR-01 + audit.

2. **Production Supabase project existence**
   - What we know: Local Supabase dev environment confirmed working (quick-1); migrations all apply cleanly
   - What's unclear: Whether a production Supabase project has been created and linked
   - Recommendation: Plan should include `supabase link --project-ref <ref>` and `supabase db push` as a task if the production project is not yet linked.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in SDK) |
| Config file | none — flutter test discovers test/ automatically |
| Quick run command | `flutter test test/unit/ --reporter=compact` |
| Full suite command | `flutter test --reporter=compact` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INFR-01 | Splash HTML element present in index.html before flutter_bootstrap.js loads | manual-only | N/A — browser visual check | N/A |
| INFR-01 | flutter_bootstrap.js contains onEntrypointLoaded with splash removal | unit (file content check) | `flutter test test/unit/infr_splash_test.dart -x` | ❌ Wave 0 |
| INFR-02 | No Dart client code calls .insert/.update/.delete on game-state tables | manual (grep audit) | `grep -rn "\.insert\b\|\.update\b\|\.delete\b" lib/ --include="*.dart"` | N/A |
| INFR-03 | All public tables have RLS enabled in production | manual (SQL audit) | SQL query on pg_tables | N/A |

**Note on INFR-01 automated test:** A minimal Dart unit test can read `web/flutter_bootstrap.js` as a file and assert it contains the required strings (`onEntrypointLoaded`, `splash`, `runApp`). This makes the check repeatable without a browser. The test lives in `test/unit/infr_splash_test.dart`.

### Sampling Rate
- **Per task commit:** `flutter test test/unit/ --reporter=compact`
- **Per wave merge:** `flutter test --reporter=compact`
- **Phase gate:** Full suite green + manual browser splash verification before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/unit/infr_splash_test.dart` — covers INFR-01 (file-content check for splash bootstrap pattern)

## Sources

### Primary (HIGH confidence)
- https://docs.flutter.dev/platform-integration/web/initialization — `flutter_bootstrap.js` tokens, `onEntrypointLoaded` API, lifecycle hooks
- https://docs.flutter.dev/platform-integration/web/renderers — CanvasKit default, skwasm tradeoffs, HTML renderer deprecation
- https://docs.flutter.dev/deployment/web — `flutter build web` command, build modes, deployment options
- https://supabase.com/docs/guides/database/postgres/row-level-security — RLS enablement, pg_tables audit query

### Secondary (MEDIUM confidence)
- https://supabase.com/docs/guides/functions/deploy — `supabase functions deploy` command and ESZip bundling
- https://supabase.com/docs/guides/database/database-advisors — Supabase Security Advisor for RLS lint check

### Tertiary (LOW confidence)
- https://dev.to/samuelkchris/optimizing-flutter-webs-initial-load-time-an-updated-comprehensive-guide-4j84 — WebSearch only; loading time benchmarks
- https://coldfusion-example.blogspot.com/2026/01/flutter-web-performance-2025-canvaskit.html — WebSearch only; renderer comparison numbers

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Flutter docs and Supabase docs are primary sources
- Architecture: HIGH — `onEntrypointLoaded` pattern is from official Flutter initialization docs
- Pitfalls: HIGH for items 1-3 (official docs); MEDIUM for items 4-5 (multiple community sources, consistent with official SPA guidance)

**Research date:** 2026-03-12
**Valid until:** 2026-06-12 (stable APIs — Flutter renderer changes are announced well in advance)
