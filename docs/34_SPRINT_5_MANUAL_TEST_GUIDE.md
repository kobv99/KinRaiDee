# Sprint 5 Manual Test Guide

Product Owner environment: `flutter run -d web-server`.

## Feature: Smart recommendation and explanation

### Test Steps

1. Add Rice, Egg, and Soy Sauce to Pantry.
2. Open Recipe recommendations.
3. Change sorting between Highest Score, Best Match, Fastest, and Least
   Missing.
4. Apply the Dashboard summaries, including พร้อมครบ and เมนูด่วน.
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

## Feature: Single recommendation list

### Test Steps

1. Add Rice, Egg, and Soy Sauce to Pantry.
2. Open Recipe recommendations and scroll through the whole page.
3. Use the refresh action in the recommendation list header.
4. Scroll to the bottom of the page and open `ค้นหาสูตร`.

### Expected Result

- The page order is header, Recommendation Dashboard, one recommendation list,
  then Search.
- No second recommendation section such as “More Recipes from Main Ingredient”
  is displayed.
- Refresh sits in the recommendation list header as a lightweight text button
  and replaces the list without leaving the page.
- Search remains reachable at the end of the page.

### Possible Regression Areas

- Recommendation paging
- Recipe catalog navigation

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

## Feature: Tracking Types and unit mismatch

### Test Steps

1. Add Chili using Piece and Soy Sauce using Bottle.
2. Open Recipes that express Chili in Gram and Soy Sauce in Tablespoon.
3. Remove Holy Basil from an otherwise almost-ready Pad Krapow Pantry.

### Expected Result

- Chili and Soy Sauce count as available despite the unit difference.
- Recipe Match is based on availability and does not drop for incompatible
  presentation units.
- Pad Krapow remains visible, shows Holy Basil as missing, and includes it in
  Shopping Preview.

### Possible Regression Areas

- Count/weight quantity matching
- Canonical compatibility
- Candidate visibility

## Feature: Dashboard, QA, Debug, and substitution popup

### Test Steps

1. Open Recommendations and review the summary card and Recipe cards.
2. Open the bug icon to enter Recommendation QA.
3. Expand Knowledge Base Health, Test Pantry Profiles, and Debug View.
4. Open a Recipe with a substitution and select `ดู`.

### Expected Result

- Dashboard counts Perfect Match, Pantry Friendly, Quick Meal, and expiring
  recommendations.
- Cards show score, time, difficulty, Pantry use, missing count, badges, and
  concise reasons.
- QA lists health metrics, profiles, score components, and Why Not.
- Substitution occupies only a compact launcher until opened in a dismissible
  popup.

### Possible Regression Areas

- Small-screen overflow
- Recipe Detail scrolling
- Substitution acceptance

## Feature: Search-first Recipe Catalog

### Test Steps

1. Open Recipes and select `ค้นหาสูตร`.
2. Confirm that no Recipe cards are displayed before entering a query.
3. Search by a Recipe name, ingredient name, and category.
4. Open one result, return to search, then clear the query.

### Expected Result

- The catalog does not render every Recipe when first opened.
- Only matching Recipes are displayed after an explicit search.
- At most 30 results are displayed per query; broader searches ask the user to
  refine the query.
- Clearing the query hides the results and returns to the search prompt.
- Opening a result still reaches the correct Recipe Detail.

### Possible Regression Areas

- Recipe Hub navigation
- Thai and English ingredient search
- Recipe Detail navigation
- Large Knowledge Base performance

## Feature: Responsive Recommendation Explanation

### Test Steps

1. Use a short browser viewport.
2. Open a recommended Recipe.
3. Expand `ทำไมถึงแนะนำเมนูนี้?`.
4. Scroll through every reason and Shopping Preview item.

### Expected Result

- The explanation remains inside the available viewport.
- Long explanation content scrolls inside the panel.
- Flutter does not display `BOTTOM OVERFLOWED`.
- The rest of Recipe Detail remains usable.

### Possible Regression Areas

- Recipe Detail scrolling
- Expansion state
- Recommendation metrics and Shopping Preview

## Feature: Interactive Recommendation Dashboard

### Test Steps

1. Open the Recipe recommendation page with Pantry ingredients available.
2. Select each summary: All Recipes, Ready to Cook, Pantry Friendly,
   Quick Meals, and Uses Expiring Ingredients.
3. Observe the Recipe list after each selection.
4. Select All Recipes again.

### Expected Result

- Every summary is clickable and the selected summary is visually identified.
- The Recipe list immediately applies the matching domain filter.
- Quick Meals shows Recipes taking no more than 30 minutes.
- Uses Expiring Ingredients shows only Recipes using expiring Pantry items.
- All Recipes clears the dashboard filter.

### Possible Regression Areas

- Recommendation ranking
- Filter state
- Summary counts
- Expiring Ingredient detection

## Feature: Production-friendly Recommendation Language

### Test Steps

1. Open Recipe recommendations in normal user mode.
2. Review Recipe cards and expand `ทำไมถึงแนะนำเมนูนี้?`.
3. Open Recommendation QA from the bug icon.

### Expected Result

- Normal Recipe cards show Pantry Match and a human-readable readiness label.
- The explanation uses labels such as Perfect Match or Almost Ready.
- The internal weighted Recommendation Score is not shown in normal UI.
- Final Score and score components remain available only in Recommendation QA.
- The Pantry recommendation banner is compact by default.
- Missing-ingredient details and the Shopping action appear only after expansion.

### Possible Regression Areas

- Recipe card badges
- Recipe Detail expansion
- Add Missing Ingredients
- Developer QA visibility
