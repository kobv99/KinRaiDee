# Recipe Readiness and Pantry Candidate Rules

## Product Rule

Pantry is the starting point for cooking decisions. Recipe evaluation answers:

> What can I cook with what I already have?

The flow is deterministic and domain-owned. It is not AI-generated and is not
persisted separately from Recipe and Pantry data.

## Source of Truth

- Recipe data declares ingredient identity, quantity, unit, role, and weight.
- `assets/recipes/ingredient_catalog.json` provides reusable defaults.
- Individual Recipe packs may override any ingredient metadata.
- Pantry provides the current canonical quantity snapshot.
- `CanonicalIngredientRegistry` owns ingredient identity resolution.
- `UnitConversionEngine` owns conversion and precision.
- `RecipeCandidateService` owns recommendation eligibility and ranking.
- `RecipeReadinessService` owns quantity-aware readiness.

Recomputing whenever Pantry, Recipe version, or servings changes prevents stale
records and avoids another persistence schema.

## Data-Driven Ingredient Model

`RecipeIngredient` supports:

- `role`: `primary`, `secondary`, or `optional`;
- `weight`: an explicit positive contribution to readiness;
- identity, aliases, quantity, and unit.

Example:

```json
{
  "id": "holy_basil",
  "role": "primary",
  "weight": 35
}
```

The Dart parser no longer owns a hardcoded ingredient catalog. Legacy string IDs
remain readable and resolve their defaults from JSON. Legacy `required`,
`importance`, and `readinessWeight` fields remain compatibility inputs, not the
preferred schema.

## Roles

| Role | Product meaning | Candidate behavior | Shopping behavior |
|---|---|---|---|
| Primary | Defines the Recipe's meaningful Pantry relationship | At least one must exist in Pantry | Missing amount is required |
| Secondary | Required support | Does not create a candidate alone | Missing amount is required |
| Optional | Nice-to-have or garnish | Does not create a candidate | Excluded by default |

A Recipe may have more than one Primary ingredient. Pad Kra Pao, for example, can
be related to Pantry through Pork or Holy Basil. Egg alone does not make it a
candidate.

## Candidate Recipes

`RecipeCandidateService` evaluates all Recipes against Pantry. A Recipe is returned
only when at least one Primary ingredient is represented in Pantry.

A positive but insufficient quantity still establishes a meaningful relationship.
An incompatible unit can also establish identity, but readiness remains a typed
unit-mismatch result. Missing or unresolved Primary ingredients do not.

Candidates are ranked by:

1. weighted readiness score;
2. fewer missing Primary ingredients;
3. fewer missing Secondary ingredients;
4. popularity and stable name ordering.

Recommendation lists and Random Recipe consume this candidate list. They never
start from the complete Recipe catalog.

## Weighted Readiness

The score is quantity-aware:

```text
ingredient contribution = weight × clamp(available / required, 0, 1)
readiness = sum(contributions) / sum(weights)
```

Explicit data weight wins. Role defaults exist only for legacy data:

| Role | Legacy fallback weight |
|---|---:|
| Primary | 5.0 |
| Secondary | 2.0 |
| Optional | 0.5 |
| Legacy garnish | 0.25 |

A partially available ingredient contributes proportionally. Missing a Primary
ingredient therefore has a much larger effect when the Recipe data assigns it a
large weight.

`RecipeReadiness` exposes:

- score and rounded percentage;
- available ingredients;
- missing required ingredients;
- optional ingredients;
- missing optional ingredients;
- per-ingredient required, available, and shortage quantities;
- canonical identity, role, weight, availability ratio, and typed status.

## Canonical and Unit Rules

Resolution order:

1. canonical ingredient ID or redirect;
2. stable registry key;
3. localized or canonical name;
4. aliases.

Display-name equality is never an identity rule. Exact canonical identity is
required after redirect resolution. Parent/child families are not substitutions.

All non-expired positive Pantry records with the identity are converted into the
Recipe unit and summed. Incompatible units produce a typed status and are never
guessed.

## Riverpod Projection

- `recipeReadinessServiceProvider` wires identity and unit contracts.
- `recipeCandidateServiceProvider` wires the candidate domain service.
- `recipeReadinessProvider` evaluates one Recipe and serving count.
- `recipeReadinessListProvider` returns one result per loaded Recipe.
- `recipeMatchesProvider` returns Pantry candidate Recipes only.
- `smartRecommendationProvider` ranks and pages only those candidates.

The cache identity includes Recipe ID, Recipe version, and servings. Pantry and
clock changes trigger recalculation.

## Recipe Detail and Shopping

Recipe Detail shows readiness groups and one action to add missing required
ingredients. `RecipeMissingShoppingController` first verifies that the selected
Recipe is still a candidate, then calls `ShoppingEngine.generate` with that Recipe,
Pantry, and servings.

The engine adds only missing required quantities, preserves existing active intent,
avoids canonical duplicates, and executes one durable Shopping mutation. Optional
ingredients are excluded by default.

The Shopping screen does not independently choose Recipes. Planning actions route
back to Pantry-based Recipe selection.

## Pantry Completion

Completing Shopping updates Pantry through `PantryCanonicalMergeService`.
Compatible units merge deterministically into the oldest durable Pantry record.
When units cannot be converted, the user may cancel, keep the purchase as a
separate Pantry record, or view the future conversion-configuration action.

Raw transaction codes, object IDs, UUIDs, exception messages, and stack traces are
never presentation text.

## Validation Targets

- data-driven role and weight parsing;
- Egg-only candidate rejection for Pad Kra Pao;
- Pork and Holy Basil candidate acceptance;
- role-/weight-aware ranking and readiness;
- partial quantity scoring;
- convertible-unit aggregation;
- incompatible-unit typed status and keep-separate action;
- expired Pantry exclusion;
- candidate-only Random Recipe and Shopping generation;
- one-click missing Shopping upsert;
- repeated action produces no canonical duplicate;
- fully ready Recipe produces no empty Shopping list;
- existing completion, Undo, persistence, and recovery remain durable.

Smart Shopping Recommendation, AI Cooking Advisor, Ingredient Substitution, and
Purchase Optimization remain future work.
