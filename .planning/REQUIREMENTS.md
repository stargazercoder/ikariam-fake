# Requirements: Ikariam Clone v1.1

**Defined:** 2026-03-13
**Core Value:** Players can build and manage cities, gather resources, and engage in real-time turn-based warfare — the core loop of build, expand, and conquer must feel satisfying and strategically meaningful.

## v1.1 Requirements

### Economy

- [x] **ECON-01**: User can see happiness score for their city (derived from tavern level + wine spending - population)
- [x] **ECON-02**: Population grows automatically when happiness is positive (pg_cron tick, NUMERIC storage)
- [x] **ECON-03**: Idle citizens generate gold tax income (population - workers = idle, idle x 3 gold/hour)
- [x] **ECON-04**: User can adjust wine spending rate in tavern (slider UI, affects happiness per tick)
- [x] **ECON-05**: Tavern consumes wine from city resources each tick based on configured spending rate

### Resources

- [x] **RSRC-01**: User can donate wood to upgrade island shared resource level
- [x] **RSRC-02**: Island resource level multiplier applies to all cities on that island
- [ ] **RSRC-03**: User can see hourly production rate per resource in main resource bar
- [ ] **RSRC-04**: User can see detailed production breakdown per resource (base rate, building level, island bonus, research bonus)

### Combat

- [ ] **CMBT-01**: Winning attacker pillages resources from defender city (% of unprotected resources)
- [ ] **CMBT-02**: Warehouse + Hideout levels protect a floor of resources from pillage
- [ ] **CMBT-03**: User can view turn-by-turn unit loss chart in battle reports (stacked bar chart)
- [ ] **CMBT-04**: Each unit type has a distinct color code in battle report visualization

## v1.2+ Requirements

### Trading

- **TRAD-01**: Player can send resources to another player via cargo ships
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
| City occupation (takeover) | Requires stable pillage first; deferred to v1.2+ |
| Reinforcements during battles | Complex networking; deferred to v1.2+ |
| Real-time trading (no travel time) | Cargo ships with travel time is the intended mechanic |
| Gold trading on marketplace | Prevents laundering; gold is price unit only |
| Negative happiness causing population loss | Anti-feature: death spirals punish beginners in small community |
| Research system | Deferred to v1.2+ |
| Alliance system | Deferred to v1.2+ |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ECON-01 | Phase 10 | Complete |
| ECON-02 | Phase 10 | Complete |
| ECON-03 | Phase 10 | Complete |
| ECON-04 | Phase 10 | Complete |
| ECON-05 | Phase 10 | Complete |
| RSRC-01 | Phase 11 | Complete |
| RSRC-02 | Phase 11 | Complete |
| RSRC-03 | Phase 11 | Pending |
| RSRC-04 | Phase 11 | Pending |
| CMBT-01 | Phase 12 | Pending |
| CMBT-02 | Phase 12 | Pending |
| CMBT-03 | Phase 12 | Pending |
| CMBT-04 | Phase 12 | Pending |

**Coverage:**
- v1.1 requirements: 13 total
- Mapped to phases: 13
- Unmapped: 0

---
*Requirements defined: 2026-03-13*
*Last updated: 2026-03-13 — traceability updated after roadmap creation*
