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

## Feature: Canonical Recipe coverage

**Test Steps**

1. Keep only Rice in Pantry and open Recipe recommendations.
2. Replace Pantry with Mackerel and review recommendations.
3. Replace Pantry with Sea Bass and review recommendations.

**Expected Results**

- Rice unlocks Fried Rice, Steamed Rice, or Rice Porridge.
- Mackerel unlocks Fried Mackerel and Mackerel Chili Paste.
- Sea Bass unlocks Fried Sea Bass, Steamed Sea Bass with Lime, and Spicy Sea
  Bass Soup.
- Generic Fish, Mackerel, Tilapia, Salmon, and Sea Bass remain distinct
  canonical ingredients.

**Possible Regression Areas**

- Recipe data loading
- Primary Ingredient ranking
- Canonical ingredient matching
- Pantry recommendation cards

## Feature: Substitution visibility and acceptance

**Test Steps**

1. Open a Recipe whose required ingredient is missing and whose
   `supportsSubstitutions` flag is enabled.
2. Confirm the Knowledge Base contains a substitute and put that substitute in
   Pantry.
3. Press `ยอมรับตัวเลือกแทน`.
4. Navigate away and return to the same Recipe.
5. Repeat with a Recipe that has `supportsSubstitutions` disabled.

**Expected Results**

- Substitutions appear only when all three conditions are true: the Recipe
  supports substitutions, a required ingredient is missing, and the Knowledge
  Base contains at least one substitute.
- Pressing Accept changes Recipe Readiness to Substituted.
- The selected row shows `ใช้ตัวเลือกนี้แล้ว` and a Thai confirmation message.
- The accepted recommendation remains visible after navigation or rebuild.
- A Recipe with substitutions disabled shows no substitution panel.
- No English canonical ID is displayed.

**Possible Regression Areas**

- Recipe Readiness
- Riverpod rebuilds
- Thai localization
- Recipe detail responsive layout

## Feature: Recipe screen responsive layout

**Test Steps**

1. Open a Recipe with multiple substitution recommendations.
2. Test at 360×640 and a wider desktop viewport.
3. Scroll the substitution panel and the Recipe content.

**Expected Results**

- No `BOTTOM OVERFLOWED BY XX PIXELS` message appears.
- Recommendation content scrolls inside its bounded panel.
- Recipe content and Start Cooking remain reachable.

**Possible Regression Areas**

- Column and Expanded layout
- Nested scrolling
- SafeArea
- Large text scaling

## Feature: Thai Pantry Essentials completeness

**Test Steps**

1. Search Pantry using both the primary Thai name and an alias for Salmon,
   Tilapia, Shallot, Coriander, and Palm Sugar.
2. Add each ingredient and open Recipe recommendations.
3. Open the new Tilapia and Salmon Recipes and review their ingredient lists
   and instructions.

**Expected Results**

- `ปลาแซลมอน`, `แซลมอน`, and `salmon` resolve to the same canonical ingredient.
- `หอมแดง`, `ผักชี`, and `น้ำตาลปี๊บ` are available as Thai Pantry Essentials.
- Tilapia and Salmon participate in species-specific Recipes.
- Shallot, Coriander, and Palm Sugar participate in at least one Recipe.
- Every new Recipe ingredient has an explicit Primary, Secondary, or Optional
  role.
- Every new Recipe contains complete ordered instructions rather than a generic
  one-line placeholder.

**Possible Regression Areas**

- Pantry Search and aliases
- Canonical merge
- Recipe recommendation coverage
- Recipe Readiness weighting
- Shopping ingredient localization
