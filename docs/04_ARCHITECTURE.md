# Architecture

## Folder Structure

- app
- core
- features
- shared

---

## State Management

Riverpod

---

## Database

Hive

---

## Routing

GoRouter

---

## Architecture Style

Clean Architecture

---

## Inventory Transaction Engine

Inventory quantity and cooking-history mutations follow RFC-0003:

1. Presentation code sends a command to `InventoryTransactionCoordinator`.
2. The coordinator validates the full command against the current durable
   revision and creates the next `InventoryStateEnvelope`.
3. `HiveInventoryCommitRepository` persists the transaction journal, writes
   the complete Pantry/History envelope, flushes Hive, and verifies its
   checksum before reporting success.
4. Riverpod publishes the committed Pantry and History snapshot only after the
   repository reports a durable commit.
5. Startup recovery resumes or rolls back every non-terminal journal record
   before `ProviderScope` is created. Ambiguous or corrupt storage fails closed
   with a recovery-required screen.

### Persistence ownership

- `InventoryStateEnvelope` is the single durable source of truth for Pantry
  quantities and cooking history.
- `InventoryTransactionRecord` is the durable recovery journal.
- `InventoryTransactionCoordinator` is the only supported write boundary for
  cooking completion, quick undo, history adjustment/cancel, and manual Pantry
  mutations.
- `PantryRepository` remains a read boundary plus favorite-name persistence; it
  cannot write inventory quantities.

### RFC implementation note

The implementation adds the internal `pantryMutation` transaction kind. This
does not add product behavior; it applies RFC-0003's single-writer and revision
rules to existing add, edit, delete, favorite, and clear Pantry operations.
Those operations therefore cannot bypass the durable envelope.

### Versioning

- Envelope version: `1`
- Minimum readable envelope version: `1`
- Transaction schema version: `1`
- Every successful mutation increments the envelope revision exactly once.
- Transaction IDs are secure UUID v4 values.

---

## Canonical Ingredient System

Pantry, Recipe, Recommendation, and future Shopping code share one stable
ingredient identity:

1. `IngredientCatalog` validates the bundled master data and constructs
   `CanonicalIngredientRegistry`.
2. Registry resolution accepts canonical IDs, localized names, aliases, and
   search keywords. Ambiguous and unknown values are never guessed.
3. `CanonicalIngredientMigration` projects legacy Pantry lots and cooking
   history to schema version 2 without changing the user's name, display unit,
   quantity, timestamps, or lot identity.
4. The projection is committed through `InventoryTransactionCoordinator` and
   the durable journal before `ProviderScope` publishes state.
5. Recipe matching, serving calculations, deduction planning, and
   recommendations compare canonical IDs first. Text matching exists only as a
   read-only compatibility path for pre-migration fixtures and imports.

### Identity ownership

- `CanonicalIngredient.id` is the domain identity shared across features.
- `Ingredient.id` remains the unique Pantry lot identity because multiple
  purchases of one canonical ingredient may have different expiry dates.
- `RecipeIngredient.id` is the canonical ingredient ID.
- `PantryQuantityChange` and `CookingHistoryChange` persist both the lot ID and
  canonical ingredient/unit IDs so retry, undo, adjustment, and cancel retain
  identity.
- Unknown values receive a deterministic `unmapped_*` identity and a migration
  issue. They remain fully usable as Pantry data but do not silently match a
  Recipe.

### Unit ownership

`UnitConversionEngine` is the only quantity conversion contract. Each
`UnitDefinition` declares its dimension, canonical base path, aliases, display
name, conversion factor, precision, and version. Validation rejects duplicate
IDs, duplicate aliases, missing parents, dimension mismatches, and circular
graphs. Invalid runtime conversions return a typed failure rather than
mutating inventory.

See [Canonical Ingredient Domain](09_CANONICAL_INGREDIENT_DOMAIN.md) and
[Canonical Ingredient Data Model](10_CANONICAL_INGREDIENT_DATA_MODEL.md).
