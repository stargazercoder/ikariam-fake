# Requirements: Ikariam Clone v1.4

**Defined:** 2026-03-19
**Core Value:** Players can build and manage cities, gather resources, and engage in real-time turn-based warfare — the core loop of build, expand, and conquer must feel satisfying and strategically meaningful.

## v1.4 Requirements

Requirements for v1.4 UI Consistency. Each maps to roadmap phases.

### Visual Constants

- [ ] **ICON-01**: 5 resource types (Wood, Marble, Crystal, Sulfur, Gold) are displayed with colored circle + letter icons consistently across all UI
- [ ] **ICON-02**: 10 building types have consistent icon and color defined and used across all UI
- [ ] **ICON-03**: Resource bar, production breakdown, trade dialog, and all resource-displaying screens use the new resource icons

### Building Detail

- [ ] **BLDG-01**: Tapping any building opens a large scrollable bottom sheet showing building information
- [ ] **BLDG-02**: Bottom sheet shows dynamic content per building type (upgrade/downgrade, tavern→happiness boost, barracks→unit training, shipyard→ship building, resource spots→production rates)
- [ ] **BLDG-03**: All building detail sheets use the same layout structure (header, stats, actions)

### Battle UI

- [ ] **BTUI-01**: Battle report shows pillaged resource amounts broken down by resource type
- [ ] **BTUI-02**: Dispatch dialog shows total carry capacity (max lootable amount) of selected units, updating live as units are selected

### Cleanup

- [ ] **CLNP-01**: All city screens have city name and player name title texts removed

## v1.4+ Future Requirements

### Visual Enhancements

- **ICON-F01**: Animated resource icons (shimmer on production)
- **ICON-F02**: Building construction progress overlay on building icons
- **BLDG-F01**: Building comparison view (current level vs next level stats side-by-side)

### Previously Deferred (from v1.3)

- **TRAD-02**: Marketplace with buy/sell orders (order book system)
- **CMBT-05**: Battle outcome: occupation (city takeover)
- **CMBT-06**: Players can send reinforcements during ongoing battles
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
| Custom icon assets (SVG/PNG) | Renkli daire + harf + Material Icons yeterli; asset management overhead gereksiz |
| Building drag & drop reordering | UX enhancement deferred |
| City/player name display redesign | Names removed now; will be re-added with proper design later |
| Isometric building rendering | 2D grid sufficient; visual upgrade deferred |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| ICON-01 | - | Pending |
| ICON-02 | - | Pending |
| ICON-03 | - | Pending |
| BLDG-01 | - | Pending |
| BLDG-02 | - | Pending |
| BLDG-03 | - | Pending |
| BTUI-01 | - | Pending |
| BTUI-02 | - | Pending |
| CLNP-01 | - | Pending |

**Coverage:**
- v1.4 requirements: 9 total
- Mapped to phases: 0
- Unmapped: 9 ⚠️

---
*Requirements defined: 2026-03-19*
*Last updated: 2026-03-19 after initial definition*
