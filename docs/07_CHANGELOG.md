# Changelog

## Unreleased

### Added

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

- `dart format --output=none --set-exit-if-changed .`: pass.
- `flutter analyze --no-pub`: pass, no issues.
- `flutter test --no-pub --coverage`: 104 tests pass.
- Line coverage: 80.55% (4,167/5,173).
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
