# Requirements: Ikariam Clone v1.3

**Defined:** 2026-03-17
**Core Value:** Players can build and manage cities, gather resources, and engage in real-time turn-based warfare — the core loop of build, expand, and conquer must feel satisfying and strategically meaningful.

## v1.3 Requirements

Requirements for v1.3 Bots, Testing & Automation. Each maps to roadmap phases.

### Bot System

- [x] **BOT-01**: 20 bot accounts exist on the world map with varied military, building, and resource levels
- [x] **BOT-02**: Bots periodically attack neighboring cities via pg_cron schedule
- [x] **BOT-03**: Bots retrain armies after suffering losses
- [x] **BOT-04**: Bots upgrade island resource buildings they occupy
- [x] **BOT-05**: Bots upgrade buildings in their own cities
- [x] **BOT-06**: Bot behaviors are guarded by is_bot flag and invisible to non-admin players

### GodMode Dashboard

- [x] **GOD-01**: Admin sees all players' resources, armies, and building levels in a single full-page dashboard table
- [x] **GOD-02**: Admin can pause, resume, and adjust speed of bot behaviors
- [x] **GOD-03**: Admin sees a live event feed showing battles, trades, and espionage actions
- [x] **GOD-04**: Admin can modify any player's resources and army counts
- [x] **GOD-05**: GodMode access is secured via is_admin check at Postgres layer — service_role key never reaches Flutter client

### Seed Data

- [x] **SEED-01**: Project init creates 20 bot accounts with diverse game states (varied resources, buildings, armies)
- [x] **SEED-02**: Seed script is idempotent — can be re-run without conflicts or duplicate data

### Testing

- [x] **TEST-01**: Critical Edge Functions are unit tested with Deno test runner
- [ ] **TEST-02**: GodMode and critical Flutter widgets are tested with Riverpod ProviderContainer

### Automation

- [ ] **AUTO-01**: Single command runs DB reset + seed + Edge Functions serve + Flutter build
- [ ] **AUTO-02**: GitHub Actions CI pipeline runs tests, lint, and build automatically on push

## v1.3+ Future Requirements

### Bot Intelligence

- **BOT-F01**: Bot archetypes (militarist, economist, builder) with weighted decision-making
- **BOT-F02**: Bots form temporary alliances and coordinate attacks
- **BOT-F03**: Bot difficulty scaling based on player progression

### Admin Tools

- **GOD-F01**: GodMode world map overlay showing all bot paths and battle zones
- **GOD-F02**: Time-travel replay of past game events
- **GOD-F03**: Economy analytics dashboard (resource flow graphs)

### Previously Deferred (from v1.2)

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
| LLM/AI-powered bot decisions | Overcomplicated for 20 bots; simple pg_cron rules sufficient |
| Bot-to-bot diplomacy | Requires alliance system (not yet built) |
| Bot trading behavior | Trading adds complexity; focus on combat + building first |
| Mobile CI/CD (iOS/Android builds) | Web-only for now |
| Performance load testing | Premature — bot system is dev-mode, not production scale |
| Counter-espionage | Keep simple; add defensive spy mechanics later |
| Spy unit training | Espionage uses instant action; unit-based spying deferred |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BOT-01 | Phase 18 | Complete |
| BOT-06 | Phase 18 | Complete |
| BOT-02 | Phase 19 | Complete |
| BOT-03 | Phase 19 | Complete |
| BOT-04 | Phase 19 | Complete |
| BOT-05 | Phase 19 | Complete |
| SEED-01 | Phase 20 | Complete |
| SEED-02 | Phase 20 | Complete |
| GOD-05 | Phase 21 | Complete |
| GOD-01 | Phase 22 | Complete |
| GOD-02 | Phase 22 | Complete |
| GOD-03 | Phase 22 | Complete |
| GOD-04 | Phase 22 | Complete |
| TEST-01 | Phase 23 | Complete |
| TEST-02 | Phase 23 | Pending |
| AUTO-01 | Phase 24 | Pending |
| AUTO-02 | Phase 24 | Pending |

**Coverage:**
- v1.3 requirements: 17 total
- Mapped to phases: 17
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-17*
*Last updated: 2026-03-17 — traceability populated after roadmap creation*
