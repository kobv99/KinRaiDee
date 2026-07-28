# Changelog

## Unreleased

### Added

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

- `dart format --output=none --set-exit-if-changed .`: 135 files pass
  without changes.
- `flutter analyze`: pass, no issues.
- `flutter test --coverage`: 138 tests pass.
- Line coverage: 82.54% (5,078/6,152).
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
