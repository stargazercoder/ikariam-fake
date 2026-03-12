---
phase: 3
slug: world-map
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-11
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK, Dart 3.10.1) |
| **Config file** | none (uses default flutter test runner) |
| **Quick run command** | `flutter test test/unit/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/unit/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 0 | MAP-01 | unit | `flutter test test/unit/map_models_test.dart` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 0 | MAP-02 | unit | `flutter test test/unit/map_models_test.dart` | ❌ W0 | ⬜ pending |
| 03-01-03 | 01 | 0 | MAP-03 | unit | `flutter test test/unit/map_models_test.dart` | ❌ W0 | ⬜ pending |
| 03-01-04 | 01 | 0 | MAP-04 | unit | `flutter test test/unit/city_grid_test.dart` | ❌ W0 | ⬜ pending |
| 03-01-05 | 01 | 0 | MAP-05 | widget | `flutter test test/widget/world_map_smoke_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/unit/map_models_test.dart` — stubs for MAP-01, MAP-02, MAP-03 (Island.fromJson, IslandDetail slot aggregation)
- [ ] `test/unit/city_grid_test.dart` — stubs for MAP-04 (kBuildingPositions completeness and uniqueness)
- [ ] `test/widget/world_map_smoke_test.dart` — stubs for MAP-05 (WorldMapScreen renders with mocked provider)

*Existing infrastructure covers framework needs — no new test packages required.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Pan and zoom gestures work on world map | MAP-05 | Gesture interaction requires physical touch/mouse | Open world map, pinch to zoom, drag to pan — verify smooth behavior |
| Tapping island navigates to island tab | MAP-01 | Navigation + tab switch requires UI interaction | Tap any island square, verify Island tab activates with correct island |
| Tapping owned city slot switches to city tab | MAP-03 | Cross-tab navigation requires UI flow | On island view, tap player's city slot, verify City tab opens |
| Bottom navigation bar persists across tabs | MAP-05 | Visual persistence is a layout concern | Switch between all 3 tabs, verify bottom bar always visible |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
