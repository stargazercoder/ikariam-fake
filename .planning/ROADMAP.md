# Roadmap: Ikariam Clone

## Milestones

- ✅ **v0.1.0 MVP** — Phases 1-9 (shipped 2026-03-12)
- 🚧 **v1.1 Economy & Combat Depth** — Phases 10-12 (in progress)

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

### 🚧 v1.1 Economy & Combat Depth (In Progress)

**Milestone Goal:** Deepen the economic loop with happiness/population/tax mechanics and make combat victories meaningful with pillage rewards and improved battle reports.

- [x] **Phase 10: Economy Foundation** — Happiness, population growth, and tax income driven by tavern wine consumption (completed 2026-03-13)
- [x] **Phase 11: Island Upgrades + Resource Rate UI** — Shared island resource building levels and hourly production rate display (completed 2026-03-13)
- [ ] **Phase 12: Combat Depth** — Pillage resources on battle victory and turn-by-turn battle report visualization

## Phase Details

### Phase 10: Economy Foundation
**Goal**: Players can manage city happiness through the tavern, watch their population grow over time, and earn gold tax income that scales with city size
**Depends on**: Phase 9 (v0.1.0 complete)
**Requirements**: ECON-01, ECON-02, ECON-03, ECON-04, ECON-05
**Success Criteria** (what must be TRUE):
  1. Player can open the Tavern screen and see their current happiness score for the city
  2. Player can move the wine spending rate slider and see the projected happiness change
  3. Every 5-minute pg_cron tick, wine is consumed from city resources at the configured rate and happiness updates accordingly
  4. When happiness is positive, the city's population increases each tick (stored as NUMERIC, not INTEGER)
  5. Idle citizens (population minus assigned workers) generate 3 gold/hour and that gold appears in the city resource bar each tick
**Plans:** 3/3 plans complete
Plans:
- [ ] 10-01-PLAN.md — Schema migration: cities economy columns, wine resource type, rewritten process_resource_tick() with 5-step economy loop
- [ ] 10-02-PLAN.md — set-wine-rate Edge Function + CityRepository.setWineRate method
- [ ] 10-03-PLAN.md — Flutter UI: wine in resource bar, happiness indicator, population summary, tavern wine slider

### Phase 11: Island Upgrades + Resource Rate UI
**Goal**: Players can cooperate to upgrade the shared island resource building and see accurate hourly production rates in the resource bar
**Depends on**: Phase 10
**Requirements**: RSRC-01, RSRC-02, RSRC-03, RSRC-04
**Success Criteria** (what must be TRUE):
  1. Player can donate wood on the island view to increase the island's shared resource building level (up to level 10)
  2. After an island upgrade, all cities on that island produce more resources each tick, proportional to the new level multiplier
  3. The main resource bar shows a "+X/hr" label for each resource reflecting the current production rate
  4. Tapping a resource or opening the building screen shows a breakdown of the rate: base rate, building level bonus, island level bonus, and research bonus
**Plans:** 2/2 plans complete
Plans:
- [ ] 11-01-PLAN.md — DB migration (island resource_level column + process_resource_tick() island multiplier) + donate-island-wood Edge Function
- [ ] 11-02-PLAN.md — Flutter UI: Island model extension, production rate provider, +X/hr labels, breakdown sheet, donate wood dialog

### Phase 12: Combat Depth
**Goal**: Winning a battle yields tangible resource rewards for the attacker, and players can review unit losses turn-by-turn in color-coded battle reports
**Depends on**: Phase 11
**Requirements**: CMBT-01, CMBT-02, CMBT-03, CMBT-04
**Success Criteria** (what must be TRUE):
  1. When an attacker wins a battle, a portion of the defender's unprotected resources is transferred to the attacker (delivered home via return unit movement cargo)
  2. Defender's Warehouse and Hideout levels protect a resource floor that cannot be pillaged
  3. Player can open a battle report and see a stacked bar chart showing unit losses per turn for both sides
  4. Each unit type is displayed in a distinct color code throughout the battle report visualization
**Plans:** 2/3 plans executed
Plans:
- [ ] 12-01-PLAN.md — SQL migration: pillage schema (cargo + pillage_result columns), updated resolve_battles() with pillage logic, updated process_arrivals() with cargo delivery, Dart hideout helper
- [ ] 12-02-PLAN.md — Flutter constants + models: unit type color map, Battle.pillageResult + UnitMovement.cargo model extensions
- [ ] 12-03-PLAN.md — Flutter UI: fl_chart stacked bar chart widget for battle losses, pillage result card, battle detail screen integration

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
| 12. Combat Depth | 2/3 | In Progress|  | - |
