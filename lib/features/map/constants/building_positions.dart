// Building grid position constants for the city spatial view.
//
// Defines the 6-column x 5-row grid layout for all 14 building types.
// No two buildings share the same (row, col) position.

import '../../../core/constants/building_constants.dart';

/// Maps each [BuildingType] to its fixed grid position in the city view.
///
/// Grid is 5 rows (0–4) × 6 columns (0–5).
/// Layout mirrors the Ikariam city grid with town hall at center (2,2).
const Map<BuildingType, ({int row, int col})> kBuildingPositions = {
  BuildingType.townHall: (row: 2, col: 2),
  BuildingType.warehouse: (row: 0, col: 0),
  BuildingType.barracks: (row: 0, col: 4),
  BuildingType.shipyard: (row: 4, col: 5),
  BuildingType.academy: (row: 0, col: 2),
  BuildingType.embassy: (row: 2, col: 0),
  BuildingType.tradingPort: (row: 4, col: 0),
  BuildingType.townWall: (row: 2, col: 5),
  BuildingType.hideout: (row: 4, col: 3),
  BuildingType.tavern: (row: 4, col: 1),
  BuildingType.sawmill: (row: 1, col: 1),
  BuildingType.quarry: (row: 1, col: 3),
  BuildingType.glassblower: (row: 3, col: 1),
  BuildingType.sulfurPit: (row: 3, col: 3),
};
