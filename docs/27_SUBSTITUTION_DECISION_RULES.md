# Substitution Decision Rules

## Product rule

The application recommends. The user decides. A substitution is advisory and
must never block Recipe browsing, Start Cooking, Pantry, or Shopping.

## Visibility

A recommendation is visible only when all conditions are true:

1. the Recipe explicitly supports substitutions;
2. a required canonical leaf is missing;
3. the Knowledge Base contains an eligible substitute;
4. the substitute is not the same canonical ingredient;
5. the recommendation is valid for the current Recipe and Pantry signature.

The same Recipe + Pantry + Knowledge Base version produces the same ordered
recommendations.

## Interaction

- Initial state is compact.
- Users may expand, collapse, hide, reopen, accept, or ignore.
- Accept records an explicit choice; it does not automatically mutate Pantry.
- Hide removes occupied layout space and leaves a compact reopen affordance.
- A changed recommendation signature resets stale UI preference to compact.
- Navigating or rebuilding with unchanged inputs preserves the user choice.

## Matching

Substitution rules reference canonical selectable leaves only. Categories and
families may filter authoring tools but never match Recipes. Ranking uses
declared compatibility and Pantry availability with deterministic tie-breaks.

