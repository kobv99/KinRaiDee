# Canonical Ingredient Domain

## Purpose

The Canonical Ingredient System gives Pantry, Recipe, Recommendation, and
Shopping one deterministic offline identity and one unit contract. SF-001
introduces Shopping lists and items; SF-002 adds aggregation and atomic
purchase-to-Pantry synchronization while continuing to exclude Shopping UI,
retailer catalogs, and pricing.

## Canonical Ingredient

`CanonicalIngredient` contains:

- globally unique normalized `id`;
- canonical English name;
- optional locale-to-name map;
- aliases and search keywords;
- category;
- default storage type;
- default purchase unit ID;
- default inventory unit ID;
- optional parent ingredient ID for compatible ingredient families; and
- metadata schema version, revision, and source.

The bundled registry is loaded by `IngredientCatalog`. Duplicate IDs, invalid
metadata, missing parents, and circular redirects fail startup validation.

## Resolution Rules

Resolution order is:

1. preferred existing canonical ID;
2. canonical ID or redirect;
3. canonical name;
4. localized name;
5. alias;
6. search keyword.

Exactly one result is required. Multiple results are `ambiguous`; no result is
`unknown`. Neither case is guessed. The migration stores a deterministic
`unmapped_*` ID and reports an `IngredientMigrationIssue`.

The default redirect maps legacy `chicken_breast` to `chicken`. Therefore
`Chicken Breast`, `Chicken breast`, `Chicken`, `Boneless Chicken Breast`, and
`อกไก่` share the `chicken` identity.

## Lot Identity Versus Ingredient Identity

A Pantry record is a lot, not the ingredient master:

- `Ingredient.id`: unique Pantry lot;
- `Ingredient.canonicalIngredientId`: the ingredient type;
- `Ingredient.canonicalUnitId`: the quantity unit;
- `Ingredient.name` and `Ingredient.unit`: preserved user-facing values.

Multiple lots may share one canonical ingredient ID while retaining different
quantities, purchase times, and expiry dates.

## Unit Contract

Each `UnitDefinition` has a canonical ID, dimension, display name, aliases,
optional parent base unit, factor to parent, decimal places, and version.

The engine converts by:

1. resolving source and target aliases to canonical unit IDs;
2. verifying a shared root and dimension;
3. converting source to root, then root to target; and
4. applying target precision with half-up rounding.

The default precision is three decimals with a `0.000001` zero tolerance.
Negative and non-finite quantities fail. Unknown and incompatible units return
typed failures. Duplicate aliases and circular conversions prevent contract
construction.

## Feature Contracts

- Pantry normalizes new and edited lots before durable mutation.
- Recipe ingredient `id` is a canonical ingredient ID.
- Recipe matching compares canonical IDs first.
- Recommendation hero keys use canonical IDs.
- Serving and deduction use `UnitConversionEngine`.
- Transaction and history changes store lot and canonical identities.
- Shopping items reference `canonicalIngredientId` and canonical `unitId`;
  Shopping does not create a second ingredient master.
- Shopping Engine aggregation converts every requirement to the canonical
  default purchase unit before subtracting Pantry or merging list entries.

## Validation Evidence

Relevant tests:

- `test/core/domain/ingredients/canonical_ingredient_registry_test.dart`
- `test/core/domain/units/unit_contract_test.dart`
- `test/features/pantry/application/canonical_ingredient_migration_test.dart`
- `test/features/recipe/canonical_ingredient_compatibility_test.dart`
- `test/features/recipe/ingredient_catalog_test.dart`
