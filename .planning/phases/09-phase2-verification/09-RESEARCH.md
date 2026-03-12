# Phase 9: Phase 2 Verification - Research

**Researched:** 2026-03-12
**Domain:** Codebase audit — RSRC/BLDG requirement verification against existing Phase 2 implementation
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| RSRC-01 | Cities produce 5 resource types: Wood, Marble, Crystal, Sulfur, Gold | Verified in migrations 20260311000004 (city_resources table), 20260311000007 (on_city_created trigger seeds all 5), 20260311000008 (process_resource_tick covers all 5 types) |
| RSRC-02 | Resource production runs server-side via pg_cron every 5 minutes | Verified in migration 20260311000010: `cron.schedule('resource-tick', '*/5 * * * *', 'SELECT public.process_resource_tick()')` |
| RSRC-03 | Production rate calculated as workers x building_level x research_bonus | Verified in migration 20260311000008: `r.workers * r.prod_level * 1.0` (research_bonus hard-coded 1.0 for v1) |
| RSRC-04 | Resources capped by Warehouse building capacity | Verified in migration 20260311000008: `LEAST(r.current_amount + production, 500.0 * POWER(1.5, r.warehouse_level))` |
| BLDG-01 | City supports 10 building types: Town Hall, Warehouse, Barracks, Shipyard, Academy, Embassy, Trading Port, Town Wall, Hideout, Tavern | Verified in migration 20260311000005: CHECK constraint lists exactly these 10 city building types (plus 4 production buildings); `building_constants.dart` `BuildingType` enum has 14 values with these 10 as non-production types |
| BLDG-02 | Buildings can be upgraded with cost formula (base_cost x 1.5^level) | Verified in `upgrade-building/index.ts`: `calcUpgradeCost()` uses `Math.pow(1.5, currentLevel)`; mirrored in `building_constants.dart`: `upgradeCost()` uses `pow(costGrowthFactor, currentLevel)` with `costGrowthFactor = 1.5` |
| BLDG-03 | Building upgrade takes time calculated as base_time x 1.2^level (minutes) | Verified in `upgrade-building/index.ts`: `calcUpgradeDurationMinutes()` uses `Math.pow(1.2, currentLevel)`; mirrored in `building_constants.dart`: `upgradeDurationMinutes()` uses `pow(timeGrowthFactor, currentLevel)` with `timeGrowthFactor = 1.2` |
| BLDG-04 | Only one construction can run at a time per city | Verified in migration 20260311000006: `UNIQUE (city_id)` constraint on `construction_queue`; enforced in `upgrade-building/index.ts` lines 175-186: checks for existing queue row and returns 409 if found |
| BLDG-05 | Construction completion detected and applied by pg_cron tick | Verified in migration 20260311000010: `cron.schedule('construction-tick', '* * * * *', 'SELECT public.complete_building_upgrades()')`; migration 20260311000009: `complete_building_upgrades()` checks `WHERE finish_at <= NOW()`, increments level, deletes queue row |
</phase_requirements>

---

## Summary

Phase 9 is not a feature implementation phase — it is a documentation verification task. The goal is to create the missing `02-VERIFICATION.md` file for Phase 2 (Core Economy). All other phases (1, 3-8) already have their corresponding `VERIFICATION.md` files. Phase 2 completed successfully with all plans merged but its verification document was never created.

The Phase 2 implementation is fully in the codebase. All 9 requirements (RSRC-01 through RSRC-04, BLDG-01 through BLDG-05) have concrete evidence in specific migration files, Edge Function TypeScript, and Dart constants. The research below maps each requirement to its precise code evidence so the planner can generate accurate observable truths and artifact verification tables.

The VERIFICATION.md follows the exact same format as the existing Phase 1, 3, 4, 5, 6, 7, and 8 verification documents. The planner needs to adopt this format and populate it with Phase 2-specific evidence. The document is code-inspector work: read the already-built files, confirm what they contain, map to requirements, write observable truths with file+line citations.

**Primary recommendation:** Create a single plan `09-01-PLAN.md` that instructs the executor to read all Phase 2 implementation files, verify each of the 9 requirements has working code, and write `02-VERIFICATION.md` into `.planning/phases/02-core-economy/`. No new code is needed — this is purely documentation.

---

## Standard Stack

This phase requires no additional libraries. The "stack" is the existing project codebase and the VERIFICATION.md document format established in Phases 1, 3-8.

### Core (existing — read-only)
| Component | Location | Purpose |
|-----------|----------|---------|
| city_resources table | `supabase/migrations/20260311000004_create_city_resources.sql` | RSRC-01, RSRC-04 evidence |
| city_buildings table | `supabase/migrations/20260311000005_create_city_buildings.sql` | BLDG-01 evidence |
| construction_queue table | `supabase/migrations/20260311000006_create_construction_queue.sql` | BLDG-04 evidence |
| on_city_created trigger | `supabase/migrations/20260311000007_on_city_created_trigger.sql` | RSRC-01, BLDG-01 evidence |
| process_resource_tick() | `supabase/migrations/20260311000008_resource_production_functions.sql` | RSRC-02, RSRC-03, RSRC-04 evidence |
| complete_building_upgrades() | `supabase/migrations/20260311000009_construction_functions.sql` | BLDG-05 evidence |
| pg_cron jobs | `supabase/migrations/20260311000010_pg_cron_jobs.sql` | RSRC-02, BLDG-05 evidence |
| upgrade-building Edge Function | `supabase/functions/upgrade-building/index.ts` | BLDG-02, BLDG-03, BLDG-04 evidence |
| BuildingType / upgradeCost / upgradeDurationMinutes | `lib/core/constants/building_constants.dart` | BLDG-01, BLDG-02, BLDG-03 evidence |
| ResourceType / warehouseCapacity | `lib/core/constants/resource_constants.dart` | RSRC-01, RSRC-04 evidence |
| resourcesStreamProvider | `lib/features/city/providers/resources_provider.dart` | RSRC-01 Flutter wiring |
| buildingsStreamProvider | `lib/features/city/providers/buildings_provider.dart` | BLDG-01 Flutter wiring |
| constructionQueueProvider | `lib/features/city/providers/construction_provider.dart` | BLDG-04, BLDG-05 Flutter wiring |
| BuildingsRepository | `lib/features/city/data/buildings_repository.dart` | BLDG-02, BLDG-04 Flutter wiring |
| building_formulas_test.dart | `test/unit/building_formulas_test.dart` | BLDG-02, BLDG-03 automated test evidence |

---

## Architecture Patterns

### VERIFICATION.md Structure (from existing phases)

The document follows this exact structure (based on 01-VERIFICATION.md and 08-VERIFICATION.md):

```
---
phase: 02-core-economy
verified: [date]
status: passed | human_needed
score: N/N must-haves verified
---

# Phase 2: Core Economy Verification Report

**Phase Goal:** [description]
**Verified:** [date]
**Status:** [status]

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | [truth] | VERIFIED / ? NEEDS HUMAN | [file:line citation] |
...

**Score: N/N truths verified**

---

## Required Artifacts

### Plan 02-00 Artifacts
| Artifact | Expected | Status | Details |
...

### Plan 02-01 Artifacts
...

### Plan 02-02 Artifacts
...

### Plan 02-03 Artifacts
...

---

## Key Link Verification

| From | To | Via | Status | Details |
...

---

## Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
...

---

## Anti-Patterns Found

...

---

## Human Verification Required

...

---

## Gaps Summary

...

---

_Verified: [date]_
_Verifier: Claude (gsd-verifier)_
```

### Evidence-First Verification Pattern

Each observable truth follows the pattern established in Phase 1 and Phase 8 verification documents:

- **Status `VERIFIED`**: Evidence is in static code — file path, line number, exact construct confirmed
- **Status `? NEEDS HUMAN`**: Requires live Supabase stack + browser to confirm (pg_cron fires in real time, Realtime streams update UI, etc.)
- **Evidence format**: `FileName.dart:line — description of what was found`

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Verification format | A new document format | The existing VERIFICATION.md pattern from 01, 03-08 | Consistency for the planner/verifier toolchain |
| Re-implementing evidence gathering | Manually checking every file from scratch | Read the SUMMARY files (02-01, 02-02, 02-03) which already document what was built | Phase 2 plans have detailed SUMMARY files listing every file created and every decision made |

---

## Common Pitfalls

### Pitfall 1: Confusing 10 vs 14 Building Types for BLDG-01
**What goes wrong:** BLDG-01 requires "10 building types" but the DB table has 14 types in its CHECK constraint.
**Why it happens:** Phase 2 added 4 production buildings (sawmill, quarry, glassblower, sulfur_pit) to the CHECK constraint as an implementation decision — they are NOT part of the BLDG-01 requirement list (Town Hall, Warehouse, Barracks, Shipyard, Academy, Embassy, Trading Port, Town Wall, Hideout, Tavern).
**How to avoid:** BLDG-01 is SATISFIED: the 10 required types are all present in the constraint. The 4 extra production buildings are an implementation detail (needed for RSRC-03 resource formula). Document this in the verification as a note.
**Source:** `supabase/migrations/20260311000005_create_city_buildings.sql` lines 12-29 and STATE.md decision: "Production buildings (sawmill, quarry, glassblower, sulfur_pit) included in city_buildings CHECK constraint"

### Pitfall 2: Treating Base Times as Non-Compliant with BLDG-03
**What goes wrong:** BLDG-03 says "base_time x 1.2^level (minutes)" but buildingBaseTimes in the code are all `1` minute, not the larger values typical of strategy games.
**Why it happens:** BASE_TIMES were intentionally reduced to 1 minute for faster testing. The formula is correct (`ceil(1 * 1.2^level)`) — the base value is just compressed.
**How to avoid:** The requirement is about the formula shape (`base_time x 1.2^level`) not the specific base time value. BLDG-03 is SATISFIED: both `upgrade-building/index.ts` `calcUpgradeDurationMinutes()` and `building_constants.dart` `upgradeDurationMinutes()` implement the exact formula.
**Source:** `lib/core/constants/building_constants.dart` lines 186-201 and comment "NOTE: Values reduced to 1/10 for faster testing"

### Pitfall 3: Missing Evidence for RSRC-04 (Warehouse Cap)
**What goes wrong:** Verifier looks for "warehouse cap" in Flutter code and does not find it, concludes RSRC-04 is unverified.
**Why it happens:** The warehouse cap is enforced server-side only — `process_resource_tick()` uses `LEAST(amount + production, 500 * POWER(1.5, warehouse_level))`. The Flutter client has `warehouseCapacity()` in `resource_constants.dart` for display purposes only.
**How to avoid:** RSRC-04 evidence is in `supabase/migrations/20260311000008_resource_production_functions.sql` lines 58-64: the `LEAST(...)` expression. The Dart `warehouseCapacity()` function is secondary display evidence.

### Pitfall 4: Asserting pg_cron as Static-Verifiable
**What goes wrong:** Marking RSRC-02 (pg_cron every 5 minutes) as fully VERIFIED from static code.
**Why it happens:** The cron job definition is in a migration file and is statically verifiable. But whether the job actually fires and process_resource_tick() actually runs is runtime behavior.
**How to avoid:** Split into two truths: (1) "pg_cron job named 'resource-tick' is registered with `*/5 * * * *` schedule" — VERIFIED from migration 20260311000010; (2) "resource-tick fires and resources increase every 5 minutes" — NEEDS HUMAN.

### Pitfall 5: Omitting Human Verification Items
**What goes wrong:** Phase 9 verification writes all truths as VERIFIED and omits human verification section.
**Why it happens:** All static code evidence exists, so it feels complete.
**How to avoid:** Several truths require a live environment to confirm: pg_cron firing in real time, Supabase Realtime pushing updates to Flutter, construction countdown displaying correctly, second-upgrade rejection in the actual UI. Follow the Phase 1 pattern of documenting these separately under "Human Verification Required."

---

## Code Examples

### Key Evidence Snippets

**RSRC-02: pg_cron registration (migration 20260311000010, lines 15-19)**
```sql
SELECT cron.schedule(
  'resource-tick',
  '*/5 * * * *',
  'SELECT public.process_resource_tick()'
);
```

**RSRC-03: Production formula (migration 20260311000008, lines 58-65)**
```sql
UPDATE public.city_resources
SET
  amount     = LEAST(
                 r.current_amount + (r.workers * r.prod_level * 1.0),
                 500.0 * POWER(1.5, r.warehouse_level)
               ),
  updated_at = NOW()
WHERE id = r.resource_id;
```

**RSRC-04: Warehouse cap in same function as RSRC-03 above — `LEAST(amount + production, 500.0 * POWER(1.5, r.warehouse_level))`**

**BLDG-02: Cost formula (upgrade-building/index.ts, lines 65-73)**
```typescript
function calcUpgradeCost(buildingType: string, currentLevel: number): Record<string, number> {
  const baseCost = BASE_COSTS[buildingType];
  const multiplier = Math.pow(COST_GROWTH_FACTOR, currentLevel);  // 1.5^currentLevel
  const result: Record<string, number> = {};
  for (const [resource, amount] of Object.entries(baseCost)) {
    result[resource] = Math.ceil(amount * multiplier);
  }
  return result;
}
```

**BLDG-03: Time formula (upgrade-building/index.ts, line 77)**
```typescript
function calcUpgradeDurationMinutes(buildingType: string, currentLevel: number): number {
  return Math.ceil(BASE_TIMES[buildingType] * Math.pow(TIME_GROWTH_FACTOR, currentLevel));  // 1.2^level
}
```

**BLDG-04: One-at-a-time enforcement (upgrade-building/index.ts, lines 175-186)**
```typescript
const { data: queueRow, error: queueCheckError } = await admin
  .from('construction_queue')
  .select('id')
  .eq('city_id', city_id)
  .maybeSingle();

if (queueRow) {
  return errorResponse('Construction queue is busy', 409);
}
```

**BLDG-04: DB-level enforcement (migration 20260311000006, line 12)**
```sql
UNIQUE (city_id)  -- enforces one-at-a-time construction per city at DB level
```

**BLDG-05: Construction completion (migration 20260311000009, lines 18-35)**
```sql
FOR q IN
  SELECT id, city_id, building_type, target_level
  FROM public.construction_queue
  WHERE finish_at <= NOW()
LOOP
  UPDATE public.city_buildings
  SET level = q.target_level, updated_at = NOW()
  WHERE city_id = q.city_id AND building_type = q.building_type;

  DELETE FROM public.construction_queue WHERE id = q.id;
END LOOP;
```

---

## Requirements Coverage — Pre-Research Summary

Complete evidence map for the 9 Phase 2 requirements:

| Requirement | Key File(s) | Critical Lines | Status |
|-------------|------------|----------------|--------|
| RSRC-01 | `20260311000004_create_city_resources.sql`, `20260311000007_on_city_created_trigger.sql`, `resource_constants.dart` | city_resources CHECK ('wood','marble','crystal','sulfur','gold'); on_city_created INSERTs all 5; ResourceType enum has 5 values | VERIFIED (static) |
| RSRC-02 | `20260311000010_pg_cron_jobs.sql` | `cron.schedule('resource-tick', '*/5 * * * *', ...)` | VERIFIED (static); runtime needs human |
| RSRC-03 | `20260311000008_resource_production_functions.sql` | `r.workers * r.prod_level * 1.0` (research_bonus=1.0 for v1) | VERIFIED (static) |
| RSRC-04 | `20260311000008_resource_production_functions.sql`, `resource_constants.dart` | `LEAST(amount + production, 500.0 * POWER(1.5, warehouse_level))`; `warehouseCapacity()` display mirror | VERIFIED (static) |
| BLDG-01 | `20260311000005_create_city_buildings.sql`, `building_constants.dart` | 10 city building types in CHECK; BuildingType enum; on_city_created seeds all 14 rows | VERIFIED (static) |
| BLDG-02 | `upgrade-building/index.ts`, `building_constants.dart`, `building_upgrade_sheet.dart` | `calcUpgradeCost()` `COST_GROWTH_FACTOR=1.5`; Dart `upgradeCost()` `costGrowthFactor=1.5`; active unit tests in building_formulas_test.dart | VERIFIED (static + tests) |
| BLDG-03 | `upgrade-building/index.ts`, `building_constants.dart`, `building_formulas_test.dart` | `calcUpgradeDurationMinutes()` `TIME_GROWTH_FACTOR=1.2`; Dart `upgradeDurationMinutes()` `timeGrowthFactor=1.2`; tests pass | VERIFIED (static + tests) |
| BLDG-04 | `20260311000006_create_construction_queue.sql`, `upgrade-building/index.ts`, `construction_provider.dart` | `UNIQUE(city_id)` constraint; `'Construction queue is busy'` 409 response; constructionQueueProvider streams active entry | VERIFIED (static); 409 behavior needs human |
| BLDG-05 | `20260311000009_construction_functions.sql`, `20260311000010_pg_cron_jobs.sql`, `buildings_provider.dart` | `WHERE finish_at <= NOW()` completion check; `construction-tick` every minute; buildingsStreamProvider emits updated level | VERIFIED (static); Realtime update needs human |

---

## State of the Art

| Area | What Was Done | Implementation Notes |
|------|--------------|---------------------|
| Resource production | Full server-side pg_cron tick every 5 minutes | Speed-up migration exists in Phase 8 for dev (20260312000007/20260312000008) |
| Building upgrades | Edge Function with dual-client pattern (anon for auth, service role for mutations) | Non-atomic resource deduction is documented exception for v1 |
| Construction queue | DB-level UNIQUE(city_id) + Edge Function application-level check | Both DB constraint and soft check provide redundant one-at-a-time enforcement |
| Flutter UI | Supabase Realtime `.stream()` providers, no polling | StreamProvider.autoDispose.family pattern established for all economy providers |
| Test coverage | building_formulas_test.dart has 16 active (non-skipped) unit tests | Covers BLDG-02 and BLDG-03 formula verification automatically |

---

## Validation Architecture

> nyquist_validation is enabled (config.json `workflow.nyquist_validation: true`).

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Flutter test (built-in) |
| Config file | None — pubspec.yaml dev_dependencies sufficient |
| Quick run command | `flutter test test/unit/ --reporter compact` |
| Full suite command | `flutter test --reporter compact` |

### Phase Requirements -> Test Map

This phase produces no new tests. Its output is a documentation artifact (VERIFICATION.md). The existing test suite already covers the formulaic requirements:

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RSRC-01 | ResourceType enum has 5 values | unit | `flutter test test/unit/building_formulas_test.dart` | YES (building_formulas_test.dart line 96-104) |
| RSRC-02 | pg_cron job definition in migration | static analysis | Read migration file | YES (20260311000010_pg_cron_jobs.sql) |
| RSRC-03 | workers * level * research_bonus formula | static analysis | Read migration function body | YES (20260311000008_resource_production_functions.sql) |
| RSRC-04 | Warehouse cap enforced with LEAST() | static analysis | Read migration function body | YES (20260311000008_resource_production_functions.sql) |
| BLDG-01 | BuildingType enum has 14 values | unit | `flutter test test/unit/building_formulas_test.dart` | YES (building_formulas_test.dart line 71) |
| BLDG-02 | upgradeCost formula: base * 1.5^level | unit | `flutter test test/unit/building_formulas_test.dart` | YES (building_formulas_test.dart lines 13-41) |
| BLDG-03 | upgradeDurationMinutes formula: base * 1.2^level | unit | `flutter test test/unit/building_formulas_test.dart` | YES (building_formulas_test.dart lines 44-68) |
| BLDG-04 | UNIQUE(city_id) enforces one-at-a-time | static analysis | Read migration DDL | YES (20260311000006_create_construction_queue.sql) |
| BLDG-05 | finish_at <= NOW() completion check | static analysis | Read migration function body | YES (20260311000009_construction_functions.sql) |

### Wave 0 Gaps

None — existing test infrastructure covers the formula requirements. No new test files needed for Phase 9. The VERIFICATION.md is the only artifact produced.

---

## Open Questions

1. **Human verification status**
   - What we know: Phase 2 was completed (all plans merged) but the 02-03 SUMMARY notes "Task 3: Human verification pending (checkpoint:human-verify)". The Task 3 human checkpoint in 02-03-PLAN.md was the end-to-end economy loop test.
   - What's unclear: Was human verification of Phase 2 actually performed during Phase 2 execution? The 02-03-SUMMARY.md says "pending". If it was never approved, the VERIFICATION.md status may be `human_needed` rather than `passed`.
   - Recommendation: The VERIFICATION.md should honestly reflect this. Mark the live-stack truths (pg_cron fires, Realtime updates UI, second-upgrade rejected in UI) as `? NEEDS HUMAN` regardless. The document is the formal record of what was verified and what requires human confirmation.

2. **BLDG-01 scope: 10 vs 14 buildings**
   - What we know: BLDG-01 requires 10 building types. The DB has 14 (10 city + 4 production). The production buildings are implementation-only extras.
   - What's unclear: Should BLDG-01 note be framed as "SATISFIED with note: 4 production buildings added as implementation detail" or simply as "SATISFIED"?
   - Recommendation: Use "SATISFIED (with note)" phrasing. The 4 extra buildings are documented in STATE.md decisions and should not count against the requirement.

---

## Sources

### Primary (HIGH confidence)

All sources are codebase files verified by direct file inspection:

- `supabase/migrations/20260311000004_create_city_resources.sql` — city_resources table schema (RSRC-01, RSRC-04)
- `supabase/migrations/20260311000005_create_city_buildings.sql` — city_buildings table schema with 14-type CHECK (BLDG-01)
- `supabase/migrations/20260311000006_create_construction_queue.sql` — UNIQUE(city_id) constraint (BLDG-04)
- `supabase/migrations/20260311000007_on_city_created_trigger.sql` — seeds 5 resources + 14 buildings on city creation (RSRC-01, BLDG-01)
- `supabase/migrations/20260311000008_resource_production_functions.sql` — `process_resource_tick()` with production formula and warehouse cap (RSRC-02, RSRC-03, RSRC-04)
- `supabase/migrations/20260311000009_construction_functions.sql` — `complete_building_upgrades()` with finish_at check (BLDG-05)
- `supabase/migrations/20260311000010_pg_cron_jobs.sql` — pg_cron job registration for resource-tick and construction-tick (RSRC-02, BLDG-05)
- `supabase/functions/upgrade-building/index.ts` — `calcUpgradeCost()`, `calcUpgradeDurationMinutes()`, one-at-a-time check (BLDG-02, BLDG-03, BLDG-04)
- `lib/core/constants/building_constants.dart` — BuildingType enum (14 values), `upgradeCost()`, `upgradeDurationMinutes()`, costGrowthFactor=1.5, timeGrowthFactor=1.2 (BLDG-01, BLDG-02, BLDG-03)
- `lib/core/constants/resource_constants.dart` — ResourceType enum (5 values), `warehouseCapacity()`, baseWarehouseCapacity=500 (RSRC-01, RSRC-04)
- `lib/features/city/data/buildings_repository.dart` — `upgradeBuilding()` invokes 'upgrade-building' Edge Function (BLDG-02, BLDG-04)
- `lib/features/city/providers/resources_provider.dart` — resourcesStreamProvider streams city_resources (RSRC-01)
- `lib/features/city/providers/buildings_provider.dart` — buildingsStreamProvider streams city_buildings (BLDG-01)
- `lib/features/city/providers/construction_provider.dart` — constructionQueueProvider streams construction_queue (BLDG-04, BLDG-05)
- `test/unit/building_formulas_test.dart` — 16 active tests covering formula correctness for BLDG-02, BLDG-03
- `.planning/phases/02-core-economy/02-01-SUMMARY.md` — Phase 2 Plan 01 execution record
- `.planning/phases/02-core-economy/02-03-SUMMARY.md` — Phase 2 Plan 03 execution record
- `.planning/phases/01-foundation/01-VERIFICATION.md` — VERIFICATION.md format reference
- `.planning/phases/08-bug-fixes-timer-guards/08-VERIFICATION.md` — VERIFICATION.md format reference

### Secondary (MEDIUM confidence)

- `.planning/STATE.md` — key decisions log confirming implementation choices (production buildings in CHECK constraint, BASE_COSTS/BASE_TIMES sync between TS and Dart)
- `.planning/phases/02-core-economy/02-RESEARCH.md` — original Phase 2 research with pitfalls and implementation rationale

---

## Metadata

**Confidence breakdown:**
- Requirements-to-code mapping: HIGH — all 9 requirements traced to specific files and lines through direct file inspection
- VERIFICATION.md format: HIGH — 7 existing verification documents provide clear format template
- Human-verification items: HIGH — consistent with Phase 1 pattern; runtime behaviors cannot be verified statically
- Open question (human approval status): MEDIUM — ambiguity about whether Phase 2 end-to-end human test was ever completed

**Research date:** 2026-03-12
**Valid until:** N/A — this is a static codebase audit, not library documentation. Valid as long as Phase 2 files are unchanged.
