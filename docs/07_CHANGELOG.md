# Changelog

## Unreleased

### Added

- RFC-0003 `InventoryTransactionCoordinator` and serialized inventory writer.
- Versioned, checksummed Pantry/History commit envelope.
- Durable Hive transaction journal with restart recovery.
- Idempotent retry, duplicate commit, quick undo, and history cancel handling.
- Unit, crash-recovery, Hive integration, provider, and application-page tests.
- Injectable `AppClock` for deterministic expiry and transaction tests.

### Changed

- Pantry quantities and cooking history now commit as one all-or-nothing
  snapshot.
- Riverpod state is published only after durable commit verification.
- All existing Pantry write paths now use the transaction coordinator.
- Startup recovery completes before application providers are initialized.
- Project Dart sources and tests are formatted consistently.

### Quality

- `flutter analyze`: pass.
- `flutter test`: 90 tests pass.
- Line coverage: 80.77% (3,800/4,705).
- `dart format`: pass.

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
