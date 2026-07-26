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
