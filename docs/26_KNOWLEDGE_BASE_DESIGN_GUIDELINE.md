# Knowledge Base Design Guideline

## Boundaries

The Knowledge Base consists of versioned ingredient, hierarchy, Recipe, and
substitution assets. Loaders translate assets into domain entities. Widgets do
not repair, infer, or hardcode missing Knowledge Base data.

## Required validation

Delivery validation must reject:

- duplicate or missing canonical IDs;
- category/family nodes marked selectable;
- selectable hierarchy leaves without a canonical ingredient;
- a canonical leaf placed in multiple unrelated families;
- Recipe or substitution references to unknown IDs;
- Recipe references to navigation nodes;
- ambiguous aliases;
- missing Thai display names;
- empty, vague, or invalid Recipe steps;
- step ingredient IDs not present in the Recipe;
- substitution self-references or duplicates;
- major canonical ingredients with no Recipe participation.

## Coverage policy

Thai Pantry Essentials are a maintained required set. Each major ingredient
must participate in at least one meaningful Recipe. Coverage is improved by
curating data, not by special-case recommendation code.

## Change process

1. Add or change canonical leaves.
2. Place leaves in the navigation hierarchy.
3. Add aliases and localization.
4. Add Recipe participation and realistic instructions.
5. Add substitution facts only where culinary compatibility is documented.
6. Run cross-asset validation and automated tests.

