# Feature Research

**Domain:** Ikariam-style browser-based multiplayer strategy game (ancient Greek island setting)
**Researched:** 2026-03-11
**Confidence:** HIGH (cross-referenced: original Ikariam wiki, Grepolis, Travian, Tribal Wars, browser MMO design literature)

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete or broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Account registration + login | Every game has accounts; players need persistent identity | LOW | Email/password sufficient for v1; Supabase Auth handles this |
| Persistent player profile (name, display) | Players need to be identifiable to others on map and in messages | LOW | Avatar optional for v1 |
| City building with upgradeable buildings | This IS the game's core loop; without it there's nothing to do | HIGH | 15+ building types; exponential cost formula (base x 1.5^level) |
| Multiple resource types (Wood, Marble, Crystal, Sulfur, Gold) | Genre standard; single resource would feel trivial | MEDIUM | 5 types per PROJECT.md; production tied to workers + building level |
| Automatic resource production over time | Players expect to log back in and have accumulated resources | MEDIUM | Server-side pg_cron ticks every 5 min; no client-side idle trust |
| Warehouse / storage capacity limits | Creates meaningful tension and trade decisions | LOW | Caps enforce trading necessity; without caps economy trivializes |
| Construction queue (build one thing at a time) | Players expect to queue construction and log off | LOW | Single queue per city; project already specifies this |
| Research / technology tree | Core genre expectation; progression and power growth | HIGH | 4 branches: Seafaring, Economy, Science, Military; tree with prerequisites |
| World map showing all players/islands | Players must be able to find each other, scout threats, plan expansions | HIGH | 2D grid for v1; island-based; must show city count per island |
| PvP military combat | Core fantasy of the genre: build army, attack enemies | HIGH | Turn-based 5-min turns is the project's chosen model |
| Land military units (at least 4-6 types) | Diverse units create strategic choice; all-same units feels broken | MEDIUM | 8 types defined in PROJECT.md (Hoplite, Phalanx, Archer, etc.) |
| Naval units for sea warfare and transport | Island-based setting demands ships; missing = thematically broken | MEDIUM | 5 types defined in PROJECT.md |
| Battle reports sent after combat | Players must know what happened and why they won/lost | LOW | Supabase Realtime push to both combatants |
| Pillage (steal resources after winning) | Standard genre mechanic; winning combat must have tangible reward | LOW | Already in PROJECT.md requirements |
| Alliance system (create/join guilds) | Social backbone; solo play only = players leave quickly | MEDIUM | Requires Embassy building; roles: Leader, General, Diplomat, Member |
| Player-to-player messaging | Basic social expectation; needed for trade and diplomacy | LOW | Supabase Realtime channels |
| Ranking / leaderboard | Players need to compare progress; without it the game lacks prestige goals | LOW | Score from buildings + research + military + gold |
| Resource trading between players | Island resource scarcity forces trade; without it players self-isolate | MEDIUM | Cargo ships, travel time based on distance |
| Beginner protection (new players can't be attacked immediately) | Without this, new players get wiped day 1 and quit | LOW | Lock attacks until Town Hall level 4; genre standard |
| Colony / city expansion (found new cities) | Mid-game progression; without it top players stagnate | HIGH | Palace upgrade to support up to 11 colonies + capital; research Expansion first |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required by genre standards, but meaningfully valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Real-time turn-based combat (5-min turns with reinforcement window) | Strategic depth over instant-resolve; players can react mid-battle | HIGH | The key differentiator vs Ikariam itself (which resolves faster); creates genuine tension and tactical decisions |
| Island-cooperative shared resource buildings | Forces positive-sum cooperation between rivals on same island; unique social dynamic | MEDIUM | Sawmill / luxury resource upgrades benefit all island residents; leeching creates natural conflict |
| Island community forum (Agora) | In-game communication for island diplomacy without needing external tools | LOW | Messages visible to all city owners on the same island |
| Island shared miracle building | Bonus resource production (e.g. +10% for all) when island community contributes | LOW | Helios Tower equivalent; encourages cooperation with tangible reward |
| Barbarian villages (PvE targets per player) | Safe tutorial for combat system without attacking real players; daily engagement hook | MEDIUM | 50 levels per player; resets slowly when ignored; first PvE activity for beginners |
| Daily tasks / favor system | Consistent daily re-engagement without forcing PvP; gives passive players a reason to log in | LOW | Tasks tied to palace; rewards favor points usable for mild bonuses |
| Spy / espionage system | Intelligence gathering before attacking; adds information asymmetry layer to combat | MEDIUM | Hideout building; spy missions: scout resources, garrison, research; counter-espionage via defending spies |
| Occupation / city takeover mechanic | Ultimate PvP goal beyond pillage; raises strategic stakes of warfare significantly | HIGH | City takeover under specific conditions (project requirement); must be balanced to prevent griefing |
| War declarations + NAP (non-aggression pact) between alliances | Structured diplomacy adds political meta-game layer above individual combat | MEDIUM | Formal state changes that players can track; gives alliances clear purpose beyond casual grouping |
| Marketplace order book (buy/sell limit orders) | Real player-driven economy; more engaging than direct trades only | HIGH | Players post buy/sell orders; cargo ship travel mechanic adds geographic pricing reality |
| Vacation mode | Quality-of-life for small community; players who can't log in don't get wiped | LOW | Must block resource production AND attacks; 48-hour minimum; prevent abuse during active battle |
| Score breakdown by category | Lets players optimize a specific area (military vs economic vs research) | LOW | Already in PROJECT.md: buildings + research + military + gold sub-scores |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create serious problems for a small community or indie scope.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Premium / pay-to-win monetization | Sustainable revenue | Destroys fairness perception; kills small communities faster than anything else; Ikariam's Ambrosia system is widely hated | Keep game free, no monetization in v1; optional cosmetics only if needed later |
| Real-time (instant-resolve) combat | Feels snappier, immediate feedback | Removes all strategic depth; rewards who's online 24/7 not who plans better; exhausting for small team to balance | Stick with 5-minute turn system; schedule-friendly combat |
| Drag-and-drop building placement | More city customization freedom | Significant UI complexity for Flutter web; little strategic value for Ikariam-style game where layout doesn't affect gameplay | Fixed grid slots with visual variety; deferred per PROJECT.md |
| Isometric / 3D map rendering | Looks more impressive | Massive scope increase; weeks of extra work with no gameplay impact; can add later | 2D grid for v1; already deferred per PROJECT.md |
| OAuth (Google/Apple login) | Easier signup | Extra integration work; email/password sufficient for small community | Email/password via Supabase Auth; add OAuth after v1 if conversion is poor |
| Multi-language (i18n) support | Broader audience | Doubles content maintenance burden; translation inconsistency is worse than no translation | English only for v1 per PROJECT.md |
| Automated trade routes | Passive economy automation appeal | Removes player decision-making from resource acquisition; reduces need to interact with other players; kills marketplace activity | Manual trading with ship queues; automation deferred |
| Server wipe / seasonal resets | Competitive seasons keep game fresh | Destroys player investment; small communities won't rebuild after wipe; designed for 10k+ player games | Single persistent world; world resets only if community explicitly votes for it |
| Alliance cities (shared alliance territory) | Collective ownership appeal | Extremely complex to implement (shared ownership, permissions, funding); governance disputes ruin alliances | Alliance bonuses via coordinated individual cities; share the mechanic through war/NAP system |
| Mobile native app (iOS/Android) | Wider reach | Flutter web already works on mobile browser; native app = app store approval, separate build pipeline, maintenance burden | Flutter web is mobile-responsive; add PWA manifest for "add to home screen" feel |
| PvP ranking seasons with prizes | Competitive motivation | Hard to maintain fairly; prize management is a legal/administrative burden for indie dev | Simple all-time leaderboard; community recognition is sufficient |
| Museum building (happiness from artifacts) | More building variety | Marginal happiness impact; complex artifact-collection mechanic; already deferred per PROJECT.md | Tavern + Agora for happiness; museum deferred post-v1 |

---

## Feature Dependencies

```
[Authentication / Account]
    └──requires──> [Player Profile]
                       └──requires──> [City Placement on World Map]
                                          └──requires──> [World Map]

[City Building]
    └──requires──> [Resource Production]
                       └──requires──> [Workers / Population System]
                                          └──requires──> [Happiness System]
                                                             └──requires──> [Tavern Building]

[Research Tree]
    └──requires──> [Academy Building]
                       └──requires──> [City Building]

[Military Training]
    └──requires──> [Barracks Building]
                       └──requires──> [City Building]

[Naval Units]
    └──requires──> [Shipyard Building]
                       └──requires──> [City Building]

[PvP Combat]
    └──requires──> [Military Units]
    └──requires──> [Naval Units] (for island attacks)
    └──requires──> [World Map] (to find targets)

[Resource Trading]
    └──requires──> [Trading Post Building]
    └──requires──> [Cargo Ships] (transport mechanic)
    └──requires──> [World Map] (distance calculation)

[Marketplace / Order Book]
    └──requires──> [Resource Trading]
    └──enhances──> [Resource Trading]

[Alliance System]
    └──requires──> [Embassy Building]
    └──requires──> [Player Messaging]

[War Declaration / NAP]
    └──requires──> [Alliance System]

[Colony Expansion]
    └──requires──> [Palace Building]
    └──requires──> [Research: Expansion (Seafaring branch)]
    └──requires──> [Colony Ship unit]

[Espionage / Spy System]
    └──requires──> [Hideout Building]
    └──requires──> [Research: Espionage]

[Barbarian Villages (PvE)]
    └──requires──> [Military Units]
    └──enhances──> [Combat Tutorial / Onboarding]

[Daily Tasks]
    └──requires──> [Palace Building]
    └──enhances──> [Barbarian Villages]

[Vacation Mode]
    └──requires──> [Authentication]
    └──conflicts──> [Active Battle] (cannot activate mid-combat)

[Island Shared Buildings (Sawmill, Luxury, Miracle)]
    └──requires──> [World Map / Island System]
    └──enhances──> [Resource Production for all island residents]

[Occupation / City Takeover]
    └──requires──> [PvP Combat]
    └──requires──> [Specific Conditions Logic]
```

### Dependency Notes

- **Colony Expansion requires Palace + Research**: Players must invest significantly before expanding; this gates mid-game progression correctly.
- **Alliance System requires Embassy Building**: Physical building gate means players can't join alliances on day 1; natural progression.
- **Marketplace enhances Resource Trading**: Order book is additive; direct player-to-player trading can work without it; add marketplace in phase 2+ once trading is validated.
- **Espionage conflicts with Beginner Protection**: New players (under Town Hall level 4) should not be spied on either; protection covers both attack and espionage.
- **Vacation Mode conflicts with Active Battle**: Standard Ikariam rule; must enforce server-side.
- **Island Shared Buildings enhance Resource Production**: All island residents benefit from upgrades regardless of who donated; creates natural cooperation incentive.

---

## MVP Definition

### Launch With (v1)

Minimum viable product — what's needed to validate the core loop: build, expand, conquer.

- [ ] Authentication (email/password) — players need accounts before anything else
- [ ] Player profile + auto city placement on first login — immediate sense of ownership
- [ ] 5 resource types with server-side production (pg_cron) — core idle loop
- [ ] Warehouse capacity limits — creates resource scarcity and trade pressure
- [ ] 10 core building types (Town Hall, Barracks, Academy, Shipyard, Trading Post, Palace, Embassy, Warehouse, Tavern, Hideout) — minimum set for all major systems
- [ ] Building upgrade queue (single slot) — fundamental city management
- [ ] Research tree (4 branches, 20+ techs) with prerequisites — progression system
- [ ] World map with island grid (2D) — spatial context, find targets
- [ ] Island view + city view — navigate game world
- [ ] 6 land unit types + 3 naval unit types — sufficient unit diversity for strategic combat
- [ ] Turn-based combat (5-min turns) with battle reports — the differentiating combat system
- [ ] Pillage mechanic — reward for winning combat
- [ ] Player-to-player messaging — minimum social layer
- [ ] Alliance system (create/join, basic roles) — social retention anchor
- [ ] Resource trading via cargo ships — inter-player economy
- [ ] Ranking leaderboard (total score) — prestige goal
- [ ] Beginner protection (no attack until Town Hall level 4) — protect new players
- [ ] Basic tutorial / help text — onboarding for new players

### Add After Validation (v1.x)

Features to add once core loop is confirmed working and players are engaged.

- [ ] Barbarian villages (PvE) — once PvP combat is stable; add safe combat practice
- [ ] Daily tasks / favor system — once players need additional daily engagement hooks
- [ ] Marketplace order book — once enough players are trading to generate liquidity
- [ ] Spy / espionage system — once PvP is active; adds intelligence layer
- [ ] Occupation / city takeover — once combat system is battle-tested; high-risk feature requiring careful balance
- [ ] Vacation mode — once players are invested enough to fear losing cities
- [ ] Island shared buildings (collaborative upgrades) — once enough players share islands
- [ ] War declaration + NAP between alliances — once alliances are active enough for political meta-game
- [ ] Extended ranking breakdowns (military, alliance, island sub-rankings) — once leaderboard is being watched

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] Isometric map rendering — massive effort, purely visual; defer until core is validated
- [ ] Drag-and-drop building placement — UX complexity without strategic value change
- [ ] Automated trade routes — reduces player agency; only add if player demand is clear
- [ ] Museum building + artifact system — complexity without proportional value for small community
- [ ] Premium cosmetics (if monetization needed) — cosmetics-only to avoid pay-to-win
- [ ] PWA / "add to homescreen" for mobile — quick win for mobile engagement after v1

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Authentication + profiles | HIGH | LOW | P1 |
| Resource production (pg_cron) | HIGH | MEDIUM | P1 |
| City building + upgrades | HIGH | HIGH | P1 |
| Research tree | HIGH | HIGH | P1 |
| World map (2D grid) | HIGH | HIGH | P1 |
| Military units + turn-based combat | HIGH | HIGH | P1 |
| Battle reports | HIGH | LOW | P1 |
| Alliance system | HIGH | MEDIUM | P1 |
| Player messaging | HIGH | LOW | P1 |
| Ranking / leaderboard | MEDIUM | LOW | P1 |
| Resource trading (cargo ships) | HIGH | MEDIUM | P1 |
| Beginner protection | HIGH | LOW | P1 |
| Colony expansion | HIGH | MEDIUM | P1 |
| Marketplace order book | MEDIUM | HIGH | P2 |
| Espionage / spy system | MEDIUM | MEDIUM | P2 |
| Occupation / city takeover | HIGH | HIGH | P2 |
| Vacation mode | MEDIUM | LOW | P2 |
| Barbarian villages (PvE) | MEDIUM | MEDIUM | P2 |
| Daily tasks | MEDIUM | LOW | P2 |
| Island shared buildings | MEDIUM | MEDIUM | P2 |
| War declaration / NAP | MEDIUM | MEDIUM | P2 |
| Isometric rendering | LOW | HIGH | P3 |
| Drag-and-drop building placement | LOW | HIGH | P3 |
| Automated trade routes | LOW | MEDIUM | P3 |
| Museum + artifacts | LOW | HIGH | P3 |
| Mobile native app | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible (v1.x)
- P3: Nice to have, future consideration (v2+)

---

## Competitor Feature Analysis

| Feature | Ikariam (original) | Grepolis | Travian/Tribal Wars | Our Approach |
|---------|-------------------|----------|---------------------|--------------|
| Combat resolution | Near-instant per tick | Fast resolve | Instant on arrival | 5-minute turns with reinforcement window — unique differentiator |
| Resource types | 5 (Wood + 4 luxury) | 3 (Wood, Stone, Silver) | 4 (Lumber, Clay, Iron, Crop) | 5 types matching Ikariam (Wood, Marble, Crystal, Sulfur, Gold) |
| Colony expansion | Up to 12 cities (Palace L11) | Up to 2 cities per player | Village limit by population | Palace-based colony limit; matches Ikariam design |
| Mythological elements | Minimal (Miracle buildings) | Strong (Gods, heroes, divine powers) | None | Minimal — Greek aesthetic without divine power mechanics (reduces scope) |
| PvE content | Barbarian villages (50 levels) | Farming villages | None significant | Barbarian villages post-v1; PvE as onboarding tool |
| Island cooperation | Shared resource buildings; donation-based | No island cooperation | No equivalent | Shared island buildings are a core differentiator; implement in v1.x |
| Marketplace | Trading post order book | Trading post | Marketplace | Order book model; P2 priority |
| Premium/monetization | Ambrosia (P2W-adjacent) | Advisor system | Premium accounts | No P2W in v1; cosmetics-only if monetization needed |
| Turn-based combat | No (continuous) | No (instant) | No (instant arrival) | Yes — our main differentiator from all competitors |

---

## Sources

- [Ikariam Wikipedia](https://en.wikipedia.org/wiki/Ikariam) — Feature overview, game mechanics
- [Ikariam Grokipedia](https://grokipedia.com/page/Ikariam) — Detailed system breakdown
- [Ikariam Fandom Wiki: Espionage](https://ikariam.fandom.com/wiki/Espionage) — Spy mechanics
- [Ikariam Fandom Wiki: Happiness](https://ikariam.fandom.com/wiki/Happiness) — Citizen happiness system
- [Ikariam Fandom Wiki: Colonization](https://ikariam.fandom.com/wiki/Colonization) — Colony expansion mechanics
- [Ikariam Fandom Wiki: Daily Tasks](https://ikariam.fandom.com/wiki/Daily_Tasks) — Daily engagement system
- [Ikariam Fandom Wiki: Barbarian Village](https://ikariam.fandom.com/wiki/Barbarian_Village) — PvE system
- [Ikariam Fandom Wiki: Trading](https://ikariam.fandom.com/wiki/Trading) — Marketplace mechanics
- [Game Influence: Ikariam (push.cx)](https://push.cx/game-influence-ikariam) — Design analysis; island cooperation as key mechanic
- [Grepolis vs Ikariam comparison](https://www.findgameslike.com/vs/grepolis-vs-ikariam) — Competitor comparison
- [Grepolis Ghost Towns (Innogames support)](https://support.innogames.com/kb/Grepolis/en_DK/370/What-are-Ghost-Towns-and-how-long-does-it-take-until-inactive-players-become-Ghosts) — Inactive player handling
- [Ikariam Vacation Mode (Fandom)](https://ikariam.fandom.com/wiki/Vacation) — Vacation mechanics
- [Pay to Win in Browser Strategy Games (mmos.com)](https://mmos.com/editorials/pay-to-win-strategy-games) — Anti-pattern analysis
- [Scope Creep in Indie Games (Wayline)](https://www.wayline.io/blog/scope-creep-indie-games-avoiding-development-hell) — Anti-feature rationale
- [Player Retention in Gaming (gamedesignskills.com)](https://gamedesignskills.com/game-design/player-retention/) — Retention mechanics

---

*Feature research for: Ikariam-style browser strategy game (Flutter + Supabase)*
*Researched: 2026-03-11*
