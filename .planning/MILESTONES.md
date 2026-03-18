# Milestones

## v1.3 Bots, Testing & Automation (Shipped: 2026-03-18)

**Phases completed:** 7 phases (18-24), 11 plans

**Key accomplishments:**
- Bot AI system: 20 autonomous bot players running on pg_cron with attack, retrain, and upgrade behaviors driven by aggression archetypes
- GodMode admin dashboard: full-page admin screen with sortable player table, bot pause/resume controls, live event feed, and inline resource/army editing
- Rich seed data: 20 diverse bot accounts with tiered game states (low/mid/high), idempotent seed script surviving double db reset
- Security architecture: SECURITY DEFINER RPCs with is_admin Postgres guard; service_role key never reaches Flutter client
- Test coverage: Deno unit tests for Edge Function formulas + 9 Flutter widget test files with isolated ProviderContainer overrides
- CI/CD pipeline: single-command dev setup scripts (bash + PowerShell) + GitHub Actions quality gate on every push to main

---

## v1.1 Economy & Combat Depth (Shipped: 2026-03-15)

**Phases completed:** 3 phases, 8 plans, 4 tasks

**Key accomplishments:**
- Happiness/wine economy: tavern consumes wine per tick, drives happiness, controls population growth rate
- Population-based gold tax: idle citizens generate 3 gold/hour, scales with city size
- Cooperative island upgrades: donate wood to level up shared island resource building, boosts all cities
- Production rate UI: +X/hr labels in resource bar with detailed breakdown sheet (base, building, island, research)
- Pillage mechanic: battle winners steal unprotected resources, Hideout provides protection floor, cargo delivery on return
- Battle report visualization: fl_chart stacked bar charts for turn-by-turn unit losses, color-coded by unit type, pillage result card

---

## v0.1.0 MVP (Shipped: 2026-03-12)

**Phases completed:** 9 phases, 27 plans, 2 tasks

**Key accomplishments:**
- Supabase Auth with auto city placement, full RLS protection, server-authority contract
- Server-side resource production (5 resources, pg_cron ticks) with warehouse limits and building upgrade queue
- 2D grid world map with island view, city grid, and InteractiveViewer navigation
- Military system: 13 unit types, training queue, dispatch with travel time
- Turn-based battle engine: naval-before-land phases, 5-minute turns, Realtime battle reports
- Production hardening: splash screen, security audit, test infrastructure with dev toolbar

---

