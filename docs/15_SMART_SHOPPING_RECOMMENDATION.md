# Smart Shopping Recommendation Engine

## Product rule

The app recommends. The user decides.

Recommendations are optional. Viewing or dismissing a recommendation never changes Shopping or Pantry. Only an explicit Add to Shopping action may create or update Shopping intent.

## Domain flow

```text
Pantry + Recipes + active Shopping
              |
              v
     RecipeReadinessService
              |
              v
 ShoppingRecommendationService
       |               |
       v               v
RecommendationScore  RecommendationExplanation
    Calculator              Builder
              |
              v
 Structured recommendation + evidence + reason
              |
              v
 Optional dashboard presentation
              |
              v
 Explicit existing Shopping mutation workflow
```

Recommendation scoring, quantity planning, impact simulation, and ranking remain in the domain layer. The presentation layer only renders domain output.

## Candidate rules

The service evaluates missing or insufficient required Recipe ingredients. Optional-only ingredients, unresolved ingredients, incompatible units, and zero-benefit candidates are excluded.

Canonical parent-child compatibility is respected, so compatible Pantry and Shopping records do not create duplicate recommendations.

## Quantity policy

For each candidate ingredient the engine:

1. calculates each impacted Recipe shortage at its default serving count;
2. converts the shortages to the canonical purchase unit;
3. combines duplicate occurrences inside one Recipe;
4. uses the maximum single-Recipe shortage as target Shopping coverage;
5. subtracts compatible active Shopping coverage;
6. recommends only the remaining quantity.

The engine does not sum every Recipe shortage because that would assume the user will cook all Recipes.

## Impact and ranking

Every candidate is simulated as a temporary Pantry quantity and each impacted Recipe is re-evaluated through RecipeReadinessService.

The result records readiness before and after, Recipes unlocked, ingredient role, shortage quantity, and top impacted Recipes.

`RecommendationScoreCalculator` applies the default named policy weights:

- Recipes unlocked;
- total readiness increase;
- average readiness increase;
- Primary Recipe count;
- Secondary Recipe count;
- ingredient frequency;
- existing Pantry synergy;
- impacted Recipe count.

Stable tie-breaking uses score, Recipes unlocked, average readiness increase, then canonical ingredient ID.

## Recommendation types and explanations

ShoppingRecommendation, RecommendationEvidence, and RecommendationRecipeImpact are immutable domain models. They expose structured quantitative facts and future-compatible reason codes rather than a single formatted sentence.

`RecommendationExplanationBuilder` assigns any applicable advisory types:

- Unlock Most Recipes;
- Improve Recipe Readiness;
- Complete Almost Ready Recipes;
- Frequently Used Ingredient.

It also builds the user-facing reason entirely from verified evidence: Recipes
unlocked, readiness increase, almost-ready Recipes, frequency, and Pantry
synergy. The UI renders this output and never reconstructs explanations.

## Reactive updates

The Riverpod provider watches Pantry, Recipes, Shopping lists, the canonical registry, the unit contract, and the application clock. No hidden mutable recommendation cache is used.

## Shopping action

ShoppingRecommendationController routes the explicit action through the existing durable Shopping mutation workflow. It rechecks compatible active Shopping coverage, updates an existing item when possible, creates a new item only when required, and treats repeated stale actions as unchanged after target coverage is met.

## Verification

Verify deterministic ordering, Recipes unlocked, readiness improvement, optional exclusion, canonical compatibility, active Shopping coverage, explicit Add, duplicate-safe repeated Add, dismiss behavior, safe error text, and phone/desktop layout.
