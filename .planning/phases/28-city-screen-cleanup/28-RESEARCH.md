# Phase 28: City Screen Cleanup - Research

**Researched:** 2026-03-21
**Domain:** Flutter widget removal — city screen title text cleanup
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Own city screen (city_screen.dart)
- Remove the city name headline Text widget (headlineMedium, white, shadowed) at lines 160-170
- Remove the "Governor: $displayName" Text widget at lines 172-177
- Remove surrounding SizedBox/padding for these text widgets entirely — content shifts up, no spacer left behind
- Keep the rest of the city screen body intact (resource panel, building grid, etc.)

#### AppBar player info (city_screen.dart)
- Remove the display_name Text from AppBar actions area (lines 66-85)
- Keep the player avatar icon only — no text label, no tooltip needed
- Avatar alone is sufficient context for the player

#### Enemy city view banner (enemy_city_view_screen.dart)
- Replace "Viewing $cityName ($ownerName) — read only" with "Viewing enemy city — read only"
- Keep the red Container banner styling unchanged — read-only warning is still needed
- Remove city name and owner name from the banner text, but preserve the banner structure

#### Navigation and borders
- Removing titles must NOT break navigation (back button, route params still work)
- Ownership color borders on city grid must remain unaffected
- All other UI elements (resource bar, building cells, construction banner) untouched

### Claude's Discretion
- Whether to remove the `cityName` and `displayName` variable declarations if they become unused after title removal
- Any cleanup of imports that become unused
- Exact dead code removal scope (only remove what's directly related to title display)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CLNP-01 | All city screens have city name and player name title texts removed | Three precise surgical edits identified: (1) city_screen.dart body title block, (2) city_screen.dart AppBar actions text, (3) enemy_city_view_screen.dart banner text string |
</phase_requirements>

---

## Summary

Phase 28 is a pure Flutter widget removal task with no new dependencies, no state management changes, and no routing changes. The scope is exactly three surgical edits across two files, with a third file (city_grid_screen.dart) verified to already be clean.

The task is the last phase of v1.4 and must remain simple and contained. All changes are cosmetic widget deletions — no logic changes, no provider changes, no model changes. The primary risk is accidentally removing too much (e.g., variables that are still used elsewhere) or leaving orphaned SizedBox spacers that create visual gaps.

**Primary recommendation:** Make three targeted edits — remove the title block from `_CityBody`, remove the displayName Text from the AppBar Row, and change the banner string in `enemy_city_view_screen.dart`. Then assess dead code (unused variables/imports) as discretionary cleanup.

---

## Standard Stack

No new libraries required. This phase uses only the existing Flutter widget tree.

### Core (existing — no changes)
| Library | Purpose |
|---------|---------|
| flutter/material.dart | Widget tree, Text, Row, Column, Padding |
| flutter_riverpod | Already present — no changes to providers |

**Installation:** None required.

---

## Architecture Patterns

### File Structure (no new files)
```
lib/features/city/screens/
└── city_screen.dart          ← Edit: remove 2 title blocks

lib/features/map/screens/
├── enemy_city_view_screen.dart  ← Edit: change banner string
└── city_grid_screen.dart        ← Verify: already clean, no changes
```

### Pattern 1: Widget Block Removal
**What:** Delete a contiguous block of widgets from a Column's children list, including any adjacent SizedBox spacers that only serve the removed block.
**When to use:** When a title Text and its spacing are coupled — removing the text but leaving the SizedBox creates a visual gap with no content.
**Example (city_screen.dart lines 159-178 — before):**
```dart
// City name header.
Text(
  cityName,
  style: Theme.of(context).textTheme.headlineMedium?.copyWith(...),
  textAlign: TextAlign.center,
),
const SizedBox(height: 4),
if (displayName.isNotEmpty)
  Text(
    'Governor: $displayName',
    style: Theme.of(context).textTheme.bodyLarge,
    textAlign: TextAlign.center,
  ),
const SizedBox(height: 16),
```
**After:** Remove the city name Text, SizedBox(height:4), the displayName conditional Text, AND replace the trailing `SizedBox(height: 16)` with nothing — the Island info card follows directly, or reduce spacing as appropriate. The `SizedBox(height: 16)` after this block separates the title section from the island card, so it must be evaluated: since it was spacing after the title group, it should be removed too.

### Pattern 2: Row Child Removal
**What:** Remove a specific child from a Row while keeping sibling widgets intact.
**When to use:** AppBar actions Row contains AvatarWidget + SizedBox + conditional Text + SizedBox — remove only the Text and its adjacent SizedBox spacers.
**Example (city_screen.dart lines 64-85 — AppBar actions):**
```dart
// Before:
Padding(
  padding: const EdgeInsets.only(right: 4),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AvatarWidget(avatarId: avatarId, size: 32),
      const SizedBox(width: 6),
      if (displayName.isNotEmpty)
        Text(displayName, style: ...),
      const SizedBox(width: 4),
    ],
  ),
),

// After: remove SizedBox(width:6) + conditional Text block, keep avatar + trailing SizedBox
Padding(
  padding: const EdgeInsets.only(right: 4),
  child: AvatarWidget(avatarId: avatarId, size: 32),
),
```
Note: With only the avatar remaining in the Row, the Row itself can be simplified to just the AvatarWidget directly inside the Padding. The trailing `SizedBox(width: 4)` provides right padding from the Padding widget, so it can be kept or folded into `EdgeInsets.only(right: 8)` at Claude's discretion.

### Pattern 3: String Literal Change
**What:** Replace an interpolated string with a static string in a Text widget.
**When to use:** Banner text content changes, but the Text widget and all styling remain.
**Example (enemy_city_view_screen.dart line 67):**
```dart
// Before:
'Viewing $cityName ($ownerName) — read only'

// After:
'Viewing enemy city — read only'
```
The Container, Row, Icon, SizedBox, Text, and all styling are unchanged.

### Anti-Patterns to Avoid
- **Leave orphaned spacers:** Removing text but keeping SizedBox(height: 4) between it and the next text creates a visual gap. Remove spacers that only separated the removed widgets.
- **Remove the outer Column children comment:** The `// City name header.` comment can be removed along with the block — don't leave dangling comments.
- **Remove cityName variable entirely without checking:** `cityName` (line 127) is extracted from city data. After removing the headline Text, verify no other widget in `_CityBody` uses `cityName`. From reading the code: `cityName` is only used in the headline Text — it is safe to remove the variable declaration.
- **Remove displayName parameter from _CityBody:** `displayName` is passed as a constructor param to `_CityBody`. After removing both uses (Governor text + AppBar is in the parent), the parameter and field may become unused. This is Claude's discretion.
- **Remove cityName/ownerName constructor params from EnemyCityViewScreen:** These are route parameters that may be used by routing logic or navigation upstream — only remove if confirmed unused in ALL uses. From reading the code: `cityId`, `cityName`, and `ownerName` are all constructor params. After the banner string change, `cityName` and `ownerName` are no longer referenced in the widget body. They can be removed from the class IF the call sites are also updated — this requires checking route configuration.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Removing widgets | Complex refactoring | Direct deletion from Column.children list |
| Dead variable removal | Automated refactor tool | Manual review of each variable's usages |

---

## Common Pitfalls

### Pitfall 1: Orphaned SizedBox spacers
**What goes wrong:** Remove the Text widgets but leave their associated SizedBox spacers in the Column, creating unexpected vertical gaps.
**Why it happens:** SizedBox spacers are inline in the children list — easy to miss when focusing on the Text widgets.
**How to avoid:** When removing a Text widget, look at the preceding and following items in the Column children list. Remove SizedBox that only served as spacing around the removed block.
**Warning signs:** Extra whitespace gap between the AppBar and the island card in the own city screen.

### Pitfall 2: Breaking _CityBody constructor contract
**What goes wrong:** Removing `displayName` from `_CityBody` field/constructor but forgetting to update the call site at line 102 (`_CityBody(city: city, displayName: displayName)`).
**Why it happens:** The `displayName` variable in `CityScreen.build()` is still needed for the AppBar avatar area — but after removing the AppBar text as well, `displayName` in the parent `CityScreen.build()` may also become unused (only `avatarId` is needed).
**How to avoid:** Trace `displayName` top to bottom: profileAsync → displayName variable in build() → passed to AppBar actions (to be removed) and to `_CityBody`. After both removals, the entire `displayName` derivation block at lines 41-44 in CityScreen can be removed.
**Warning signs:** Dart analysis "unused variable" warning on `displayName`.

### Pitfall 3: Removing EnemyCityViewScreen constructor params used by router
**What goes wrong:** Removing `cityName` and `ownerName` from the constructor causes router/navigation call sites to fail compilation.
**Why it happens:** The params were added for display purposes but are passed from the route — removing them requires updating every navigation call site.
**How to avoid:** Before removing constructor params, check the router file for the `/city-view` route. If the route already passes these params from navigation state and removing them would break the route, either keep the params (unused but required by contract) or update the router simultaneously.
**Warning signs:** Compile errors at call sites passing `cityName:` and `ownerName:` named arguments.

### Pitfall 4: Forgetting the `// City name header.` comment
**What goes wrong:** The comment `// City name header.` at line 159 stays in the code after its Text widget is removed, becoming a dangling comment with no corresponding code.
**How to avoid:** Remove the comment along with the widget block.

---

## Code Examples

### Exact removal scope in city_screen.dart — _CityBody.build()

Lines 159-178 currently read:
```dart
              // City name header.
              Text(
                cityName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: const [
                        Shadow(blurRadius: 4, color: Colors.black54),
                      ],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              if (displayName.isNotEmpty)
                Text(
                  'Governor: $displayName',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
```
**Remove the entire block** (comment + city name Text + SizedBox(height:4) + Governor conditional Text + SizedBox(height:16)). The island info Card follows immediately after — no spacer needed since the scroll padding at the top of SingleChildScrollView already provides breathing room.

### Exact removal scope in city_screen.dart — CityScreen AppBar actions

Lines 64-85 (the first actions child, a Padding widget):
```dart
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvatarWidget(avatarId: avatarId, size: 32),
                const SizedBox(width: 6),
                if (displayName.isNotEmpty)
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
```
**Replace** the entire Padding+Row with just the avatar in a Padding:
```dart
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AvatarWidget(avatarId: avatarId, size: 32),
          ),
```
(Right padding increased from 4 to 8 to preserve breathing room from the logout icon, absorbing the removed trailing SizedBox(width:4).)

### Exact change in enemy_city_view_screen.dart

Line 67 — only the string literal changes:
```dart
// Before:
'Viewing $cityName ($ownerName) — read only'

// After:
'Viewing enemy city — read only'
```
Everything else in the Container/Row/Text structure stays identical.

### Dead code removal (Claude's discretion)

**cityName variable** in `_CityBody.build()` (line 127):
```dart
final cityName = city!['name'] as String? ?? 'Unknown City';
```
After removing the headline Text, `cityName` is no longer referenced. Safe to delete.

**displayName field** in `_CityBody`:
After removing the Governor Text (only use in `_CityBody`), the `displayName` constructor param and field become unused. Remove the field, constructor param, and update the call site in `CityScreen.build()`.

**displayName variable** in `CityScreen.build()` (lines 41-44):
After removing the AppBar text (only use in parent) and removing the `_CityBody(displayName:)` param, the entire `displayName` derivation block can be removed. The `profileAsync` watch is still needed for `avatarId` — do NOT remove `profileAsync`.

**cityName/ownerName in EnemyCityViewScreen**: Check router before removing. Keep if router passes them as named args; only remove if router is updated simultaneously.

---

## State of the Art

No technology changes in this phase. Purely removing existing Flutter widgets.

| Current Approach | After Phase 28 | Impact |
|-----------------|----------------|--------|
| city_screen.dart shows city name + governor text | No title text — content starts at island card | Cleaner city screen, name will be re-added with proper design later |
| AppBar shows avatar + display name text | AppBar shows avatar only | Less AppBar clutter |
| Enemy banner shows city and owner names | Banner shows generic "Viewing enemy city" | Names removed from foreign city view |

---

## Open Questions

1. **EnemyCityViewScreen constructor params (cityName, ownerName)**
   - What we know: After the banner text change, both params are unused in the widget body
   - What's unclear: Whether the router call site passes these as required named args that must be updated simultaneously
   - Recommendation: Read the router file before deciding. If router update is simple (remove two named args from the navigation call), do it. If the router extracts them from route state and it's complex, leave the params as unused (compiler will warn but not error with named params that are just unused fields).

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Flutter test (built-in) |
| Config file | pubspec.yaml dev_dependencies |
| Quick run command | `flutter test` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CLNP-01 | No city/player name text on city screens | manual-only | N/A | N/A |

**Manual-only justification:** This requirement is purely visual — no text widget with city name or player name renders on any city screen. Flutter widget tests could verify text absence, but the project has no existing widget test infrastructure for city screens. Visual verification on device/emulator is the appropriate validation method for a cosmetic removal.

### Sampling Rate
- **Per task commit:** `flutter analyze` (static analysis only — no widget tests exist)
- **Per wave merge:** `flutter analyze`
- **Phase gate:** Visual review of city screen + enemy city view before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] No test files needed — CLNP-01 validated by manual visual inspection only. Flutter analyze ensures no compilation errors from variable/import removals.

---

## Sources

### Primary (HIGH confidence)
- Direct code read: `lib/features/city/screens/city_screen.dart` — full file, confirmed exact line numbers and widget structure
- Direct code read: `lib/features/map/screens/enemy_city_view_screen.dart` — full file, confirmed banner text location
- Direct code read: `lib/features/map/screens/city_grid_screen.dart` — full file, confirmed no title texts present (no changes needed)
- `.planning/phases/28-city-screen-cleanup/28-CONTEXT.md` — locked decisions and code context

### Secondary (MEDIUM confidence)
- `.planning/REQUIREMENTS.md` — CLNP-01 definition confirmed
- `.planning/STATE.md` — project context and decision history

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Exact edit locations: HIGH — source files read directly, line numbers verified
- Dead code analysis: HIGH — variable usages traced through read files
- Router interaction: MEDIUM — router file not read; EnemyCityViewScreen param removal flagged as open question
- Test approach: HIGH — visual-only validation appropriate for cosmetic removal

**Research date:** 2026-03-21
**Valid until:** Phase is simple and self-contained — research does not expire
