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

Inventory quantity and history mutations follow RFC-0003:

1. Presentation code sends a command to an application controller/coordinator.
2. The coordinator validates the full command against the current durable
   revision and creates the next `InventoryStateEnvelope`.
3. `HiveInventoryCommitRepository` persists the transaction journal, writes the
   complete Pantry/History/Shopping envelope, flushes Hive, and verifies its
   checksum before reporting success.
4. Riverpod publishes committed projections only after the repository reports a
   durable commit.
5. Startup recovery resumes or rolls back every non-terminal journal record
   before `ProviderScope` is created. Ambiguous or corrupt storage fails closed
   with a recovery-required screen.

### Persistence ownership

- `InventoryStateEnvelope` is the single durable source of truth for Pantry,
  Cooking History, and Shopping state.
- `InventoryTransactionRecord` is the durable recovery journal and owns the
  before/after snapshots used for Purchase History projection and Undo.
- `InventoryTransactionCoordinator` and feature-specific application
  coordinators are the supported write boundaries.
- `PantryRepository` and `ShoppingRepository` remain read boundaries; neither
  exposes inventory writes.
- Presentation code has no Hive import and never publishes optimistic durable
  state.

### RFC implementation note

The implementation includes `pantryMutation`, Shopping transaction kinds, and
history-retention transaction kinds. They all reuse RFC-0003's single-writer,
revision, checksum, rollback, idempotency, and restart-recovery rules. No feature
owns a separate persistence shortcut.

### Versioning

- Envelope version: `1`
- Current reader version: `3`
- Transaction schema version: `1`
- Every successful mutation increments the envelope revision exactly once.
- Transaction IDs are secure UUID v4 values.
- Reader version `2` adds the capability-gated `shopping.v1` projection.
  Envelopes written before Shopping remain checksum-compatible and readable.
- Reader version `3` adds `shopping.engine.v1` and atomic Shopping/Pantry
  synchronization. Reader-v2 Shopping envelopes remain readable until their
  first engine mutation.
- The actionable-only Shopping redesign does not require a new envelope version.
  Purchase History is projected from durable transaction records instead of
  duplicating the same snapshots in another Hive schema.

---

## Canonical Ingredient System

Pantry, Recipe, Recommendation, and Shopping code share one stable ingredient
identity:

1. `IngredientCatalog` validates the bundled master data and constructs
   `CanonicalIngredientRegistry`.
2. Registry resolution accepts canonical IDs, stable registry keys, localized
   names, aliases, and search keywords. Ambiguous and unknown values are never
   guessed.
3. `CanonicalIngredientMigration` projects legacy Pantry records and Cooking
   History to schema version 2 without changing quantity, timestamps, or record
   identity.
4. The projection is committed through the durable transaction journal before
   `ProviderScope` publishes state.
5. Recipe matching, serving calculations, deduction planning, Pantry merge, and
   recommendations compare resolved canonical IDs. Text is only an input to the
   registry's legacy alias compatibility path; display-name equality is never an
   inventory merge rule.

### Identity ownership

- `CanonicalIngredient.id` is the domain identity shared across features.
- `Ingredient.id` is the persisted Pantry record identity used by transaction
  snapshots and Undo.
- Pantry's product invariant is one compatible inventory record per resolved
  canonical ingredient. New add/update and Shopping-completion paths consolidate
  compatible legacy duplicates into one deterministic primary record.
- Intentionally incompatible/unknown units fail closed and require explicit
  conversion rather than silent merge.
- `RecipeIngredient.id` is the canonical ingredient ID.
- `PantryQuantityChange`, Cooking History, and Purchase History retain canonical
  ingredient/unit identity together with persisted record IDs.
- Unknown values receive a deterministic `unmapped_*` identity and a migration
  issue. They remain readable but are not silently matched.

### Unit ownership

`UnitConversionEngine` is the only quantity conversion contract. Each
`UnitDefinition` declares its dimension, canonical base path, aliases, display
name, conversion factor, precision, and version. Validation rejects duplicate
IDs, duplicate aliases, missing parents, dimension mismatches, and circular
graphs. Invalid runtime conversions return a typed failure rather than mutating
inventory.

`IngredientUnitPolicy` owns ingredient-aware input recommendations. It projects
canonical identity/category into a preferred unit, a short recommended-unit
list, and an optional family. Pantry presentation consumes that projection and
keeps the complete Unit Contract behind `Other unit…`; it contains no
ingredient-name branching. Existing non-recommended units remain readable and
editable without silent rewriting.

`PantryCanonicalMergeService` owns the shared merge algorithm used by manual
Pantry add/update and Shopping completion. It resolves canonical identity,
selects a deterministic primary record, converts all compatible quantities,
consolidates duplicates, and returns typed failures for incompatible units.

See [Canonical Ingredient Domain](09_CANONICAL_INGREDIENT_DOMAIN.md) and
[Canonical Ingredient Data Model](10_CANONICAL_INGREDIENT_DATA_MODEL.md).

---

## Shopping Foundation, Engine, and UI

SF-001 adds the local Shopping aggregate. SF-002 adds generation and inventory
synchronization. SF-003 exposes the offline workflow. The current product rule is
that Shopping contains unfinished work only:

1. `ShoppingList` owns versioned active `ShoppingItem` records.
2. Every item resolves to a valid canonical ingredient and canonical unit.
3. `ShoppingEngine` aggregates Recipes by canonical ingredient, converts to
   purchase units, subtracts non-expired Pantry, merges active manual intent,
   and drops legacy completed/archived records from regenerated lists.
4. `ShoppingRepository` projects active-only Shopping lists and durable Purchase
   History. It exposes no write method.
5. List generation, edit, and delete continue through
   `InventoryTransactionCoordinator.mutateShopping`.
6. `ShoppingCompletionCoordinator.completeItem` is the single completion action.
   It resolves canonical identity, calls `PantryCanonicalMergeService`, removes
   the Shopping item, and commits the complete envelope atomically.
7. Completion never stores a new Completed Shopping item. The durable
   `shoppingPurchase` transaction record becomes the Purchase History source.
8. `PurchaseHistoryProjector` derives timestamp, ingredient, quantity, Recipe
   sources, Shopping list/item IDs, Pantry transaction ID, and affected Pantry
   record IDs from committed journal snapshots.
9. `ShoppingCompletionCoordinator.undoCompletion` verifies the original
   transaction's affected Pantry state and atomically restores Pantry plus the
   active Shopping item. The inverse journal record removes the projected
   Purchase History entry.
10. `ShoppingCompletionController` publishes Pantry and invalidates Shopping and
    Purchase History only after durable success.
11. `ShoppingPage` triggers one `Complete Shopping Item` action, then displays
    `✓ เพิ่มเข้าตู้แล้ว` with a short Undo SnackBar. There is no Completed tab,
    Completed section, archive action, or restore action.
12. `ShoppingViewProjector` performs active-only alias/localized search,
    category/Recipe filtering, deterministic sorting, and Pantry availability
    conversion as a pure in-memory projection.
13. `ShoppingGenerationSheet` selects multiple Recipes, previews
    `ShoppingEngine.generate`, and commits only after confirmation.
14. `UnitPresentation` remains the shared display boundary for Pantry, Recipe,
    Shopping, Cooking History, and purchase quantities.

Existing purchased/archived records and their embedded receipts remain readable
for backward compatibility, but active projections never render them. The
transaction envelope remains the only Hive persistence path. There is no
Shopping-specific Hive box or direct storage access from presentation.

See [Shopping Foundation Domain Model](11_SHOPPING_FOUNDATION_DOMAIN.md) and
[Shopping UI and Pantry Completion Workflow](12_SHOPPING_UI.md).

---

## Smart Shopping Recommendation Flow

```text
Pantry
  |
  v
RecipeReadinessService
  |
  v
ShoppingRecommendationService
  |-- RecommendationScoreCalculator
  `-- RecommendationExplanationBuilder
  |
  v
Advisory recommendation UI
  |
  v
Explicit Add to Shopping
```

- Pantry is the origin of every recommendation calculation.
- `ShoppingRecommendationService` owns candidate discovery, canonical grouping,
  quantity simulation, impact evidence, deterministic ordering, and active
  Shopping coverage.
- `RecommendationScoreCalculator` owns the named impact weights for Recipes
  unlocked, readiness improvement, Primary/Secondary importance, ingredient
  frequency, Pantry synergy, and impacted Recipes.
- `RecommendationExplanationBuilder` converts verified domain evidence into
  recommendation types and a user-facing reason. Presentation code never
  derives scores, ranking, or explanations.
- Riverpod recomputes from Pantry, Recipe repository, and active Shopping
  projections. No mutable recommendation cache is maintained.
- Viewing or dismissing recommendations has no persistence effect. Only an
  explicit user action enters the existing canonical and duplicate-safe
  Shopping transaction workflow.

See [Smart Shopping Recommendation Engine](15_SMART_SHOPPING_RECOMMENDATION.md).
