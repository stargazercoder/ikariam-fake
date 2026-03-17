# Requirements: Ikariam Clone v1.2

**Defined:** 2026-03-16
**Core Value:** Players can build and manage cities, gather resources, and engage in real-time turn-based warfare — the core loop of build, expand, and conquer must feel satisfying and strategically meaningful.

## v1.2 Requirements

### Espionage

- [x] **ESPY-01**: User can send a spy to an enemy city to reveal resource amounts, building levels, and army counts
- [x] **ESPY-02**: User can view a read-only version of another player's city screen (buildings layout)

### Trading

- [x] **TRAD-01**: User can send resources to another player's city via cargo ships (with travel time)

### Movement Visibility

- [x] **MOVE-01**: User can see a list of outgoing army movements (attack, return) with destination, ETA, and unit composition
- [x] **MOVE-02**: User can see returning cargo ships with carried resource amounts (pillage loot and trade cargo)

### UI Polish

- [x] **UIPL-01**: City view screen removes the AppBar title for cleaner layout
- [ ] **UIPL-02**: Cities on island/world map use distinct colors to differentiate own vs enemy vs ally
- [ ] **UIPL-03**: Unit types in military screens use subtle color coding consistent with unitTypeColors

### Dev Acceleration

- [x] **DEVT-01**: Dev toolbar supports bulk unit spawning (select multiple types and quantities in one action)
- [x] **DEVT-02**: Unit training times reduced to 1/5 of normal in dev mode
- [x] **DEVT-03**: Unit travel/arrival times reduced to 1/5 of normal in dev mode

## v1.3+ Requirements

### Trading (Advanced)

- **TRAD-02**: Marketplace with buy/sell orders (order book system)

### Combat (Advanced)

- **CMBT-05**: Battle outcome: occupation (city takeover)
- **CMBT-06**: Players can send reinforcements during ongoing battles

### Other Deferred

- **RSCH-01**: Research system with 4 branches (Seafaring, Economy, Science, Military)
- **RSCH-02**: Research prerequisites (tech tree with dependencies)
- **RSCH-03**: Academy building generates research points hourly
- **ALNC-01**: Alliance system (create/join, Embassy, roles)
- **ALNC-02**: Alliance chat and player-to-player messaging
- **ALNC-03**: War declarations and NAP agreements
- **RANK-01**: Ranking system (total score, military, naval, alliance, island)
- **RANK-02**: Score calculation (building + research + military + gold points)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Marketplace order book | Complex economy feature; direct trading first |
| City occupation (takeover) | Requires stable espionage + trading first |
| Counter-espionage | Keep v1.2 simple; add defensive spy mechanics later |
| Alliance-based trading bonuses | Alliance system not yet built |
| Spy unit training | v1.2 espionage uses instant action (no spy unit type); unit-based spying deferred |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DEVT-01 | Phase 13 | Complete |
| DEVT-02 | Phase 13 | Complete |
| DEVT-03 | Phase 13 | Complete |
| MOVE-01 | Phase 14 | Complete |
| MOVE-02 | Phase 14 | Complete |
| TRAD-01 | Phase 15 | Complete |
| ESPY-01 | Phase 16 | Complete |
| ESPY-02 | Phase 16 | Complete |
| UIPL-01 | Phase 17 | Complete |
| UIPL-02 | Phase 17 | Pending |
| UIPL-03 | Phase 17 | Pending |

**Coverage:**
- v1.2 requirements: 11 total
- Mapped to phases: 11
- Unmapped: 0

---
*Requirements defined: 2026-03-16*
*Last updated: 2026-03-16 after roadmap creation (all 11 requirements mapped)*
