# Sprint 3 Manual Test Guide

The Product Owner performs these tests using:

```text
flutter run -d web-server
```

Codex does not perform Product Acceptance.

## Test 1

**Feature:** Recommendation Ranking

**Test Steps:**

1. Open Pantry.
2. Add an ingredient that partially supports several Recipes.
3. Review the Top Recommendations.
4. Open View All.

**Expected Results:**

- Recommendations originate from the current Pantry.
- Higher-impact ingredients appear before lower-impact ingredients.
- Reopening the same state produces the same order.
- Each item displays ingredient, impact, and an understandable reason.
- No Shopping item is created automatically.

**Possible Regression Areas:**

- Pantry Insights
- Recipe Readiness
- Recommendation Preview
- Recommendation Detail

## Test 2

**Feature:** Recommendation Types and Detail

**Test Steps:**

1. Open a recommendation.
2. Review Impact Score, Recipes unlocked, readiness change, and affected Recipes.
3. Compare the reason with the displayed evidence.

**Expected Results:**

- Detail explains why the ingredient is recommended.
- The reason matches the quantitative evidence.
- Almost-ready and frequently-used benefits appear only when applicable.
- Closing the detail does not change Pantry or Shopping.

**Possible Regression Areas:**

- Responsive bottom sheet
- Recipe names and readiness percentages
- Technical error visibility

## Test 3

**Feature:** Explicit Add to Shopping

**Test Steps:**

1. Open a recommendation.
2. Select Add to Shopping.
3. Return to Shopping.
4. Repeat Add to Shopping for the same recommendation.

**Expected Results:**

- The first explicit action adds or updates one canonical Shopping item.
- Repeated actions do not create duplicates.
- Existing compatible Shopping quantity is preserved or increased correctly.
- Pantry remains unchanged until Shopping completion.

**Possible Regression Areas:**

- Canonical Ingredient Resolution
- Shopping duplicate prevention
- Shopping quantity and unit
- Pantry merge and Undo

## Test 4

**Feature:** Automatic Recommendation Refresh

**Test Steps:**

1. Note the current recommendation order.
2. Add or edit a Pantry ingredient.
3. Delete a Pantry ingredient.
4. Complete a Shopping item into Pantry.

**Expected Results:**

- Recommendations refresh after every Pantry change.
- Recommendation evidence and order reflect the latest Pantry.
- Completed Shopping coverage is reflected through the updated Pantry.
- No manual refresh or app restart is required.

**Possible Regression Areas:**

- Pantry create/edit/delete
- Shopping completion
- Pantry Insights counters
- Recipe Repository loading

## Test 5

**Feature:** Advisory Product Behavior

**Test Steps:**

1. Dismiss a recommendation panel.
2. Open any Recipe with missing ingredients.
3. Continue to Start Cooking.

**Expected Results:**

- Dismissal is optional and does not mutate data.
- Users can browse any Recipe.
- Users can continue cooking despite missing ingredients.
- Recommendations never force Shopping actions.

**Possible Regression Areas:**

- Recipe browsing
- Start Cooking
- Recommendation dismissal
- Navigation

## Test 6

**Feature:** Responsive Layout and Safe Errors

**Test Steps:**

1. Test Pantry and Shopping at phone and desktop widths.
2. Open recommendation detail at both widths.
3. Temporarily test retry behavior if a load error is observable.

**Expected Results:**

- No overflow, overlap, or inaccessible action.
- Long reasons and Recipe names wrap correctly.
- Snackbars clear normally.
- No exception, UUID, stack trace, or internal code is shown.

**Possible Regression Areas:**

- Pantry layout
- Shopping layout
- Recommendation bottom sheet
- Snackbar persistence
