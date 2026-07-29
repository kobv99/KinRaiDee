# Sprint 4 Manual Test Guide

Product Owner tests with `flutter run -d web-server`.

## Feature: Knowledge-based recommendations

**Test Steps**

1. Open a Recipe that is missing fish sauce, lime, or onion.
2. Ensure Pantry contains one listed substitute.
3. Review all substitute recommendations.

**Expected Results**

- Pantry-available substitutes rank first.
- Multiple substitutes are shown where the Knowledge Base provides them.
- Every result explains flavor, texture, compatibility, and limitations.
- The order is stable when data does not change.
- Users may ignore recommendations and continue cooking.

**Possible Regression Areas**

- Recipe Readiness
- Pantry matching
- Shopping recommendations
- Recipe detail responsive layout

## Feature: Advisory-only behavior

**Test Steps**

1. View and dismiss a substitution.
2. Continue to Start Cooking.
3. Check Pantry and Shopping.

**Expected Results**

- Viewing or dismissing never mutates data.
- Cooking remains available.
- No substitute is added to Pantry or Shopping automatically.

**Possible Regression Areas**

- Start Cooking
- Pantry persistence
- Shopping duplicate prevention

## Feature: Recommendation stability and Thai localization

**Test Steps**

1. Open a Recipe with a missing ingredient and note its recommendations.
2. Navigate away, return to the same Recipe, and refresh the page state.
3. Accept a Pantry-available substitute and navigate away and back again.

**Expected Results**

- The same Recipe and Pantry produce the same recommendations in the same order.
- Recommendations remain visible after navigation, refresh, and acceptance.
- Ingredient labels are Thai, such as `ซีอิ๊ว`, `น้ำปลา`, `มะนาว`, and `เนย`.
- Canonical English IDs are not displayed as ingredient labels.

**Possible Regression Areas**

- Recipe Readiness
- Recipe detail state
- Canonical ingredient resolution
- Responsive layout

## Feature: Canonical fish granularity

**Test Steps**

1. Add `ปลาทู`, `ปลานิล`, `ปลาแซลมอน`, and `ปลากะพง` separately.
2. Search Pantry for each ingredient.
3. Review Recipe matching for each fish.

**Expected Results**

- Each fish remains a separate canonical ingredient.
- One fish species does not satisfy another species or generic `Fish`.
- `Seafood` is used for organization only, not as a Recipe ingredient match.

**Possible Regression Areas**

- Pantry merge
- Pantry search
- Recipe matching
- Shopping recommendations

## Feature: Fried Rice recommendation

**Test Steps**

1. Add only Rice to Pantry and open Recipe recommendations.
2. Add Egg and Soy Sauce, then review recommendations again.

**Expected Results**

- Fried Rice is a candidate when Rice is present.
- Adding Egg and Soy Sauce increases its readiness and priority.
- Missing optional ingredients do not remove Fried Rice from recommendations.

**Possible Regression Areas**

- Primary Ingredient ranking
- Recipe Readiness score
- Recommendation ordering

## Feature: Pantry Search position

**Test Steps**

1. Open Pantry on a narrow browser viewport.
2. Repeat with Pantry Insights, recommendation cards, and expiring items visible.

**Expected Results**

- Search is the first Pantry content control and remains above cards.
- No recommendation or insight card pushes Search below the fold.

**Possible Regression Areas**

- Pantry responsive layout
- Pantry Insights
- Recent and frequent ingredient sections
