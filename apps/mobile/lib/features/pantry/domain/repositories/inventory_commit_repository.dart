import '../models/inventory_state_envelope.dart';
import '../models/inventory_transaction_record.dart';
import '../models/pantry_quantity_transaction.dart';

enum InventoryCommitOutcome {
  committed,
  alreadyCommitted,
  rolledBack,
  conflict,
  validationFailure,
  storageFailure,
  recoveryRequired,
}

class InventoryCommit {
  const InventoryCommit({
    required this.transactionId,
    required this.kind,
    required this.commandChecksum,
    required this.createdAt,
    required this.before,
    required this.after,
  });

  final String transactionId;
  final InventoryTransactionKind kind;
  final String commandChecksum;
  final DateTime createdAt;
  final InventoryStateEnvelope before;
  final InventoryStateEnvelope after;
}

class InventoryCommitResult {
  const InventoryCommitResult({
    required this.outcome,
    required this.code,
    this.snapshot,
    this.transactionId,
  });

  final InventoryCommitOutcome outcome;
  final String code;
  final InventoryStateEnvelope? snapshot;
  final String? transactionId;

  bool get isDurablyCommitted =>
      outcome == InventoryCommitOutcome.committed ||
      outcome == InventoryCommitOutcome.alreadyCommitted;
}

enum InventoryRecoveryOutcome { recovered, noWork, recoveryRequired }

class InventoryRecoveryResult {
  const InventoryRecoveryResult({
    required this.outcome,
    required this.snapshot,
    this.blockingTransactionId,
    this.code,
  });

  final InventoryRecoveryOutcome outcome;
  final InventoryStateEnvelope snapshot;
  final String? blockingTransactionId;
  final String? code;

  bool get allowsMutation =>
      outcome != InventoryRecoveryOutcome.recoveryRequired;
}

abstract interface class InventoryCommitRepository {
  Future<InventoryStateEnvelope> loadConsistentSnapshot();

  Future<InventoryCommitResult> commit(InventoryCommit commit);

  Future<void> complete(String transactionId);

  Future<InventoryRecoveryResult> recoverPendingTransactions();

  Future<List<InventoryTransactionRecord>> loadJournal();
}
