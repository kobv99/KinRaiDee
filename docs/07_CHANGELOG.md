# Changelog

## Unreleased

### Added

- Transaction-safe single-entry deletion and clear-all retention controls for
  Cooking History, both protected by confirmation dialogs.
- Shared `UnitPresentation` localization coverage for Pantry, Recipe,
  Shopping, cooking, and Cooking History.
- Canonical artwork metadata and backward-compatible artwork fallback for
  Pantry lots previously created by Shopping.
- Regression coverage for Shopping-to-Pantry metadata, localized units,
  Cooking History retention, and narrow completion filters.
- Ingredient-aware Unit Policy with preferred units, recommended units, and
  optional unit families on every canonical ingredient.
- Compact Pantry unit selector plus an on-demand `Other unit…` path that
  preserves unusual historical units.
- Domain and widget coverage for fish, cooking oil, egg defaults, ingredient
  changes, and legacy-unit recovery.
- SF-003 Shopping screen with overview, active/completed sections, loading,
  error, and empty states.
- Multi-Recipe selection and duplicate-safe generation preview before durable
  confirmation.
- Shopping check/uncheck, quantity edit, delete confirmation, archive, restore,
  and recent-action undo controls.
- Canonical/alias/localized search, category/status/Recipe filters,
  deterministic sorting, and Pantry availability display.
- Shopping widget, interaction, projection, multi-Recipe, undo, failure, and
  restart integration tests.
- SF-002 `ShoppingEngine` for deterministic multi-Recipe aggregation, Pantry
  subtraction, canonical alias resolution, unit conversion, and merging
  existing Shopping demand.
- Shopping item lifecycle mutations for add, remove, quantity update,
  purchase, unpurchase, archive, restore, and clear completed.
- Atomic purchase-to-Pantry synchronization with immutable purchase receipts
  and conflict-safe undo.
- Shopping Engine aggregation, mutation, purchase, undo, idempotency,
  crash-recovery, rollback, and legacy-reader tests.
- SF-001 Shopping domain entities: `ShoppingList`, `ShoppingItem`,
  `ShoppingCategory`, `ShoppingStatus`, and `ShoppingSource`.
- Read-only Shopping repository backed by the durable transaction envelope.
- Recipe/Pantry shortage-to-Shopping draft builder using canonical ingredient
  and unit identities.
- Transaction-safe Shopping create, update, and remove mutations through
  `InventoryTransactionCoordinator`.
- Shopping model, repository, Riverpod durability, revision, idempotency, and
  restart-recovery tests.
- Canonical Ingredient Registry with globally unique IDs, localized names,
  aliases, search keywords, storage defaults, unit defaults, and versioned
  metadata.
- Deterministic Unit Contract with conversion validation and precision policy.
- Startup migration for legacy Pantry and cooking-history identity data.
- Canonical compatibility, migration, normalization, conversion, duplicate,
  unknown-value, and rounding tests.
- RFC-0003 `InventoryTransactionCoordinator` and serialized inventory writer.
- Versioned, checksummed Pantry/History commit envelope.
- Durable Hive transaction journal with restart recovery.
- Idempotent retry, duplicate commit, quick undo, and history cancel handling.
- Unit, crash-recovery, Hive integration, provider, and application-page tests.
- Injectable `AppClock` for deterministic expiry and transaction tests.

### Changed

- Shopping-to-Pantry commits now retain canonical artwork and localized display
  units while preserving canonical unit IDs for calculations.
- Shopping UI copy and filters now use Thai consistently; completion segments
  remain single-line and horizontally scroll when space is constrained.
- Pantry unit choices now refresh from canonical metadata/domain policy when
  the selected ingredient changes; invalid selections switch to the new
  preferred unit.
- The Unit Contract now includes `bulb` and `can`, and recognizes stem aliases
  for the existing stalk unit.
- Canonical unknown-ID hashing now uses web-compatible `BigInt` arithmetic while
  preserving the existing 64-bit FNV output exactly.
- Shopping presentation publishes no optimistic durable state; controls wait
  for `InventoryTransactionCoordinator` success before refresh.
- `ShoppingItem` metadata version 2 adds active/purchased/archived state,
  multiple Recipe source references, and optional purchase receipt.
- Inventory reader version 3 adds capability `shopping.engine.v1`; reader-v2
  SF-001 envelopes remain readable.
- Shopping validation now forbids duplicate active canonical ingredients and
  incompatible purchase units.
- `InventoryStateEnvelope` now supports capability-gated `shopping.v1` state
  while retaining checksum compatibility with pre-Shopping envelopes.
- Current envelope reader version is `2`; envelope schema remains version `1`.
- Phase 2 is now Shopping Foundation.
- Pantry, Recipe, Recommendation, deduction, and cooking-history transaction
  paths now carry canonical ingredient and unit IDs.
- Recipe quantity conversion now uses the shared Unit Contract.
- The bundled registry now covers every ingredient ID referenced by local
  recipes.
- Pantry quantities and cooking history now commit as one all-or-nothing
  snapshot.
- Riverpod state is published only after durable commit verification.
- All existing Pantry write paths now use the transaction coordinator.
- Startup recovery completes before application providers are initialized.
- Project Dart sources and tests are formatted consistently.

### Quality

- `dart format --output=none --set-exit-if-changed .`: 145 files pass
  without changes.
- `flutter analyze`: pass, no issues.
- The 39-file non-hanging regression suite passes all 160 tests, including the
  12-test ingredient-unit/catalog target. The remaining root widget test
  separately reaches `+1` before reproducing the known Windows finalizer hang.
- Regression line coverage: 83.13% (5,946/7,153).
- Focused Shopping Engine suite: 30 tests pass.
- Focused Transaction Engine regression: 23 tests pass.

## v0.1.0

### Added

- Flutter Setup
- Navigation
- Pantry
- Hive
- Riverpod

---

### Changed

- Initial Project Structure
