# Sprint 5 Manual Test Guide

Product Owner environment: `flutter run -d web-server`.

## Feature: Smart recommendation and explanation

### Test Steps

1. Add Rice, Egg, and Soy Sauce to Pantry.
2. Open Recipe recommendations.
3. Change sorting between Highest Score, Best Match, Fastest, and Least
   Missing.
4. Apply the 75% and 100% match filters.
5. Open a recommended Recipe and expand “ทำไมถึงแนะนำเมนูนี้?”.

### Expected Result

- Ranking remains stable after navigation and rebuild.
- Cards show Recommendation Score and data-driven badges.
- Filters remove only Recipes outside the selected threshold.
- Detail shows Recipe Match, Pantry completion, Pantry utilization, reasons,
  missing count, and shopping preview.
- Missing ingredients never prevent the user from continuing to cook.

### Possible Regression Areas

- Hero ingredient selection and paging
- Recipe readiness
- Pantry canonical matching
- Substitution panel
- Recipe Detail responsive layout

## Feature: Expiring ingredients

### Test Steps

1. Add an ingredient with an expiry date tomorrow.
2. Open recommendations containing that ingredient.

### Expected Result

- Relevant Recipes receive an expiring-ingredient score contribution and badge.
- The explanation states why expiry influenced the recommendation.
- Expired ingredients are not counted as available.

### Possible Regression Areas

- Time-zone/date handling
- Stable ranking
- Pantry quantity matching
