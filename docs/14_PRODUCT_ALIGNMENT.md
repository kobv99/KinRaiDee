# Product Alignment: Pantry → Recipe → Shopping

## Scope

This sprint aligns existing Pantry, Recipe, and Shopping behavior before Smart
Shopping Recommendation. It does not add AI, substitutions, purchase optimization,
or a new recommendation model.

## Product Flow

```text
Pantry
  ↓
RecipeCandidateService
  ↓
Recipe Readiness and ranking
  ↓
User selects one Recipe
  ↓
Missing required ingredients
  ↓
Shopping
  ↓
Purchase
  ↓
Pantry update
```

Shopping is a consequence of Recipe planning. The Shopping screen routes users
back to Pantry-based Recipe selection instead of offering an unrelated generator.

## Data-Driven Recipe Ingredients

Recipe ingredient behavior is declared in data, not presentation code.

```json
{
  "id": "holy_basil",
  "role": "primary",
  "weight": 35
}
```

Supported roles:

- `primary`: defines whether a Recipe is related to the Pantry and has the largest
  readiness effect;
- `secondary`: required support with a medium readiness effect;
- `optional`: does not block cooking or Shopping generation and has a small effect.

`weight` is a positive Recipe-specific contribution. Catalog defaults live in
`assets/recipes/ingredient_catalog.json`; each Recipe pack may override role,
weight, quantity, unit, aliases, or required status. Legacy string ingredient IDs
continue to load catalog defaults, but the Dart parser no longer owns the catalog.

Pad Kra Pao currently declares Pork and Holy Basil as Primary ingredients. Garlic
and Chili are Secondary. Optional additions can be represented directly in the
Recipe data without changing a service or widget.

## Candidate Rule

`RecipeCandidateService` is the single domain owner of recommendation eligibility.
A Recipe is a candidate only when at least one declared Primary ingredient is
represented in Pantry.

Quantity may be insufficient and the Pantry unit may require user resolution; both
still establish a meaningful ingredient relationship. Missing or unresolved
Primary ingredients do not.

Examples:

- Pantry contains only Egg → Pad Kra Pao is not a candidate.
- Pantry contains Pork → Pad Kra Pao is a candidate.
- Pantry contains Holy Basil → Pad Kra Pao is a candidate.

All recommendation lists, ranking, Random Recipe pools, and legacy Shopping
selection consume this candidate projection rather than the complete Recipe list.

## Readiness

`RecipeReadinessService` remains quantity-aware and uses the data weight for each
ingredient. Availability contributes proportionally:

```text
contribution = weight × clamp(available / required, 0, 1)
readiness = sum(contributions) / sum(weights)
```

Explicit data weights win. Role defaults exist only for backward compatibility.
Optional ingredients are excluded from missing-required Shopping output.

## Shopping Generation

`RecipeMissingShoppingController` verifies candidate eligibility before calling
`ShoppingEngine.generate`. The engine receives one user-selected Recipe and adds
only its missing required ingredients after Pantry subtraction and unit conversion.
The UI does not decide candidate eligibility, importance, readiness, or generation.

The legacy multi-Recipe sheet is no longer a Shopping entry point and is restricted
to candidate Recipes if invoked by older navigation or tests.

## Pantry Unit Mismatch

Internal merge failures never reach the user. When a purchased item cannot merge
with an existing Pantry record because its unit family is different, the user may:

- keep the purchase as a separate Pantry record;
- view the future unit-conversion action;
- cancel without mutation.

`PantryCanonicalMergeService` owns the explicit separate-record behavior.

## Error Boundary

Presentation code maps transaction and loading failures to user-facing outcomes.
It never appends internal error codes, UUIDs, object IDs, entity names, stack
traces, or raw exception messages. Technical codes remain available to domain and
test layers only.

## Verification

Required automated coverage includes:

- Recipe data role and weight parsing;
- Egg-only rejection for Pad Kra Pao;
- Pork and Holy Basil candidate acceptance;
- weighted candidate ranking;
- candidate-only Shopping generation;
- no duplicate Shopping items;
- incompatible-unit cancel and keep-separate behavior;
- Shopping navigation back to Pantry-based Recipe planning;
- existing completion, Undo, persistence, and recovery behavior.

PR #7 remains Draft until formatting, analysis, the full Flutter suite, manual web
verification, and product acceptance are recorded on the current head.
