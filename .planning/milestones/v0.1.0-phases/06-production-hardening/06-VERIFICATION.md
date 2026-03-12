---
phase: 06-production-hardening
verified: 2026-03-12T09:00:00Z
status: human_needed
score: 3/3 automated must-haves verified
re_verification: false
human_verification:
  - test: "Splash screen visible in browser before Flutter/CanvasKit renders"
    expected: "Dark indigo (#1A237E) page with gold IKARIAM heading and Loading... text appears immediately; fades to Flutter app after CanvasKit load; page is never blank white"
    why_human: "Visual rendering behavior in a real browser cannot be verified by static file analysis; 06-02-SUMMARY.md records approval but approval occurred during plan execution, not independent verification"
  - test: "Production build interactive time on a standard connection"
    expected: "Game reaches interactive state within an acceptable time (~5-10s on standard broadband)"
    why_human: "Load-time performance requires a live network measurement; cannot be derived from file content"
---

# Phase 6: Production Hardening Verification Report

**Phase Goal:** The game is deployed to the web with acceptable first-load performance, a proper splash screen during CanvasKit load, and the server-authority contract verified in production
**Verified:** 2026-03-12T09:00:00Z
**Status:** human_needed — all automated checks pass; splash screen visual behavior requires human sign-off as independent verification
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Visiting the game URL shows a styled HTML/CSS splash screen immediately while CanvasKit loads — the page is never blank | ? HUMAN NEEDED | Files verified correct; browser rendering requires human confirmation |
| 2 | The game reaches interactive state within an acceptable time on a standard connection | ? HUMAN NEEDED | Production build exists; load time requires live measurement |
| 3 | All INFR-02 and INFR-03 guarantees (server-only mutations, RLS on all tables) are verified to hold | ✓ VERIFIED | grep audit: only ProfileRepository.updateProfile; all 11 tables have RLS + at least 1 policy |

**Score:** 1/3 truths fully verifiable by automation; 2/3 require human confirmation (all automated checks passed)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `web/index.html` | HTML splash screen visible before any JS executes | ✓ VERIFIED | Contains `id="splash"` at line 36, before `flutter_bootstrap.js` script tag at line 47. Title "Ikariam", meta description updated, branding colors present |
| `web/flutter_bootstrap.js` | Custom bootstrap with splash removal on engine ready | ✓ VERIFIED | Contains `{{flutter_js}}`, `{{flutter_build_config}}`, `onEntrypointLoaded`, `runApp()`, `getElementById('splash')` in correct order (runApp before getElementById) |
| `web/manifest.json` | Updated PWA manifest with game branding | ✓ VERIFIED | name/short_name "Ikariam", background_color "#1A237E", theme_color "#1A237E", description updated |
| `test/unit/infr_splash_test.dart` | Automated file-content check for splash pattern | ✓ VERIFIED | 17 tests across 3 groups covering index.html structure, flutter_bootstrap.js content, manifest.json branding; all assertions match actual file content |
| `build/web/` | Production release build output | ✓ VERIFIED | Directory exists with index.html (contains splash div), main.dart.js, flutter_bootstrap.js, canvaskit/, and full asset set |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `web/index.html` | `web/flutter_bootstrap.js` | `<script src="flutter_bootstrap.js" async>` | ✓ WIRED | Script tag at line 47 references flutter_bootstrap.js |
| `web/flutter_bootstrap.js` | `web/index.html #splash` | `getElementById` after `runApp()` | ✓ WIRED | `document.getElementById('splash')` at line 8; runApp() at line 7 — removal happens after app starts |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| INFR-01 | 06-01-PLAN.md, 06-02-PLAN.md | Flutter web shows splash screen during CanvasKit load instead of blank page | ? HUMAN NEEDED | File-level implementation verified; visual behavior in browser requires human confirmation |

**INFR-02 and INFR-03** (claimed in 06-02-SUMMARY.md as also verified by this phase):

| Requirement | Source | Description | Status | Evidence |
|-------------|--------|-------------|--------|----------|
| INFR-02 | Phase 1 (primary), 06-02 (re-audited) | All game state mutations run server-side | ✓ VERIFIED | grep across `lib/**/*.dart`: only `ProfileRepository.updateProfile` calls `.update()` — operates on `profiles` table with owner RLS policy; all game-state mutations go through Edge Functions |
| INFR-03 | Phase 1 (primary), 06-02 (re-audited) | RLS enabled on every database table | ✓ VERIFIED | Migration audit: 11 public tables (`islands`, `profiles`, `cities`, `city_resources`, `city_buildings`, `construction_queue`, `city_units`, `training_queue`, `unit_movements`, `battles`, `battle_turns`) — all have `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` and at least 1 `CREATE POLICY` |

**Note:** INFR-02 and INFR-03 are formally Phase 1 requirements (REQUIREMENTS.md traceability table). Phase 6 Plan 02 re-audited them as part of the production hardening gate — this is additive validation, not their primary ownership.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `web/index.html` | 14 | Comment text "placeholder for base href" | Info | Flutter framework comment, not a code stub — this is standard Flutter scaffold text and is functionally correct |

No functional anti-patterns found. The "placeholder" text is a Flutter-generated comment explaining the `$FLUTTER_BASE_HREF` token — it is correct and expected.

---

### Human Verification Required

#### 1. Splash Screen Visual Rendering

**Test:** Serve the production build locally:
```
cd build/web && python -m http.server 8000
```
Open http://localhost:8000 in a browser.

**Expected:** Dark indigo (#1A237E) background with "IKARIAM" in gold serif text and "Loading..." below, visible immediately. After CanvasKit loads (1-3 seconds), splash fades out and the Flutter app appears. Page is **never** blank white at any point.

**Throttled test:** DevTools > Network > Slow 3G, then refresh — splash must remain visible throughout CanvasKit download.

**Why human:** Visual rendering in a real browser cannot be confirmed by static file analysis. The file content is correct (verified), but the browser paint behavior is what INFR-01 actually requires.

#### 2. First-Load Interactive Time

**Test:** With DevTools Network tab recording, load http://localhost:8000 on an unthrottled connection and note time-to-interactive.

**Expected:** Game reaches interactive state (first Flutter frame painted, login screen responsive) within an acceptable time.

**Why human:** Load-time performance is a runtime measurement; no build artifact encodes the timing value.

---

### Summary

**All automated checks passed:**

- All 4 source artifacts exist and are substantive — no stubs, no placeholders, no empty implementations
- Both key links wired correctly (index.html references bootstrap; bootstrap removes splash after runApp)
- Production build confirmed in `build/web/` with splash div present in built index.html
- INFR-02 grep audit: clean — only the approved ProfileRepository exception
- INFR-03 migration audit: all 11 public tables have RLS enabled with at least 1 policy each
- `test/unit/infr_splash_test.dart` has 17 substantive file-content assertions that structurally mirror the actual implementation

**Pending human confirmation:**

INFR-01 is the sole requirement owned by Phase 6. Its automated layer (file content, build output, bootstrap wiring) is fully verified. The remaining confirmation is whether the splash is visually observable in a browser — which was approved during 06-02 plan execution but has not been independently re-confirmed by this verification pass.

If the human splash verification from plan 06-02 (user response "approved") is accepted as the independent gate, this phase can be marked **passed**. If independent re-verification is required, the human test above must be re-run.

---

_Verified: 2026-03-12T09:00:00Z_
_Verifier: Claude (gsd-verifier)_
