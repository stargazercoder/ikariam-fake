// Island resource level constants and formulas.
//
// These mirror the logic in the donate-island-wood Edge Function to ensure
// client-side cost display is always consistent with the server.

import 'dart:math';

/// Wood cost to upgrade island resource level from [currentLevel] to
/// currentLevel + 1.
///
/// Formula: ceil(300 * 1.5^currentLevel). Mirrors donate-island-wood Edge
/// Function.
int islandDonationCost(int currentLevel) {
  const baseCost = 300;
  const growth = 1.5;
  return (baseCost * pow(growth, currentLevel)).ceil();
}

/// Island production multiplier at a given [resourceLevel].
///
/// Level 0 = 1.0x, Level 5 = 1.5x, Level 10 = 2.0x.
/// Each level adds +10% to base production.
double islandMultiplier(int resourceLevel) {
  return 1.0 + resourceLevel * 0.10;
}

/// Maximum island resource level. Donations are blocked at this level.
const int maxIslandResourceLevel = 10;
