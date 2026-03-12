---
status: testing
phase: 05-combat
source: 05-00-SUMMARY.md, 05-01-SUMMARY.md, 05-02-SUMMARY.md, 05-03-SUMMARY.md
started: 2026-03-12T22:00:00Z
updated: 2026-03-12T22:00:00Z
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

number: 1
name: Cold Start Smoke Test
expected: |
  Kill any running server/service. Run `supabase db reset` to clear and re-apply all migrations. Server boots without errors, all 6 new combat migrations apply cleanly, and the 5 cron jobs (resource-tick, construction-tick, training-tick, arrivals-tick, battle-tick) are all registered.
awaiting: user response

## Tests

### 1. Cold Start Smoke Test
expected: Kill any running server/service. Run `supabase db reset` to clear and re-apply all migrations. All 6 combat migrations apply cleanly, 5 cron jobs registered, no errors.
result: [pending]

### 2. Battles Tab Visible
expected: Run `flutter run -d chrome`, log in. Bottom navigation shows 4 tabs: World, Island, City, Battles. The Battles tab has a shield icon.
result: [pending]

### 3. Empty Battles State
expected: Tap the Battles tab. Screen shows "No battles yet" message (since no battles have occurred).
result: [pending]

### 4. Dispatch Army to Enemy City
expected: From your city, train some units (Barracks). Dispatch them to another player's city. Units appear as "in transit" with travel-time countdown on the military screen.
result: [pending]

### 5. Battle Starts on Arrival
expected: After army arrives at enemy city, a battle entry appears in the Battles tab for both attacker and defender. Shows "Active" status with turn number and countdown to next turn.
result: [pending]

### 6. Turn Resolves with Casualties
expected: Wait for 5-minute turn to resolve (or check after battle-tick cron fires). Battle turn card appears showing casualties for both sides. Surviving unit counts update.
result: [pending]

### 7. Naval Before Land Phase
expected: Send a mixed army (naval + land units). In the battle turn card, Naval phase is displayed before Land phase. If attacker's naval is wiped, land phase shows "blocked" message.
result: [pending]

### 8. Real-time Updates Without Refresh
expected: With battle active, both attacker and defender browser windows update automatically when a turn resolves — no page refresh needed. New turn card appears via Supabase Realtime.
result: [pending]

### 9. Battle Ends on Wipeout
expected: Let a battle run until one side has zero units. Battle status changes to "attacker_won" or "defender_won". Winner's surviving units return home (attacker) or remain (defender).
result: [pending]

### 10. Battle Detail Screen
expected: Tap an active or completed battle in the list. Detail screen shows: status header, army count comparison (attacker vs defender), reverse-chronological list of turn cards with per-turn casualties.
result: [pending]

### 11. Countdown Timer on Active Battle
expected: On an active battle, the detail screen shows a live countdown timer ticking down to the next turn resolution (similar to construction countdown).
result: [pending]

## Summary

total: 11
passed: 0
issues: 0
pending: 11
skipped: 0

## Gaps

[none yet]
