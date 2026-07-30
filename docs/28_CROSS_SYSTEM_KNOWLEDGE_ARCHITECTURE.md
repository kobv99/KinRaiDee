# Cross-System Knowledge Architecture

## Problem statement

The previous design allowed the Pantry catalog, canonical ingredient registry,
hierarchy, Recipe packs, and substitution UI to evolve independently. That
created duplicate names, mixed category/ingredient identity, generic Recipe
steps, and UI workarounds.

## Target ownership

```text
Canonical Ingredient Catalog (selectable leaves)
        │
        ├── Ingredient Hierarchy (navigation placement only)
        ├── Pantry (canonical leaf + quantity/unit)
        ├── Recipe (canonical leaves + roles + structured steps)
        ├── Shopping (canonical leaf + purchase unit)
        └── Substitution (canonical leaf → canonical leaf facts)
```

The canonical catalog owns identity, aliases, Thai localization, storage, and
unit policy. The hierarchy owns browse relationships only. Recipes own cooking
facts. Substitution owns optional compatibility facts. Presentation reads these
contracts and never invents missing data.

## Selection state machine

```text
Select Ingredient
  ├── Browse → expand navigation → select leaf ─┐
  └── Search → select result (Quick Add) ───────┤
                                                ↓
                                  Quantity / Unit / Expiry
                                                ↓
                                         Pantry command
```

Search never opens Browse branches. Browse expansion never changes selection.
Once either mode selects a leaf, the picker is removed and Quantity receives
the canonical selection.

## Recipe contract

A Recipe contains canonical leaf ingredients, explicit roles, and an ordered
list of structured steps. Cooking progress derives from the list length.
Legacy string steps are accepted only as a migration input.

## Recommendation contract

Recipe Readiness and Substitution are pure projections of Recipe + Pantry +
Knowledge Base. UI preference (expanded/collapsed/hidden) is keyed by a
deterministic recommendation signature and cannot alter domain data.

## Validation boundary

Cross-asset validation runs after loading and before delivery tests. Invalid
references fail closed with an author-facing error. The UI never changes IDs,
injects aliases, treats categories as ingredients, or generates fake Recipe
coverage.

## Migration sequence

1. Establish structured Recipe steps and independent Browse/Search state.
2. Remove remaining UI-owned ingredient catalog consumers.
3. Replace generic identities with explicit unspecified-cut leaves and ID
   redirects.
4. Curate cut/species-specific Recipe coverage.
5. Require structured steps for every production Recipe and remove legacy
   generation fallback.

