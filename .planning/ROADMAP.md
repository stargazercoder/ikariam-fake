# Roadmap: Ikariam Clone

## Milestones

- ✅ **v0.1.0 MVP** — Phases 1-9 (shipped 2026-03-12)
- ✅ **v1.1 Economy & Combat Depth** — Phases 10-12 (shipped 2026-03-15)
- ✅ **v1.2 Espionage, Trading & Polish** — Phases 13-17 (shipped 2026-03-17)
- ✅ **v1.3 Bots, Testing & Automation** — Phases 18-24 (shipped 2026-03-18)
- 🚧 **v1.4 UI Consistency** — Phases 25-28 (in progress)

## Phases

<details>
<summary>✅ v0.1.0 MVP (Phases 1-9) — SHIPPED 2026-03-12</summary>

- [x] Phase 1: Foundation (4/4 plans) — completed 2026-03-10
- [x] Phase 2: Core Economy (4/4 plans) — completed 2026-03-11
- [x] Phase 3: World Map (3/3 plans) — completed 2026-03-11
- [x] Phase 4: Military (4/4 plans) — completed 2026-03-11
- [x] Phase 5: Combat (4/4 plans) — completed 2026-03-11
- [x] Phase 6: Production Hardening (2/2 plans) — completed 2026-03-12
- [x] Phase 7: Test Infrastructure (3/3 plans) — completed 2026-03-12
- [x] Phase 8: Bug Fixes & Timer Guards (2/2 plans) — completed 2026-03-12
- [x] Phase 9: Phase 2 Verification (1/1 plan) — completed 2026-03-12

Full details: [milestones/v0.1.0-ROADMAP.md](milestones/v0.1.0-ROADMAP.md)

</details>

<details>
<summary>✅ v1.1 Economy & Combat Depth (Phases 10-12) — SHIPPED 2026-03-15</summary>

- [x] Phase 10: Economy Foundation (3/3 plans) — completed 2026-03-13
- [x] Phase 11: Island Upgrades + Resource Rate UI (2/2 plans) — completed 2026-03-13
- [x] Phase 12: Combat Depth (3/3 plans) — completed 2026-03-15

Full details: [milestones/v1.1-ROADMAP.md](milestones/v1.1-ROADMAP.md)

</details>

<details>
<summary>✅ v1.2 Espionage, Trading & Polish (Phases 13-17) — SHIPPED 2026-03-17</summary>

- [x] Phase 13: Dev Acceleration (2/2 plans) — completed 2026-03-16
- [x] Phase 14: Movement Visibility (2/2 plans) — completed 2026-03-16
- [x] Phase 15: Resource Trading (2/2 plans) — completed 2026-03-16
- [x] Phase 16: Espionage & City Viewing (3/3 plans) — completed 2026-03-16
- [x] Phase 17: UI Polish (2/2 plans) — completed 2026-03-17

</details>

<details>
<summary>✅ v1.3 Bots, Testing & Automation (Phases 18-24) — SHIPPED 2026-03-18</summary>

- [x] Phase 18: Bot Schema Foundation (1/1 plan) — completed 2026-03-17
- [x] Phase 19: Bot Behavior Engine (2/2 plans) — completed 2026-03-17
- [x] Phase 20: Seed Data (1/1 plan) — completed 2026-03-17
- [x] Phase 21: GodMode Backend (1/1 plan) — completed 2026-03-17
- [x] Phase 22: GodMode Flutter Dashboard (2/2 plans) — completed 2026-03-17
- [x] Phase 23: Unit Tests (2/2 plans) — completed 2026-03-18
- [x] Phase 24: Automation & CI (2/2 plans) — completed 2026-03-18

Full details: [milestones/v1.3-ROADMAP.md](milestones/v1.3-ROADMAP.md)

</details>

### 🚧 v1.4 UI Consistency (In Progress)

**Milestone Goal:** Establish consistent visual language across all screens — resource and building icons with canonical colors, unified building detail sheets with dynamic per-building content, battle UI improvements, and removal of redundant title text from city screens.

- [x] **Phase 25: Visual Constants** — Define and apply resource and building icon/color system across all UI (completed 2026-03-19)
- [x] **Phase 26: Building Detail Sheet** — Unified scrollable bottom sheet with dynamic per-building content (completed 2026-03-20)
- [ ] **Phase 27: Battle UI Improvements** — Pillage amounts in reports and carry capacity in dispatch dialog
- [ ] **Phase 28: City Screen Cleanup** — Remove city name and player name title texts from all city screens

## Phase Details

### Phase 25: Visual Constants
**Goal**: Every resource and building type has a canonical icon and color, used consistently in every screen that displays them.
**Depends on**: Phase 24 (previous milestone complete)
**Requirements**: ICON-01, ICON-02, ICON-03
**Success Criteria** (what must be TRUE):
  1. Resource bar shows colored circle + letter icons (W, M, C, S, G) for all 5 resource types
  2. Every screen that displays resources (production breakdown, trade dialog, battle report) uses the same resource icons
  3. Each of the 10 building types displays the same icon and color wherever it appears in the UI
  4. No screen uses ad-hoc resource or building representations that differ from the canonical set
**Plans**: 1 plan

Plans:
- [ ] 25-01-PLAN.md — Define visual constants, ResourceBadge widget, and replace all ad-hoc icon/color usage

### Phase 26: Building Detail Sheet
**Goal**: Tapping any building opens a large, scrollable bottom sheet with building-specific information and actions, using a consistent layout structure throughout.
**Depends on**: Phase 25
**Requirements**: BLDG-01, BLDG-02, BLDG-03
**Success Criteria** (what must be TRUE):
  1. Tapping any building on the city grid opens a bottom sheet (no buildings navigate away or do nothing)
  2. The bottom sheet scrolls and shows a header with the building name and icon, a stats section, and an actions section
  3. Tavern sheet shows happiness boost and wine consumption controls
  4. Barracks sheet shows unit training queue and train-unit controls; Shipyard sheet shows ship building equivalents
  5. Resource production buildings show current production rate; all buildings show upgrade/downgrade options
**Plans**: 2 plans

Plans:
- [ ] 26-01-PLAN.md — Shared bottom sheet scaffold (header, stats, actions layout) + simple building stats + BuildingCell wiring
- [ ] 26-02-PLAN.md — Dynamic content per building type (tavern, warehouse, production, barracks, shipyard) + downgrade backend + cleanup

### Phase 27: Battle UI Improvements
**Goal**: Battle reports show what resources were pillaged, and the dispatch dialog shows how much loot the selected army can carry.
**Depends on**: Phase 25
**Requirements**: BTUI-01, BTUI-02
**Success Criteria** (what must be TRUE):
  1. A battle report for a victorious attack shows the pillaged amount for each resource type
  2. The dispatch dialog shows a live total carry capacity that updates as the player adds or removes units
  3. A player can see at a glance whether their army can carry their desired loot before dispatching
**Plans**: TBD

Plans:
- [ ] 27-01: Add pillage resource breakdown to battle report UI and dispatch carry capacity indicator

### Phase 28: City Screen Cleanup
**Goal**: City screens present only gameplay content — city name and player name title texts are removed from all city screen views.
**Depends on**: Phase 25
**Requirements**: CLNP-01
**Success Criteria** (what must be TRUE):
  1. No city name or player name text appears as a standalone title on any city screen (own or foreign)
  2. The city grid screen has no AppBar title text showing city or player names
  3. Removing the titles does not break navigation, ownership color borders, or any other UI element
**Plans**: TBD

Plans:
- [ ] 28-01: Remove city and player name title text from all city screen widgets

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation | v0.1.0 | 4/4 | Complete | 2026-03-10 |
| 2. Core Economy | v0.1.0 | 4/4 | Complete | 2026-03-11 |
| 3. World Map | v0.1.0 | 3/3 | Complete | 2026-03-11 |
| 4. Military | v0.1.0 | 4/4 | Complete | 2026-03-11 |
| 5. Combat | v0.1.0 | 4/4 | Complete | 2026-03-11 |
| 6. Production Hardening | v0.1.0 | 2/2 | Complete | 2026-03-12 |
| 7. Test Infrastructure | v0.1.0 | 3/3 | Complete | 2026-03-12 |
| 8. Bug Fixes & Timer Guards | v0.1.0 | 2/2 | Complete | 2026-03-12 |
| 9. Phase 2 Verification | v0.1.0 | 1/1 | Complete | 2026-03-12 |
| 10. Economy Foundation | v1.1 | 3/3 | Complete | 2026-03-13 |
| 11. Island Upgrades + Resource Rate UI | v1.1 | 2/2 | Complete | 2026-03-13 |
| 12. Combat Depth | v1.1 | 3/3 | Complete | 2026-03-15 |
| 13. Dev Acceleration | v1.2 | 2/2 | Complete | 2026-03-16 |
| 14. Movement Visibility | v1.2 | 2/2 | Complete | 2026-03-16 |
| 15. Resource Trading | v1.2 | 2/2 | Complete | 2026-03-16 |
| 16. Espionage & City Viewing | v1.2 | 3/3 | Complete | 2026-03-16 |
| 17. UI Polish | v1.2 | 2/2 | Complete | 2026-03-17 |
| 18. Bot Schema Foundation | v1.3 | 1/1 | Complete | 2026-03-17 |
| 19. Bot Behavior Engine | v1.3 | 2/2 | Complete | 2026-03-17 |
| 20. Seed Data | v1.3 | 1/1 | Complete | 2026-03-17 |
| 21. GodMode Backend | v1.3 | 1/1 | Complete | 2026-03-17 |
| 22. GodMode Flutter Dashboard | v1.3 | 2/2 | Complete | 2026-03-17 |
| 23. Unit Tests | v1.3 | 2/2 | Complete | 2026-03-18 |
| 24. Automation & CI | v1.3 | 2/2 | Complete | 2026-03-18 |
| 25. Visual Constants | 1/1 | Complete    | 2026-03-19 | - |
| 26. Building Detail Sheet | 2/2 | Complete   | 2026-03-20 | - |
| 27. Battle UI Improvements | v1.4 | 0/TBD | Not started | - |
| 28. City Screen Cleanup | v1.4 | 0/TBD | Not started | - |
