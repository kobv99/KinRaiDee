# Product Alignment: Pantry → Recipe → Shopping

## Non-Negotiable Product Philosophy

> The app recommends. The user decides.

KinRaiDee is an intelligent cooking assistant, not a workflow controller. Product
philosophy wins whenever it conflicts with technical convenience, implementation
simplicity, an existing screen, or an existing workflow.

Every recommendation is optional. Users may dismiss it, ignore it, cook anyway,
buy later, or substitute later. Readiness and candidate rules influence what the
application recommends; they never determine whether the user is allowed to open a
Recipe or start cooking.

## Scope

This sprint aligns existing Pantry, Recipe, and Shopping behavior before Smart
Shopping Recommendation. It does not add AI, substitutions, purchase optimization,
or a new recommendation model.

## Product Flow

```text
Pantry
  ↓
Candidate Recipes
  ↓
Recipe Readiness recommendation
  ↓
User selects one Recipe or cooks anyway
  ↓
Optional Add Missing Ingredients action
  ↓
Shopping
  ↓
Purchase
  ↓
Pantry update
```

Shopping is a consequence of Recipe planning. The Shopping screen routes users
back to Pantry-based Recipe selection instead of offering an unrelated generator.
No step in this flow is a mandatory gate for cooking.

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

- `primary`: defines whether a Recipe is meaningfully related to Pantry and has the
  largest readiness effect;
- `secondary`: supporting Recipe identity with a medium readiness effect;
- `optional`: a small readiness contribution that never blocks cooking or Shopping
  generation.

`weight` is a positive Recipe-specific contribution. Catalog defaults live in
`assets/recipes/ingredient_catalog.json`; each Recipe pack may override role,
weight, quantity, unit, aliases, or required status. Legacy string ingredient IDs
continue to load catalog defaults, but the Dart parser no longer owns the catalog.

Pad Kra Pao currently declares Pork and Holy Basil as Primary ingredients. Garlic
and Chili are Secondary. Optional additions can be represented directly in Recipe
data without changing a service or widget.

## Candidate Rule

`RecipeCandidateService` is the single domain owner of recommendation eligibility.
A Recipe becomes a recommendation candidate only when at least one declared Primary
ingredient is represented in Pantry.

Quantity may be insufficient and the Pantry unit may require user resolution; both
still establish a meaningful ingredient relationship. Missing or unresolved
Primary ingredients do not.

Examples:

- Pantry contains only Egg → Pad Kra Pao is not recommended.
- Pantry contains Pork → Pad Kra Pao may be recommended.
- Pantry contains Holy Basil → Pad Kra Pao may be recommended.

Candidate exclusion only affects recommendation surfaces. It never prevents direct
Recipe access or cooking.

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

Readiness is advisory. A low score may change recommendation language and suggested
Shopping actions, but it never disables Start Cooking.

## Recipe Detail Advisory

Recipe Detail keeps the ingredient list and cooking instructions as the primary
content. Readiness is shown as a neutral advisory panel that is:

- compact by default;
- expandable for missing and optional details;
- dismissible for the current Recipe session;
- non-overlapping with Recipe content;
- explicit that cooking remains available;
- actionable through an optional Add Missing Ingredients button.

The panel never says that the user cannot cook. It uses recommendation language
such as “เราแนะนำให้เตรียมเพิ่ม” and explains that flavor or authenticity may
change. Closing the panel immediately returns the full space to Recipe content.

## Cooking Freedom

Start Cooking remains available regardless of readiness or missing ingredients.
Completion and Pantry deduction are separate explicit user decisions. The user may
finish cooking without an automatic deduction when no compatible Pantry quantity
is available.

No Recipe candidate, readiness, or Shopping service is permitted to become a
cooking authorization gate.

## Shopping Generation

`RecipeMissingShoppingController` verifies candidate eligibility before calling
`ShoppingEngine.generate`. The engine receives one user-selected Recipe and adds
only its missing required ingredients after Pantry subtraction and unit conversion.
The UI does not decide candidate eligibility, importance, readiness, or generation.

Shopping generation occurs only after the user explicitly chooses Add Missing
Ingredients. Recommendations never mutate Shopping automatically.

The legacy multi-Recipe sheet is no longer a Shopping entry point and is restricted
to candidate Recipes if invoked by older navigation or tests.

## Pantry Merge

Shopping completion resolves canonical identity and attempts a deterministic merge
into the oldest compatible Pantry record. Compatible canonical ingredients must not
create duplicates.

When units cannot be converted, the user may:

- keep the purchase as a separate Pantry record;
- view the future unit-conversion action;
- cancel without mutation.

`PantryCanonicalMergeService` owns merge and explicit separate-record behavior.
Presentation never creates Pantry records directly.

## Terminology

Current product flows use Pantry terminology consistently, including:

- `เพิ่มเข้า Pantry`;
- `Pantry อัปเดตแล้ว`;
- `คืนรายการและจำนวนใน Pantry แล้ว`.

User-facing copy must not reintroduce `เข้าตู้` or `เก็บเข้าตู้` without an explicit
future product decision.

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
- compact, expandable, dismissible readiness UI;
- cooking remains available after dismissing recommendations;
- responsive layouts produce no overlap or overflow;
- candidate-only explicit Shopping generation;
- no duplicate Shopping or compatible Pantry items;
- incompatible-unit cancel and keep-separate behavior;
- Shopping navigation back to Pantry-based Recipe planning;
- safe presentation errors without internal identifiers;
- existing completion, Undo, persistence, and recovery behavior.

PR #7 remains Draft until formatting, analysis, the full Flutter suite, manual web
verification, and product acceptance are recorded on the current head.
