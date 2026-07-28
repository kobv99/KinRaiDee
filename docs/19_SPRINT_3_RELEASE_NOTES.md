# Sprint 3 Release Notes – Smart Shopping Recommendation Engine

## Added

- Deterministic Smart Shopping impact scoring.
- Recommendation types for unlocking Recipes, improving readiness, completing
  almost-ready Recipes, and frequently used ingredients.
- Domain-generated recommendation explanations.
- Impact Score and reason in recommendation detail.

## Improved

- Ranking now includes ingredient frequency and existing Pantry synergy.
- Recommendation responsibilities are separated into service, score calculator,
  and explanation builder.
- Architecture documentation for the Pantry-to-Shopping recommendation flow.

## Fixed

- Recommendation explanation logic no longer belongs to presentation code.

## Known Limitations

- Recommendations use local deterministic data only.
- Purchase price, package size, retailer availability, and budget are not
  considered.
- Product Acceptance remains pending Product Owner manual testing.

## Out of Scope

- AI and LLM integration
- Ingredient Substitution
- Budget Optimization
- Food Waste Reduction
- Meal Planning
- Automatic Shopping mutation
