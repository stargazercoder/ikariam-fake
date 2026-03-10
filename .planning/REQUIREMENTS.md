# Requirements: Ikariam Clone

**Defined:** 2026-03-11
**Core Value:** Players can build and manage cities, gather resources, and engage in real-time turn-based warfare — the core loop of build, expand, and conquer must feel satisfying and strategically meaningful.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Authentication

- [x] **AUTH-01**: User can sign up with email and password via Supabase Auth
- [x] **AUTH-02**: User can log in and session persists across browser refresh
- [ ] **AUTH-03**: User can create player profile with display name and avatar
- [x] **AUTH-04**: User gets a city automatically placed on an island on first login

### Resources

- [ ] **RSRC-01**: Cities produce 5 resource types: Wood, Marble, Crystal, Sulfur, Gold
- [ ] **RSRC-02**: Resource production runs server-side via pg_cron every 5 minutes
- [ ] **RSRC-03**: Production rate calculated as workers x building_level x research_bonus
- [ ] **RSRC-04**: Resources capped by Warehouse building capacity

### Buildings

- [ ] **BLDG-01**: City supports 10 building types: Town Hall, Warehouse, Barracks, Shipyard, Academy, Embassy, Trading Port, Town Wall, Hideout, Tavern
- [ ] **BLDG-02**: Buildings can be upgraded with cost formula (base_cost x 1.5^level)
- [ ] **BLDG-03**: Building upgrade takes time calculated as base_time x 1.2^level (minutes)
- [ ] **BLDG-04**: Only one construction can run at a time per city
- [ ] **BLDG-05**: Construction completion detected and applied by pg_cron tick

### World Map

- [ ] **MAP-01**: World map displays islands on a grid coordinate system
- [ ] **MAP-02**: Each island contains 16-17 city slots, 1 wood resource, and 1 luxury resource (marble/crystal/sulfur)
- [ ] **MAP-03**: Island view shows all cities on the island and resource gathering areas
- [ ] **MAP-04**: City view displays buildings on a grid layout
- [ ] **MAP-05**: Map renders as simple 2D grid (not isometric)

### Military

- [ ] **MIL-01**: 8 land unit types trainable from Barracks (Hoplite, Phalanx, Archer, Cavalry, Catapult, Mortar, Medic, Cook)
- [ ] **MIL-02**: 5 naval unit types buildable from Shipyard (Cargo Ship, Ram Ship, Catapult Ship, Mortar Ship, Diving Boat)
- [ ] **MIL-03**: Each unit type requires specific building level to unlock
- [ ] **MIL-04**: Training queue with time-based completion via pg_cron
- [ ] **MIL-05**: Troops can be dispatched to other cities with travel time based on distance

### Combat

- [ ] **CMBT-01**: Battles resolve in turns, each turn lasting 5 minutes
- [ ] **CMBT-02**: Each turn a portion of armies engage, survivors carry to next turn
- [ ] **CMBT-03**: Naval battle phase occurs before land battle phase
- [ ] **CMBT-04**: Battle reports sent to both attacker and defender via Supabase Realtime
- [ ] **CMBT-05**: All battle calculations run server-side (Edge Function or pg function)

### Infrastructure

- [ ] **INFR-01**: Flutter web shows splash screen during CanvasKit load instead of blank page
- [x] **INFR-02**: All game state mutations run server-side (no client-side calculations)
- [x] **INFR-03**: RLS (Row Level Security) enabled on every database table from creation

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Research System

- **RSCH-01**: 4 research branches: Seafaring, Economy, Science, Military
- **RSCH-02**: Academy building generates research points hourly
- **RSCH-03**: Research prerequisite/tech tree with dependencies
- **RSCH-04**: Research completion tracked by pg_cron

### Social & Diplomacy

- **SOCL-01**: Alliance system with create/join and roles (Leader, General, Diplomat, Member)
- **SOCL-02**: Player-to-player private messaging
- **SOCL-03**: Alliance chat channel via Supabase Realtime
- **SOCL-04**: War declarations and NAP (non-aggression pact) agreements

### Combat Extensions

- **CMBT-06**: Players can send reinforcements during active battles
- **CMBT-07**: Battle outcomes include pillage (steal resources)
- **CMBT-08**: Battle outcomes include occupation (city takeover under conditions)

### Economy Extensions

- **ECON-01**: Marketplace with buy/sell order book
- **ECON-02**: Player-to-player resource trading via cargo ships
- **ECON-03**: Island shared resource buildings (cooperative mechanic)

### Rankings

- **RANK-01**: Score calculation (building + research + military + gold points)
- **RANK-02**: Multiple leaderboards (total, military, naval, alliance, island)

### Maintenance

- **MAINT-01**: Ghost city cleanup after 30 days of inactivity

## Out of Scope

| Feature | Reason |
|---------|--------|
| Isometric rendering | High complexity; 2D grid sufficient for v1 |
| OAuth login (Google/Apple) | Email/password sufficient for small community |
| Mobile/Desktop native apps | Web-only for v1; Flutter enables future expansion |
| Multi-language (i18n) | English only for v1 |
| Drag & drop building placement | Deferred UX enhancement |
| Premium/monetization | No P2W for small community game |
| Museum building | Low priority decorative feature |
| Animated construction effects | Visual polish deferred |
| Espionage system | Complex feature, requires stable combat first |
| Barbarian villages (PvE) | Requires combat system maturity |
| Server wipes / seasonal resets | Anti-pattern for small community |
| WASM renderer | CanvasKit sufficient for v1; WASM deferred |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUTH-01 | Phase 1 | Complete |
| AUTH-02 | Phase 1 | Complete |
| AUTH-03 | Phase 1 | Pending |
| AUTH-04 | Phase 1 | Complete |
| INFR-02 | Phase 1 | Complete |
| INFR-03 | Phase 1 | Complete |
| RSRC-01 | Phase 2 | Pending |
| RSRC-02 | Phase 2 | Pending |
| RSRC-03 | Phase 2 | Pending |
| RSRC-04 | Phase 2 | Pending |
| BLDG-01 | Phase 2 | Pending |
| BLDG-02 | Phase 2 | Pending |
| BLDG-03 | Phase 2 | Pending |
| BLDG-04 | Phase 2 | Pending |
| BLDG-05 | Phase 2 | Pending |
| MAP-01 | Phase 3 | Pending |
| MAP-02 | Phase 3 | Pending |
| MAP-03 | Phase 3 | Pending |
| MAP-04 | Phase 3 | Pending |
| MAP-05 | Phase 3 | Pending |
| MIL-01 | Phase 4 | Pending |
| MIL-02 | Phase 4 | Pending |
| MIL-03 | Phase 4 | Pending |
| MIL-04 | Phase 4 | Pending |
| MIL-05 | Phase 4 | Pending |
| CMBT-01 | Phase 5 | Pending |
| CMBT-02 | Phase 5 | Pending |
| CMBT-03 | Phase 5 | Pending |
| CMBT-04 | Phase 5 | Pending |
| CMBT-05 | Phase 5 | Pending |
| INFR-01 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 31 total
- Mapped to phases: 31
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-11*
*Last updated: 2026-03-11 after roadmap creation*
