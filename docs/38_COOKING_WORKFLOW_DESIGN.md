# Cooking Workflow Design

## Two Separate Surfaces

Recipe Detail is a planning surface. It answers whether the user should cook
this Recipe: recommendation summary, serving selection, scaled ingredients,
missing ingredients, and the instructions as reference reading.

Cooking Mode is an assistance surface. It answers what to do right now. It is
opened as a dedicated full-screen route from Start Cooking, never as a popup
and never as an inline mode inside Recipe Detail.

## Recipe Detail Flow

Recipe → Recommendation Summary → Choose Serving → Review Missing Ingredients
→ Start Cooking.

The serving count chosen in Recipe Detail is the serving count used by Cooking
Mode and by the Pantry deduction plan.

## Cooking Mode Stages

1. Recipe Summary: Recipe name, serving count, cooking time, step count.
2. Ingredient Checklist: required, missing, and optional ingredients scaled to
   the selected serving count.
3. Cooking Steps: exactly one step at a time with `ขั้นตอน X / N`, a progress
   bar, the estimated remaining time, Previous, and Next.
4. Cooking Complete: congratulation, Recipe name, serving count, and elapsed
   time, with Favourites, Cooking History, and Rating reserved as future work.

Estimated remaining time sums the declared durations of the remaining steps.
When a Recipe does not declare step durations, the Recipe cooking time is
distributed evenly across the remaining steps.

## Navigation and Exit

Cooking Mode always offers Previous Step, Next Step, and Exit. Exiting between
the summary and the completion screen asks `ออกจากโหมดทำอาหาร?` and states that
progress will be lost. System back navigation goes through the same
confirmation.

## Cooking Session

Pressing Start on the summary stage creates a Cooking Session storing the
Recipe identity, the Recipe name, the serving count, and the start time. The
session ends as completed when the user finishes cooking and as abandoned when
the user confirms an exit. The session is the seed for cooking history,
statistics, and favourites, and it is kept in the presentation layer until a
persistence boundary is introduced.

## Focus Rules

Cooking Mode hides recommendation panels, the Recommendation Dashboard,
recommendation filters, and large recommendation cards. Voice mode, hands-free
mode, cooking timers, and keep-screen-awake behaviour are future work and must
not be simulated by the current UI.

## Pantry Effects

Pantry deduction happens once, when cooking completes. The deduction sheet
remains the single confirmation point, the deduction transaction remains
undoable from its snackbar, and a Recipe without deductible lots completes
without mutating Pantry.
