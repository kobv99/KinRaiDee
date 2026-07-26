import '../../../../core/models/ingredient.dart';
import '../../domain/models/cooking_history_entry.dart';
import '../../domain/models/inventory_transaction_record.dart';

abstract interface class InventoryStore {
  Future<Map<String, dynamic>?> readEnvelope();

  Future<void> writeEnvelope(Map<String, dynamic> envelope);

  Future<Map<String, dynamic>?> readJournal();

  Future<void> writeJournal(Map<String, dynamic> journal);

  Future<void> writeLegacyBackup(Map<String, dynamic> backup);

  List<Ingredient> readLegacyPantry();

  List<CookingHistoryEntry> readLegacyHistory();
}

enum InventoryCommitStage {
  created,
  validating,
  prepared,
  committing,
  envelopeWritten,
  committed,
  completing,
  completed,
  failed,
  rollingBack,
  rolledBack,
  recoveryRequired,
}

abstract interface class InventoryCommitObserver {
  Future<void> reached(
    InventoryCommitStage stage,
    InventoryTransactionRecord record,
  );
}

class NoopInventoryCommitObserver implements InventoryCommitObserver {
  const NoopInventoryCommitObserver();

  @override
  Future<void> reached(
    InventoryCommitStage stage,
    InventoryTransactionRecord record,
  ) async {}
}

class InventoryProcessInterruption implements Exception {
  const InventoryProcessInterruption(this.stage);

  final InventoryCommitStage stage;

  @override
  String toString() => 'Inventory process interrupted at ${stage.name}.';
}
