# Ingredient Substitution Knowledge Base

## Product rule

The application recommends. The user decides. Missing ingredients never block
cooking, and no recommendation automatically mutates Pantry, Recipe, or
Shopping.

## Data flow

```text
JSON Knowledge Base
        |
        v
KnowledgeBaseLoader (cached once)
        |
        v
IngredientSubstitutionRepository
        |
        v
IngredientSubstitutionService
        |
        +--> IngredientCompatibilityCalculator
        |
        `--> SubstitutionRankingService
                    |
                    v
          Explainable advisory result
```

## Domain model

Every record contains stable canonical IDs for the original and substitute,
confidence, flavor similarity, texture similarity, cooking-method
compatibility, suitable/unsuitable dishes, category, notes, flavor/texture
differences, and limitations.

The JSON schema is versioned. Domain models expose an extension map so future
nutrition, allergen, cost, regional, seasonal, preference, AI-confidence, and
vendor fields can be added without changing ranking consumers.

## Ranking

Pantry availability is the first ordering rule. Remaining deterministic
tie-breakers are confidence, flavor similarity, texture similarity,
cooking-method compatibility, then canonical substitute ID. Randomness is
forbidden.

## Storage ownership

Substitution facts exist only in
`assets/substitutions/ingredient_substitutions.json`. Services, repositories,
and presentation contain no ingredient-specific substitution rules. Replacing
the asset data source requires only another repository implementation.
