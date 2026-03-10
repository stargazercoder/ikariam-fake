# Phase 1: Foundation - Context

**Gathered:** 2026-03-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Working Flutter web project with Supabase Auth, RLS-protected database schema, server-authority contract, and auto city placement on first login. No game mechanics (resource production, buildings, combat) — just the base everything else builds on.

</domain>

<decisions>
## Implementation Decisions

### Player Profile & Avatar
- Preset avatar set (10-20 ancient Greek themed avatars) — no user upload, no Storage needed
- Profile creation screen appears immediately after sign-up — cannot enter game without profile
- Display name: 3-20 characters, alphanumeric + underscore, unique constraint in DB
- Both display name and avatar can be changed later via settings

### Auto City Placement
- New player's city placed on the island with the most empty slots (least populated)
- Fixed starting resource pack: same amounts for every player (e.g., 500 Wood, 500 Gold, others 0)
- Only Town Hall (Level 1) pre-built — player builds everything else
- Auto-assigned city name from ancient Greek city name pool (Sparta, Athens, etc.) — changeable later

### Database Schema Scope
- Phase 1 creates only the tables needed for this phase: profiles, islands, cities
- Other tables (resources, buildings, units, etc.) added in their respective phases via new migrations
- 100 islands created via seed migration at project setup
- Each island has 16-17 city slots, 1 wood resource area, 1 luxury resource area
- Luxury resource types (Marble, Crystal, Sulfur) distributed equally across islands (~33 each)
- RLS enabled in the same migration that creates each table — never added later

### Flutter Project Structure
- GoRouter for declarative routing with auth guards
- Feature-first folder organization: lib/features/auth/, lib/features/city/, lib/features/map/
- Riverpod for state management (per PROJECT.md constraints)
- Flame engine dependency added in Phase 1, GameWidget wrapper prepared, but map/game rendering deferred to Phase 3
- Auth screens are standard Flutter widgets (not Flame)

### UI Style
- Minimal and clean design — Material 3 based
- Ancient Greek color palette (navy blue, gold, white)
- No illustrations, columns, or parchment textures in v1

### Claude's Discretion
- Exact starting resource amounts per type
- Avatar asset selection/style
- Specific ancient Greek city names in the pool
- GoRouter route structure and guard implementation
- Supabase Edge Function naming conventions
- Loading/error state designs

</decisions>

<specifics>
## Specific Ideas

- Avatar system uses preset images — no upload, no moderation concern
- City auto-naming from a pool of real ancient Greek city/region names gives the game personality without requiring user input
- "Least populated island" placement strategy naturally distributes players across the world

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — greenfield project, no existing code

### Established Patterns
- None yet — Phase 1 establishes all foundational patterns

### Integration Points
- Supabase project needs to be created/connected
- Flutter project needs to be initialized with `flutter create`
- Flame, Riverpod, GoRouter, supabase_flutter packages to be added

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-03-11*
