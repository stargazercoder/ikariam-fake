# Roadmap: Ikariam Clone

## Milestones

- ✅ **v0.1.0 MVP** — Phases 1-9 (shipped 2026-03-12)
- ✅ **v1.1 Economy & Combat Depth** — Phases 10-12 (shipped 2026-03-15)
- 🔄 **v1.2 Espionage, Trading & Polish** — Phases 13-17 (in progress)

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

### v1.2 Espionage, Trading & Polish (Phases 13-17)

- [x] **Phase 13: Dev Acceleration** — Bulk unit spawning and 5x faster timers in dev toolbar (completed 2026-03-16)
- [x] **Phase 14: Movement Visibility** — Armies and cargo in transit shown with destinations, ETAs, and carried resources (completed 2026-03-16)
- [x] **Phase 15: Resource Trading** — Send resources to other players via cargo ships with travel time (completed 2026-03-16)
- [ ] **Phase 16: Espionage & City Viewing** — Spy on enemy cities and view read-only city screens
- [ ] **Phase 17: UI Polish** — Clean up city view layout, color-code cities and units

## Phase Details

### Phase 13: Dev Acceleration
**Goal**: Developers can accelerate game testing by spawning multiple unit types at once and running timers at 5x speed
**Depends on**: Nothing (dev-mode-only changes, no production feature dependencies)
**Requirements**: DEVT-01, DEVT-02, DEVT-03
**Success Criteria** (what must be TRUE):
  1. Dev toolbar shows a bulk spawn dialog where multiple unit types and quantities can be selected and spawned in a single action
  2. Unit training completes at 1/5 of normal time when dev mode is active
  3. Unit travel and arrival completes at 1/5 of normal time when dev mode is active
  4. Bulk spawn and timer overrides are invisible and inert in production builds
**Plans:** 2/2 plans complete
Plans:
- [ ] 13-01-PLAN.md — Server-side RPC functions and Edge Function timer speed-ups
- [ ] 13-02-PLAN.md — Flutter dev toolbar bulk spawn dialog and instant complete button

### Phase 14: Movement Visibility
**Goal**: Players can see all their armies and cargo currently in transit with full context (destination, ETA, composition)
**Depends on**: Nothing (reads existing unit_movements table; cargo JSONB column already present)
**Requirements**: MOVE-01, MOVE-02
**Success Criteria** (what must be TRUE):
  1. Player sees a list of all outgoing army movements showing destination city, arrival ETA, and the unit types and counts in the movement
  2. Player sees returning cargo ships in the same movement list showing the resource amounts being carried (pillage loot or trade cargo)
  3. Movement list updates in real-time as new dispatches are sent and arrivals are confirmed
**Plans:** 2/2 plans complete
Plans:
- [ ] 14-01-PLAN.md — UnitMovement model update, global movements stream, and movement providers
- [ ] 14-02-PLAN.md — Movements screen UI, navigation tab, and end-to-end verification

### Phase 15: Resource Trading
**Goal**: Players can send resources to any other player's city using cargo ships that travel in real time
**Depends on**: Phase 14 (movement visibility confirms cargo display works before adding trade-originated cargo)
**Requirements**: TRAD-01
**Success Criteria** (what must be TRUE):
  1. Player can open a trade dialog from another player's city and specify resource type and amount to send
  2. Sending resources deducts the amount from the sender's warehouse immediately and creates a cargo ship movement
  3. Cargo ships arrive at the destination city after the distance-based travel time and the resources are added to the recipient's warehouse
  4. Both sender and recipient can see the in-transit cargo in their movement lists (Phase 14 visibility)
  5. Trade is blocked if the sender has insufficient resources or the recipient's warehouse would overflow
**Plans:** 2/2 plans complete
Plans:
- [ ] 15-01-PLAN.md — DB migration (trade movement type + deduct_resources RPC) and send-trade Edge Function
- [ ] 15-02-PLAN.md — TradeRepository, TradeDialog with sliders, island screen trade integration, movements screen trade display

### Phase 16: Espionage & City Viewing
**Goal**: Players can spy on enemy cities to gather intelligence and view any player's city layout in read-only mode
**Depends on**: Nothing (espionage is an instant server-side action; read-only city view reads existing city/building data)
**Requirements**: ESPY-01, ESPY-02
**Success Criteria** (what must be TRUE):
  1. Player can trigger a spy action against any enemy city and receive a report showing current resource amounts, building levels, and total army counts
  2. Spy action resolves instantly (no travel time, no spy unit consumed)
  3. Player can navigate to any other player's city screen and see a read-only version of their building grid and city stats
  4. Read-only city view clearly indicates it is not the player's own city (no action buttons, ownership label visible)
**Plans**: TBD

### Phase 17: UI Polish
**Goal**: City view, map, and military screens are visually cleaner and players can instantly distinguish their own vs enemy cities and unit types by color
**Depends on**: Nothing (visual-only changes; no new data dependencies)
**Requirements**: UIPL-01, UIPL-02, UIPL-03
**Success Criteria** (what must be TRUE):
  1. City view screen has no AppBar title bar — the building grid fills the full available vertical space
  2. On the island view and world map, each city slot uses a distinct color to differentiate own city (green), allied cities, and enemy cities
  3. Unit type rows in military screens (training queue, battle reports, army lists) render with the matching color from unitTypeColors for that unit type
  4. Color coding is consistent across all screens that display units or city markers
**Plans**: TBD

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
| 13. Dev Acceleration | 2/2 | Complete    | 2026-03-16 | - |
| 14. Movement Visibility | 2/2 | Complete    | 2026-03-16 | - |
| 15. Resource Trading | 2/2 | Complete   | 2026-03-16 | - |
| 16. Espionage & City Viewing | v1.2 | 0/? | Not started | - |
| 17. UI Polish | v1.2 | 0/? | Not started | - |
