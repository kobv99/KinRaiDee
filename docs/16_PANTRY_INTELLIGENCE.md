# Pantry Intelligence

## Product rule

> The application recommends. The user decides.

Pantry remains the primary content, the source of recommendation context, and
the durable inventory projection. Recommendations never mutate Shopping without
an explicit user action.

## Data integrity

Every selectable Pantry catalog item must resolve to exactly one canonical
ingredient. The bundled audit covers the complete selectable catalog and
explicitly verifies Chicken Breast, Duck, Tilapia, Ground Pork, Holy Basil, and
Thai Basil.

A successful Pantry transaction publishes the committed snapshot immediately.
Regression coverage verifies creation, canonical resolution, durable
persistence, search projection, UI state, and reload without manual refresh.

## Domain services

`PantryInsightService` derives:

- ingredient count;
- recipes ready now;
- recipes almost ready;
- unique missing canonical ingredient families; and
- recommendation summary.

`ShoppingRecommendationService` owns deterministic ranking, scoring,
explanation evidence, recipe unlock counts, readiness improvement, and active
Shopping coverage. Both services are reusable domain services; presentation
only renders their projections.

## User experience

The Pantry page keeps inventory primary and presents:

1. Pantry Summary;
2. Pantry Insights;
3. Recommended Purchases, limited to the top three;
4. Recently Added;
5. Pantry utilities, search, and ingredient list.

Recommendation details show why an ingredient is suggested, recipes unlocked,
readiness improvement, and top impacted recipes. Adding to Shopping is explicit,
duplicate-safe, and dismissible.

## Refresh behavior

Riverpod projections watch Pantry, Recipe, Shopping, and expiry state.
Recommendations and insights therefore recompute after Pantry create, edit,
delete, Shopping completion, or Shopping mutation without a mutable cache.

## Explicit exclusions

- no AI;
- no ingredient substitution;
- no automatic Shopping mutation;
- no Smart Shopping Optimization;
- no price, retailer, package, budget, or meal-planning logic.
