# Recipe Readiness and Smart Shopping Foundation

## Product Rule

Pantry is the starting point for cooking decisions. Recipe Readiness answers:

> What can I cook with what I already have?

Readiness is a deterministic domain projection. It is not AI-generated and is
not persisted separately from Recipe and Pantry data.

## Source of Truth

- Recipe ingredients define required quantities, units, optional status, and
  optional readiness metadata.
- Pantry inventory provides the current canonical quantity snapshot.
- `CanonicalIngredientRegistry` owns ingredient identity resolution.
- `UnitConversionEngine` owns all quantity conversion and precision rules.
- `RecipeReadinessService` combines those inputs into a derived result.

Recomputing the projection whenever Pantry, Recipe version, or servings changes
prevents stale readiness records and avoids a second persistence schema.

## Domain Model

`RecipeIngredient` remains backward compatible and may additionally declare:

- `importance`: `main`, `supporting`, or `garnish`;
- `readinessWeight`: an explicit positive scoring override.

Existing Recipe packs require no migration. When metadata is absent, the service
uses Recipe hero identity and required/optional status.

`RecipeReadiness` exposes:

- score and rounded percentage;
- available ingredients;
- missing required ingredients;
- optional ingredients;
- missing optional ingredients;
- per-ingredient required, available, and shortage quantities;
- canonical identity, weight, availability ratio, and typed status.

## Weighted Scoring

Default weights:

| Ingredient role | Weight |
|---|---:|
| Hero/main ingredient | 5.0 |
| Required supporting ingredient | 2.0 |
| Optional ingredient | 0.5 |
| Garnish | 0.25 |

The score is quantity-aware:

```text
ingredient contribution = weight × clamp(available / required, 0, 1)
readiness = sum(contributions) / sum(weights)
```

A partially available ingredient therefore contributes proportionally. Missing a
main protein has a much larger effect than missing garnish.

Explicit ingredient weight wins over importance. Explicit importance wins over
hero/required/optional fallback.

## Canonical and Unit Rules

For each Recipe ingredient, resolution order is:

1. canonical ingredient ID or redirect;
2. stable registry key;
3. localized name or canonical name;
4. aliases.

Pantry display-name equality is never an identity rule. Legacy Pantry records
without canonical IDs may use the registry name path as a read-only compatibility
fallback.

After redirect resolution, Recipe Readiness requires the exact same canonical ID.
Parent/child ingredient families are not treated as substitutions in this sprint.
That boundary is reserved for the future Ingredient Substitution feature.

All non-expired, positive Pantry records with the exact resolved identity are
converted into the Recipe unit and summed. Incompatible units produce a typed
status and contribute zero rather than being silently merged or guessed.

## Riverpod Projection

- `recipeReadinessServiceProvider` wires registry and unit contracts.
- `recipeReadinessProvider` evaluates one Recipe and serving count.
- `recipeReadinessListProvider` guarantees one result for every loaded Recipe.

The family cache key includes Recipe ID, Recipe version, and servings. Pantry and
clock changes are watched dependencies, so inventory updates recalculate the
projection.

## Recipe Detail

Recipe Detail displays a bounded, scrollable readiness panel below the existing
AppBar. It shows:

- readiness percentage and progress;
- available, missing, and optional counts;
- ingredient groups and shortage quantities;
- one action to add required shortages to Shopping.

The existing serving, cooking checklist, Pantry deduction, Cooking History, and
Undo flows remain unchanged.

The readiness action currently uses the Recipe's configured serving count. A
future shared serving-selection state may synchronize all Recipe Detail sections;
that is outside this focused sprint.

## Add Missing Ingredients to Shopping

The UI invokes one application action:

```text
Add Missing Ingredients(recipe, servings)
```

`RecipeMissingShoppingController`:

1. loads the current actionable Shopping list;
2. calls the existing `ShoppingEngine.generate` with Recipe, Pantry, and servings;
3. excludes optional ingredients by default;
4. detects no-missing and unchanged outcomes;
5. executes one durable `ShoppingMutation.upsert`.

The controller depends on a `ShoppingMutationExecutor` function rather than a
Riverpod provider or concrete presentation controller. Provider wiring stays at
the presentation boundary.

Canonical duplicate avoidance, unit conversion, Pantry subtraction, active manual
intent, revisions, durable commit, and recovery all remain owned by the existing
Shopping Engine and transaction coordinator.

## Pantry Completion

This sprint does not add another Pantry write path. Shopping completion continues
to call the canonical Pantry merge service introduced by the Shopping workflow.
Completing purchased items therefore updates compatible inventory instead of
creating duplicate canonical Pantry records.

## Future Extension Points

The readiness result is intentionally reusable by future features:

- Smart Shopping prioritization;
- Ingredient Substitution;
- AI Cooking Advisor;
- Purchase Optimization.

None of those features is implemented here. Future systems consume the typed
readiness result rather than duplicating Pantry matching or scoring logic.

## Validation Targets

- hero/main and garnish weighting;
- partial quantity scoring;
- convertible-unit aggregation;
- localized identity fallback;
- exact identity without substitution;
- expired Pantry exclusion;
- every Recipe receives a result;
- Recipe Detail groups and score;
- one-click batch Shopping upsert;
- repeated action produces no duplicate canonical Shopping item;
- fully ready Recipes do not create empty Shopping lists;
- existing Shopping completion still performs canonical Pantry merge.
