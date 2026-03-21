---
phase: 27-battle-ui-improvements
verified: 2026-03-21T12:33:58Z
status: passed
score: 4/4 must-haves verified
re_verification: false
---

# Phase 27: Battle UI Improvements Verification Report

**Phase Goal:** Battle reports show what resources were pillaged, and the dispatch dialog shows how much loot the selected army can carry.
**Verified:** 2026-03-21T12:33:58Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #   | Truth                                                                                              | Status     | Evidence                                                                                      |
| --- | -------------------------------------------------------------------------------------------------- | ---------- | --------------------------------------------------------------------------------------------- |
| 1   | Battle report for a victorious attack shows pillaged amount per resource type (already implemented) | ✓ VERIFIED | `PillageResultCard` in `pillage_result_card.dart` renders `Resources gained:`/`Resources lost:` and iterates `pillageResult!.entries`; wired at `battle_detail_screen.dart:80` |
| 2   | Dispatch dialog shows a live total carry capacity that updates as the player adds or removes cargo ships | ✓ VERIFIED | `_CargoCapacityRow` at `dispatch_screen.dart:384` reads `_dispatchControllers` via `controllers[UnitType.cargoShip.dbName]`; parent `onChanged: () => setState(() {})` triggers rebuild |
| 3   | When no cargo ships are selected, dispatch dialog shows 0 capacity with warning text              | ✓ VERIFIED | `dispatch_screen.dart:459`: `'No cargo ships \u2014 army cannot carry loot'` rendered in orange italic when `selected == 0` |
| 4   | cargoCapacityPerShip constant equals 500 in Dart, matching SQL v_cargo_cap formula                | ✓ VERIFIED | `unit_constants.dart:182`: `const int cargoCapacityPerShip = 500;` with sync comment at line 181; unit test passes (`flutter test` exits 0) |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact                                          | Expected                                          | Status     | Details                                                              |
| ------------------------------------------------- | ------------------------------------------------- | ---------- | -------------------------------------------------------------------- |
| `lib/core/constants/unit_constants.dart`          | `cargoCapacityPerShip = 500` constant             | ✓ VERIFIED | Line 182: `const int cargoCapacityPerShip = 500;` with sync comment  |
| `lib/features/military/screens/dispatch_screen.dart` | `_CargoCapacityRow` widget rendering carry capacity | ✓ VERIFIED | Class at line 384; instantiated at line 213 with `controllers` + `roster` |
| `test/unit/unit_constants_test.dart`              | Test for `cargoCapacityPerShip` constant          | ✓ VERIFIED | Lines 83–92: `cargo capacity` group, 2 tests, all pass               |
| `test/widget/pillage_result_card_test.dart`       | Wave 0 stub tests for BTUI-01 verification        | ✓ VERIFIED | 4 `skip: true` stubs covering attacker, defender, null, per-resource |
| `test/widget/dispatch_capacity_test.dart`         | Wave 0 stub tests for BTUI-02 capacity row        | ✓ VERIFIED | 3 `skip: true` stubs covering 0 ships, N ships, hidden state         |

### Key Link Verification

| From                        | To                               | Via                                      | Status     | Details                                                   |
| --------------------------- | -------------------------------- | ---------------------------------------- | ---------- | --------------------------------------------------------- |
| `dispatch_screen.dart`      | `unit_constants.dart`            | `import '../../../core/constants/unit_constants.dart'` | ✓ WIRED | Line 7; `cargoCapacityPerShip` used at lines 416–417     |
| `dispatch_screen.dart`      | `_dispatchControllers['cargo_ship']` | `controllers[UnitType.cargoShip.dbName]` in `_CargoCapacityRow.build()` | ✓ WIRED | Line 394; value read and used to compute `capacity`      |

### Requirements Coverage

| Requirement | Source Plan  | Description                                                                 | Status      | Evidence                                                            |
| ----------- | ------------ | --------------------------------------------------------------------------- | ----------- | ------------------------------------------------------------------- |
| BTUI-01     | 27-01-PLAN.md | Battle report shows pillaged resource amounts broken down by resource type  | ✓ SATISFIED | `PillageResultCard` renders per-resource breakdown; wired in `battle_detail_screen.dart:80`; Wave 0 stubs in `pillage_result_card_test.dart` |
| BTUI-02     | 27-01-PLAN.md | Dispatch dialog shows total carry capacity of selected units, updating live  | ✓ SATISFIED | `_CargoCapacityRow` at `dispatch_screen.dart:213`; reads live from `_dispatchControllers`; shows `$capacity / $maxCapacity`; Wave 0 stubs in `dispatch_capacity_test.dart` |

No orphaned requirements — both BTUI-01 and BTUI-02 are claimed by `27-01-PLAN.md` and marked Complete in REQUIREMENTS.md.

### Anti-Patterns Found

None. No TODO/FIXME/HACK/placeholder comments in production files (`unit_constants.dart`, `dispatch_screen.dart`). Wave 0 test stubs contain TODO comments intentionally (skip: true pattern is the documented convention).

### Human Verification Required

#### 1. Live capacity update in running app

**Test:** Open dispatch dialog for a city with cargo ships. Change the cargo ship count up and down.
**Expected:** The "Carry Capacity" card updates in real time showing `X / Y` where X changes with each keystroke.
**Why human:** Cannot verify `setState` rebuild cycle behavior programmatically from static analysis.

#### 2. Zero-ship warning visibility

**Test:** Set cargo ship count to 0 in a dispatch dialog that has cargo ships available in the roster.
**Expected:** Orange italic text "No cargo ships — army cannot carry loot" appears below the capacity line.
**Why human:** Color and italic style require visual inspection.

#### 3. Carry Capacity row hidden when no cargo ships in roster

**Test:** Open dispatch dialog for a city that owns zero cargo ships (none in roster).
**Expected:** The "Carry Capacity" card does not appear at all.
**Why human:** Requires a city without cargo ships to test the `maxShips == 0` branch.

#### 4. Battle report pillage breakdown visibility

**Test:** Complete a victorious attack that pillages resources. View the battle report.
**Expected:** A "Resources gained:" section lists each resource type and amount pillaged.
**Why human:** Requires a live battle result; BTUI-01 was pre-existing and verified via code inspection only.

### Gaps Summary

No gaps. All 4 must-have truths are verified, all 5 artifacts exist and are substantive, both key links are wired, and both requirement IDs (BTUI-01, BTUI-02) are fully satisfied. The flutter unit test suite (11 tests) passes; the Wave 0 stub tests (7 tests, all skipped) pass correctly.

---

_Verified: 2026-03-21T12:33:58Z_
_Verifier: Claude (gsd-verifier)_
