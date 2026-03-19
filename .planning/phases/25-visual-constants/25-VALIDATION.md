# Validation Architecture — Phase 25: Visual Constants

## Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (Flutter SDK built-in) |
| Config file | pubspec.yaml dev_dependencies |
| Quick run command | `flutter test test/constants/visual_constants_test.dart test/widgets/resource_badge_test.dart` |
| Full suite command | `flutter test` |

## Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ICON-01 | `ResourceBadge` renders colored circle + correct letter for 5 production resources | unit | `flutter test test/widgets/resource_badge_test.dart` | Wave 0 |
| ICON-02 | `buildingTypeIcon` and `buildingTypeColor` cover all BuildingType values | unit | `flutter test test/constants/visual_constants_test.dart` | Wave 0 |
| ICON-03 | `resourceTypeColor` and `resourceTypeLetter` cover all ResourceType values | unit | `flutter test test/constants/visual_constants_test.dart` | Wave 0 |

## Sampling Rate
- **Per task commit:** `flutter test test/constants/visual_constants_test.dart test/widgets/resource_badge_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

## Wave 0 Gaps
- [ ] `test/constants/visual_constants_test.dart` — covers ICON-01, ICON-02, ICON-03 (map completeness)
- [ ] `test/widgets/resource_badge_test.dart` — widget render test for `ResourceBadge`
