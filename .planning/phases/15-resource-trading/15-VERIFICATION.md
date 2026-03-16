---
phase: 15-resource-trading
verified: 2026-03-16T00:00:00Z
status: passed
score: 9/9 must-haves verified
re_verification: false
---

# Phase 15: Resource Trading — Verification Report

**Phase Goal:** Resource Trading — send resources between own cities (and other cities)
**Verified:** 2026-03-16
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | unit_movements table accepts movement_type='trade' without CHECK violation | VERIFIED | Migration `20260316000002` drops old constraint and re-adds with `('attack', 'return', 'trade')` at line 18 |
| 2 | deduct_resources RPC atomically deducts a resource and raises on insufficient balance | VERIFIED | `CREATE OR REPLACE FUNCTION public.deduct_resources` with `SECURITY DEFINER`, `IF NOT FOUND THEN RAISE EXCEPTION 'Insufficient %'` in migration lines 27–47 |
| 3 | send-trade Edge Function validates ownership, resources, warehouse capacity, deducts resources, and inserts a trade movement | VERIFIED | `send-trade/index.ts` implements: origin ownership check (line 153), server-side balance pre-check (lines 182–198), warehouse capacity check (lines 201–234), `deduct_resources` RPC loop (lines 266–276), `unit_movements` insert (lines 285–296) |
| 4 | Self-trade (origin == destination) is allowed by send-trade | VERIFIED | Line 106: `// NOTE: origin_city_id === destination_city_id is intentionally allowed (self-trade)` — no rejection branch |
| 5 | Trade movement has units={} and cargo JSONB with resource amounts | VERIFIED | Insert at lines 285–296: `units: {}`, `movement_type: 'trade'`, `cargo` (the validated cargo object) |
| 6 | Player can tap any occupied city on island screen and see Trade option | VERIFIED | `island_screen.dart` lines 225–229: all occupied slots route to `_showCityActionDialog`; method at line 242 shows Trade button for both own and enemy cities |
| 7 | Player can open trade dialog, select resource amounts via sliders, and send trade | VERIFIED | `trade_dialog.dart` has `_ResourceSliderRow` with `Slider` widget; `_onSendTrade()` calls `tradeRepositoryProvider.sendTrade()` |
| 8 | Trade dialog shows sender available amounts, recipient warehouse space, and travel time preview | VERIFIED | Dialog watches `resourcesStreamProvider(originCityId)` for sender, `recipientCityInfoProvider` for recipient space (`remainingSpace()` and 'Recipient space:' label), and computes `calcTravelMinutes` for travel time row |
| 9 | Movements screen shows trade movements with green local_shipping icon and 'Cargo shipment' label | VERIFIED | `movements_screen.dart` lines 80–91: `_movementIcon` returns `Icons.local_shipping` for trade; `_movementColor` returns `Colors.green`; lines 146–155: shows 'Cargo shipment' when `movementType == 'trade'` |

**Score:** 9/9 truths verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `supabase/migrations/20260316000002_trade_movement_type_and_deduct_resources.sql` | Extended CHECK constraint and deduct_resources RPC | VERIFIED | 48 lines; contains `movement_type IN ('attack', 'return', 'trade')` and full `deduct_resources` SECURITY DEFINER function |
| `supabase/functions/send-trade/index.ts` | Trade Edge Function | VERIFIED | 309 lines; `Deno.serve` handler with full validation, deduction, and insert pipeline |
| `lib/features/trade/data/trade_repository.dart` | TradeRepository with sendTrade() and TradeException | VERIFIED | `class TradeRepository`, `class TradeException`, `sendTrade()`, `tradeRepositoryProvider` all present |
| `lib/features/trade/providers/trade_providers.dart` | tradeRepositoryProvider and recipientResourcesProvider | VERIFIED | `recipientCityInfoProvider` FutureProvider.family, `RecipientCityInfo` with `remainingSpace()` |
| `lib/features/trade/screens/trade_dialog.dart` | showTradeDialog entry point and _TradeDialogContent widget | VERIFIED | 401 lines; `Future<bool?> showTradeDialog`, `_TradeDialogContent ConsumerStatefulWidget`, resource sliders for all 4 tradeable types |
| `lib/features/map/screens/island_screen.dart` | Unified _showCityActionDialog for all occupied city slots | VERIFIED | `_showCityActionDialog` at line 242; called from all occupied slot onTap callbacks; two `showTradeDialog` calls (own + enemy) at lines 279 and 319 |
| `lib/features/movements/screens/movements_screen.dart` | Trade movement icon/color helpers and 'Cargo shipment' label | VERIFIED | `_movementIcon` and `_movementColor` top-level helpers; `'Cargo shipment'` branch at line 147; `_movementIcon(movement.movementType)` used at line 117 |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `trade_dialog.dart` | `trade_repository.dart` | `ref.read(tradeRepositoryProvider).sendTrade()` | WIRED | Line 260: `await ref.read(tradeRepositoryProvider).sendTrade(...)` |
| `trade_repository.dart` | send-trade Edge Function | `supabaseClient.functions.invoke('send-trade', ...)` | WIRED | Lines 35–42: multiline invoke call with `'send-trade'` as function name and cargo body |
| `island_screen.dart` | `trade_dialog.dart` | `showTradeDialog()` call from city action dialog | WIRED | Lines 279 and 319: two `showTradeDialog(context, ...)` calls in `_showCityActionDialog` |
| `movements_screen.dart` | `UnitMovement.movementType` | `_movementIcon` and `_movementColor` helpers | WIRED | Line 117: `_movementIcon(movement.movementType)` and line 119: `_movementColor(movement.movementType, theme)` |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| TRAD-01 | 15-01, 15-02 | User can send resources to another player's city via cargo ships (with travel time) | SATISFIED | Full pipeline: island screen tap → trade dialog → sliders → send-trade Edge Function → deducts resources → inserts unit_movement with cargo → visible in movements screen |

**REQUIREMENTS.md status:** `[x] TRAD-01` marked Complete at Phase 15.

**Orphaned requirements check:** No additional requirements mapped to Phase 15 in REQUIREMENTS.md beyond TRAD-01.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/features/trade/data/trade_repository.dart` | 57 | `return {}` | Info | Defensive fallback for unexpected response.data type — real return is line 55. Not a stub; the Edge Function always returns a Map. |

No blockers or warnings found. Flutter analyze reports zero issues on all modified and created files.

---

## Human Verification Required

### 1. Trade Dialog Slider Interaction

**Test:** Open app, navigate to island screen, tap an occupied enemy city, tap "Trade", interact with resource sliders, verify amounts clamp correctly and "Warehouse full" warning appears when slider exceeds recipient space.
**Expected:** Sliders respond smoothly; label shows `{value} / {available}`; recipient space row updates; Send Trade button enables when any slider > 0.
**Why human:** Slider UX, visual clamping behavior, and SnackBar content cannot be verified programmatically.

### 2. Trade Success Flow

**Test:** Send a trade from one city to another; confirm the success SnackBar appears with "Trade sent! Cargo arrives in Xh Ym." and a trade movement appears in the Movements tab.
**Expected:** Green SnackBar with correct travel time; Movements screen shows green local_shipping icon, city name, "Cargo shipment", and countdown timer.
**Why human:** Real-time movement insertion and SnackBar display require a live Supabase session.

### 3. Own-City Trade

**Test:** Tap your own city on the island screen; verify the dialog shows "Go to City" (FilledButton) and "Trade" (OutlinedButton); tap "Trade" and confirm the trade dialog opens.
**Expected:** Own-city variant dialog with both buttons; Trade opens the dialog with self-trade destination.
**Why human:** UI rendering and dialog variant selection require a running app.

---

## Gaps Summary

No gaps. All observable truths are verified, all artifacts exist and are substantive, all key links are wired, and flutter analyze passes with no issues.

---

_Verified: 2026-03-16_
_Verifier: Claude (gsd-verifier)_
