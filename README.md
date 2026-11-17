# WeightSumMore

A local-first iOS 17+ fitness, nutrition and weight tracker built with SwiftUI,
SwiftData, Swift Charts and HealthKit. English and Traditional Chinese interfaces
are included.

## Run

1. Open `FitnessTracker.xcodeproj` in Xcode with the iOS 17 SDK or later.
2. Select the shared **WeightSumMore** scheme and an iPhone simulator.
3. Run the app and create a profile.

For a physical device, select your own Developer Team under Signing & Capabilities
and configure HealthKit for the app identifier. Health imports are read-only and
require the user's permission. Apple Watch workouts must first sync to Apple
Health on the iPhone. No separate watchOS app is required or included.

The existing bundle identifier and internal `FitnessTracker` module are retained
to preserve local app data when updating an existing installation.

## Features

- Daily energy dashboard with estimated BMR, TDEE and calorie balance.
- Training categories, workout streaks and optional Health workout imports with
  duplicate review.
- Meal-based calorie logging, a food portion / nutrition-label calculator inside
  the intake editor, and a separate portion-estimation tutorial.
- Weight trends and user-defined recording goals in **More > Goals**, alongside
  the monthly training goal. The Weight tab shows progress without an edit form.
- 1D, 7D, 30D, 90D, 1Y and all-time filters, adaptive charts, and expandable records.
- Separate energy balance, intake/output and estimated weight-change reports.
- Local SwiftData storage. No account, server, cloud sync or analytics SDK.

## Tests

Use **Product > Test**, or choose an installed simulator:

```sh
xcodebuild test -project FitnessTracker.xcodeproj -scheme WeightSumMore \
  -destination 'platform=iOS Simulator,name=<installed iPhone simulator>' \
  CODE_SIGNING_ALLOWED=NO
```

Tests cover formulas, date boundaries, period aggregation, persistence, recording
goals, food portions, workout streaks and Health import deduplication. An app-hosted
render test attaches Traditional Chinese phone-width screenshots to the test
result bundle. Real-device Health authorization and Watch synchronization need
separate device testing.

## Wellness And Food References

Energy calculations and weight changes are estimates for general wellness, not
medical advice. Profile caution flags display stronger warnings. The app does not
diagnose conditions or prescribe a calorie target.

Food portion references come from the
[Hong Kong Department of Health common-food table](https://www.studenthealth.gov.hk/english/resources/resources_bl/files/caloric_value_common_food.pdf).
Package and restaurant nutrition information take priority over these estimates.
Further reading: [CFS nutrient information](https://www.cfs.gov.hk/english/nutrient/index.php)
and [FDA nutrition-label guidance](https://www.fda.gov/food/nutrition-facts-label/how-understand-and-use-nutrition-facts-label).
