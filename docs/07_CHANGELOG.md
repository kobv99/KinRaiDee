# Changelog

## Unreleased

### Added

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

- `dart format --output=none --set-exit-if-changed .`: 130 files pass
  without changes.
- `flutter analyze`: pass, no issues.
- `flutter test --coverage`: 123 tests pass.
- Line coverage: 81.47% (4,521/5,549).
- Focused Shopping Foundation suite: 15 tests pass.
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
