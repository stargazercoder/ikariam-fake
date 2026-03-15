---
phase: 12-combat-depth
verified: 2026-03-15T20:00:00Z
status: passed
score: 4/4 success criteria verified
gaps: []
resolution: "CMBT-02 docs-code mismatch resolved by aligning docs to code — Warehouse removed from REQUIREMENTS.md and ROADMAP.md success criterion #2 per user decision (Hideout-only protection is the intended design)"
human_verification:
  - test: "Open a completed battle report with attacker victory and cargo ships present"
    expected: "Stacked bar chart appears showing unit losses per turn, with naval and land sections, each unit type in its distinct color, legend visible. Pillage card shows per-resource breakdown."
    why_human: "Visual layout, color accuracy, and chart interactivity cannot be verified programmatically"
  - test: "Open same battle report as defender"
    expected: "Pillage card shows 'Resources lost:' in red with same amounts; chart renders identically"
    why_human: "isAttacker perspective logic requires a live session with two different user accounts"
---

# Phase 12: Combat Depth — Verification Report

**Phase Goal:** Winning a battle yields tangible resource rewards for the attacker, and players can review unit losses turn-by-turn in color-coded battle reports
**Verified:** 2026-03-15T20:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | When an attacker wins, a portion of defender's unprotected resources is transferred to the attacker via return movement cargo | VERIFIED | `resolve_battles()` in 20260315000001 computes loot, deducts from defender, attaches to return movement INSERT as JSONB cargo; `process_arrivals()` delivers cargo to attacker city on arrival |
| 2 | Defender's Warehouse and Hideout levels protect a resource floor that cannot be pillaged | PARTIAL | Only Hideout is queried. CONTEXT.md documents "Warehouse does NOT provide pillage protection" but REQUIREMENTS.md and ROADMAP.md still say Warehouse + Hideout. Requirement text and success criterion were never updated. |
| 3 | Player can open a battle report and see a stacked bar chart showing unit losses per turn for both sides | VERIFIED | `BattleLossChart` widget renders naval and land stacked BarChart sections; integrated into `battle_detail_screen.dart`; 7 widget tests pass |
| 4 | Each unit type is displayed in a distinct color code throughout the battle report visualization | VERIFIED | `unitTypeColors` map has exactly 13 entries, all distinct (verified by test using `Color.toARGB32()`), used in `_buildRod()` in battle_loss_chart.dart |

**Score:** 3/4 success criteria verified

---

## Required Artifacts

### Plan 01 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `supabase/migrations/20260315000001_pillage_schema_and_functions.sql` | Cargo column + pillage_result column + updated resolve_battles() + updated process_arrivals() | VERIFIED | File exists (702 lines). Contains: `ALTER TABLE unit_movements ADD COLUMN cargo JSONB`, `ALTER TABLE battles ADD COLUMN pillage_result JSONB`, `CREATE OR REPLACE FUNCTION resolve_battles()` with full pillage block (P1–P7), `CREATE OR REPLACE FUNCTION process_arrivals()` with cargo delivery branch |
| `lib/core/constants/building_constants.dart` | `hideoutProtectionFloor(int? level)` Dart helper | VERIFIED | Function exists at line 234. Returns 50 for null, `(100.0 * pow(1.5, level)).floor()` otherwise. Matches SQL CASE formula exactly. |
| `test/hideout_protection_test.dart` | 5 TDD test cases | VERIFIED | All 5 cases present: null=50, level 0=100, level 1=150, level 5=759, level 10=5766 |

### Plan 02 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/core/constants/unit_constants.dart` | `unitTypeColors` map with 13 entries | VERIFIED | Map defined at line 219 with 13 entries; `orderedLandTypes` (8) and `orderedNavalTypes` (5) const lists also present |
| `lib/features/battles/models/battle.dart` | `Battle.pillageResult` nullable field | VERIFIED | `final Map<String, int>? pillageResult` at line 52; `fromJson` parses `pillage_result` JSONB with `(v as num).toInt()` safe cast |
| `lib/features/military/models/unit_movement.dart` | `UnitMovement.cargo` nullable field | VERIFIED | `final Map<String, int>? cargo` at line 36; `fromJson` parses `cargo` JSONB with `(v as num).toInt()` safe cast |
| `test/unit_type_colors_test.dart` | 3 tests asserting 13 entries, full coverage, distinct colors | VERIFIED | All 3 tests present; uses `c.toARGB32()` (not deprecated `c.value`) for distinctness check |

### Plan 03 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/features/battles/screens/widgets/battle_loss_chart.dart` | `BattleLossChart` with stacked BarChart | VERIFIED | 380-line file; uses `BarChartRodStackItem` for stacking; `_PhaseChart` private widget handles naval/land separation; legend shows only participating unit types |
| `lib/features/battles/screens/widgets/pillage_result_card.dart` | `PillageResultCard` with per-resource breakdown | VERIFIED | Widget exists; returns `SizedBox.shrink()` on null/empty; shows "Resources gained:" (attacker) or "Resources lost:" (defender); canonical resource sort order enforced |
| `lib/features/battles/screens/battle_detail_screen.dart` | Integrates `BattleLossChart` and `PillageResultCard` | VERIFIED | Both imported and rendered; PillageResultCard gated by `!battle.isActive && battle.pillageResult != null`; BattleLossChart rendered inside `turnsAsync.when(...data:...)` |
| `test/battle_loss_chart_test.dart` | Widget tests for chart and pillage card | VERIFIED | 7 widget tests: 3 for BattleLossChart (with casualties, empty turns, placeholder text) + 4 for PillageResultCard (null, empty map, attacker view, defender view) |
| `pubspec.yaml` | `fl_chart` dependency | VERIFIED | `fl_chart: ^1.2.0` present |

---

## Key Link Verification

### Plan 01 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `resolve_battles()` | `city_resources SELECT FOR UPDATE` | Pillage deduction inside attacker_won branch | VERIFIED | Line 461: `FROM public.city_resources WHERE city_id = b.defender_city_id AND resource_type = v_res_type FOR UPDATE` |
| `resolve_battles()` | `unit_movements.cargo` | INSERT with cargo JSONB on return movement | VERIFIED | Lines 532-548: INSERT includes `cargo` column; value is `CASE WHEN v_loot = '{}' THEN NULL ELSE v_loot END` |
| `process_arrivals()` | `city_resources` | Cargo delivery UPDATE on friendly arrival | VERIFIED | Lines 636-648: `IF m.cargo IS NOT NULL THEN` loop over `jsonb_each_text(m.cargo)` with `UPDATE city_resources SET amount = amount + v_qty` |

### Plan 02 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `unit_constants.dart unitTypeColors` | `battle_loss_chart.dart` | Import and color lookup by UnitType | VERIFIED | `battle_loss_chart.dart` imports `unit_constants.dart`; `unitTypeColors[ut]` used in `_buildRod()` at line 288 |
| `battle.dart pillageResult` | `battle_detail_screen.dart` | Display pillage breakdown | VERIFIED | `battle.pillageResult` passed to `PillageResultCard` at line 81 |

### Plan 03 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `battle_loss_chart.dart` | `unit_constants.dart unitTypeColors` | Color lookup for chart segments | VERIFIED | `import '../../../../core/constants/unit_constants.dart'`; `unitTypeColors[ut]` at line 288 |
| `battle_loss_chart.dart` | `battle_turn.dart BattleTurn` | Reads casualties JSONB per turn | VERIFIED | `t.navalAttackerCasualties`, `t.landAttackerCasualties`, etc. referenced in `_PhaseChart` |
| `battle_detail_screen.dart` | `battle_loss_chart.dart` | Widget composition | VERIFIED | `import 'widgets/battle_loss_chart.dart'` at line 13; `BattleLossChart(turns: turns)` at line 109 |
| `pillage_result_card.dart` | `battle.dart pillageResult` | Reads pillageResult map | VERIFIED | `PillageResultCard(pillageResult: battle.pillageResult, isAttacker: isAttacker)` at line 80 |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| CMBT-01 | 12-01 | Winning attacker pillages resources from defender city (% of unprotected resources) | SATISFIED | Full pillage logic in `resolve_battles()`: hideout floor, pillage ratio, cargo cap, deduction, delivery |
| CMBT-02 | 12-01 | Warehouse + Hideout levels protect a floor of resources from pillage | PARTIAL | Hideout protection implemented and tested. Warehouse protection NOT implemented. CONTEXT.md documents this as a deliberate design change ("Warehouse does NOT provide pillage protection") but REQUIREMENTS.md and ROADMAP.md still reference Warehouse. |
| CMBT-03 | 12-03 | User can view turn-by-turn unit loss chart in battle reports (stacked bar chart) | SATISFIED | BattleLossChart widget with fl_chart BarChart, naval + land sections, integrated into battle_detail_screen.dart |
| CMBT-04 | 12-02, 12-03 | Each unit type has a distinct color code in battle report visualization | SATISFIED | unitTypeColors map with 13 distinct colors, used in chart; verified by test |

**CMBT-02 Note:** The design decision to exclude Warehouse from pillage protection was made in CONTEXT.md before planning began. The PLAN (12-01) correctly reflects Hideout-only in its must_haves. However, REQUIREMENTS.md and ROADMAP.md were never updated. This creates a documentation gap: the requirement text says one thing, the implementation does another. The implementation may be correct per the project owner's intent, but the requirement and success criterion must be reconciled.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `battle_loss_chart.dart` | 17 | Comment: "placeholder text is shown instead" | Info | Describes a legitimate fallback UI — not a code stub |
| `battle_detail_screen.dart` | 172, 459 | Comments: "Loading / not found placeholder", "No turns yet placeholder" | Info | Private widget names describing fallback states — not stubs |

No functional stubs found. No TODO/FIXME in implementation code. No empty handler anti-patterns.

---

## Human Verification Required

### 1. Battle report visual appearance

**Test:** Start the app (`flutter run`), trigger and resolve a battle where the attacker wins with cargo ships present.
**Expected:** Battle detail screen shows (a) a stacked bar chart for naval losses and land losses with attacker/defender side-by-side rods, (b) each unit type in its distinct color, (c) a color legend below each chart, (d) a "Pillage" card with per-resource amounts in green for attacker.
**Why human:** Visual layout, color rendering, chart animation, and tooltip behavior require a running app and real data.

### 2. Defender view of pillage card

**Test:** Open the same completed battle from the defender's account.
**Expected:** "Pillage" card shows "Resources lost:" label with amounts in red; chart shows same data as attacker view.
**Why human:** Requires two user sessions to verify the `isAttacker` perspective logic at runtime.

### 3. Edge case — no cargo ships

**Test:** Win a battle with no surviving cargo ships.
**Expected:** No pillage card appears; battle report shows chart only.
**Why human:** Requires a specific battle configuration to test.

*Note: Plan 03 SUMMARY documents human verification was completed and approved during development.*

---

## Gaps Summary

One gap was found, rooted in a documentation inconsistency rather than a missing implementation:

**CMBT-02 / Success Criterion #2 — Warehouse protection not implemented.**

The ROADMAP success criterion and REQUIREMENTS.md both state that Warehouse levels protect a resource floor from pillage. The actual SQL implementation (`resolve_battles()`) only queries Hideout — Warehouse is never consulted. CONTEXT.md explicitly documents this as a deliberate design decision: "Warehouse does NOT provide pillage protection — only storage capacity. Hideout is the sole protection mechanism."

The implementation is internally consistent and the hideout-only design is coherent. The gap is that the canonical requirement text and roadmap success criterion were never updated to reflect the design decision. This must be resolved either by:
1. Updating REQUIREMENTS.md CMBT-02 and ROADMAP.md success criterion #2 to remove Warehouse (align docs to code), or
2. Implementing Warehouse-based protection in `resolve_battles()` (align code to docs).

This is a documentation/specification gap, not a missing feature per the CONTEXT.md decision, but it blocks marking CMBT-02 as fully satisfied against the stated success criterion.

---

_Verified: 2026-03-15T20:00:00Z_
_Verifier: Claude (gsd-verifier)_
