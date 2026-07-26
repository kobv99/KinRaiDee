import 'dart:async';

import '../../../core/models/ingredient.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/utils/transaction_id_generator.dart';
import '../domain/models/cooking_history_entry.dart';
import '../domain/models/inventory_state_envelope.dart';
import '../domain/models/inventory_transaction_record.dart';
import '../domain/models/pantry_quantity_transaction.dart';
import '../domain/services/cooking_history_adjustment_planner.dart';
import '../domain/repositories/inventory_commit_repository.dart';

enum InventoryTransactionOutcome {
  committed,
  alreadyCommitted,
  alreadyUndone,
  alreadyCancelled,
  validationFailure,
  conflict,
  storageFailure,
  recoveryRequired,
  cancelledBeforeCommit,
}

class InventoryTransactionResult {
  const InventoryTransactionResult({
    required this.outcome,
    required this.code,
    required this.snapshot,
    this.transaction,
  });

  final InventoryTransactionOutcome outcome;
  final String code;
  final InventoryStateEnvelope snapshot;
  final PantryQuantityTransaction? transaction;

  bool get isSuccess =>
      outcome == InventoryTransactionOutcome.committed ||
      outcome == InventoryTransactionOutcome.alreadyCommitted ||
      outcome == InventoryTransactionOutcome.alreadyUndone ||
      outcome == InventoryTransactionOutcome.alreadyCancelled;
}

class InventoryTransactionCoordinator {
  InventoryTransactionCoordinator({
    required InventoryCommitRepository repository,
    AppClock clock = systemAppClock,
    TransactionIdGenerator? transactionIdGenerator,
  }) : // Private fields keep the coordinator contract intentionally narrow.
       // ignore: prefer_initializing_formals
       _repository = repository,
       // ignore: prefer_initializing_formals
       _clock = clock,
       _transactionIdGenerator =
           transactionIdGenerator ?? SecureTransactionIdGenerator();

  static const double quantityTolerance = 0.000001;

  final InventoryCommitRepository _repository;
  final AppClock _clock;
  final TransactionIdGenerator _transactionIdGenerator;
  Future<void> _tail = Future<void>.value();

  Future<InventoryStateEnvelope> loadSnapshot() {
    return _repository.loadConsistentSnapshot();
  }

  Future<InventoryRecoveryResult> recoverOnStartup() {
    return _serialized(_repository.recoverPendingTransactions);
  }

  Future<void> completePresentation(String transactionId) {
    return _serialized(() => _repository.complete(transactionId));
  }

  Future<InventoryTransactionResult> completeCooking(
    PantryQuantityTransaction planned,
  ) {
    return _serialized(() async {
      final before = await _repository.loadConsistentSnapshot();
      final transaction = _normalize(
        planned,
        kind: InventoryTransactionKind.completeCooking,
        revision: before.revision,
      );
      final checksum = _transactionChecksum(transaction);
      final existing = await _existingResult(transaction, checksum, before);
      if (existing != null) {
        return existing;
      }

      final validation = _validateQuantityChanges(transaction, before.pantry);
      if (validation != null) {
        return _failure(validation.$1, validation.$2, before, transaction);
      }
      if (transaction.changes.isEmpty) {
        return _failure(
          InventoryTransactionOutcome.cancelledBeforeCommit,
          'empty_transaction',
          before,
          transaction,
        );
      }

      final committedAt = _clock.now();
      final afterPantry = _applyChanges(
        before.pantry,
        transaction.changes,
        committedAt,
      );
      final entry = CookingHistoryEntry.fromTransaction(transaction);
      if (before.history.any(
        (current) =>
            current.id == entry.id ||
            current.originatingTransactionId == transaction.transactionId,
      )) {
        return _failure(
          InventoryTransactionOutcome.conflict,
          'duplicate_history_identity',
          before,
          transaction,
        );
      }
      final afterHistory = <CookingHistoryEntry>[entry, ...before.history]
        ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
      final after = _targetEnvelope(
        before,
        transaction.transactionId,
        committedAt,
        pantry: afterPantry,
        history: afterHistory,
      );
      return _commit(transaction, checksum, before, after);
    });
  }

  Future<InventoryTransactionResult> undoCooking(
    PantryQuantityTransaction original,
  ) {
    return _serialized(() async {
      final before = await _repository.loadConsistentSnapshot();
      final originalId = original.transactionId;
      if (originalId.isEmpty) {
        return _failure(
          InventoryTransactionOutcome.validationFailure,
          'missing_original_transaction_id',
          before,
          original,
        );
      }
      final history = _findHistoryForTransaction(before.history, originalId);
      if (history == null) {
        return _failure(
          InventoryTransactionOutcome.conflict,
          'history_not_found',
          before,
          original,
        );
      }
      if (history.reversedByTransactionId != null ||
          history.cancelledByTransactionId != null ||
          history.isCancelled) {
        return InventoryTransactionResult(
          outcome: InventoryTransactionOutcome.alreadyUndone,
          code: 'already_undone',
          snapshot: before,
          transaction: original,
        );
      }

      final undoId = _transactionIdGenerator.generate();
      final transaction = PantryQuantityTransaction(
        transactionId: undoId,
        schemaVersion: 1,
        expectedRevision: before.revision,
        kind: InventoryTransactionKind.undoCooking,
        reversesTransactionId: originalId,
        targetHistoryEntryId: history.id,
        recipeId: history.recipeId,
        recipeName: history.recipeName,
        servings: history.servings,
        changes: history.changes
            .map(
              (change) => PantryQuantityChange(
                ingredientId: change.ingredientId,
                ingredientName: change.ingredientName,
                unit: change.unit,
                beforeQuantity: change.afterQuantity,
                afterQuantity: change.beforeQuantity,
              ),
            )
            .toList(growable: false),
        createdAt: _clock.now(),
      );
      final validation = _validateQuantityChanges(transaction, before.pantry);
      if (validation != null) {
        return _failure(validation.$1, validation.$2, before, transaction);
      }

      final committedAt = _clock.now();
      final afterPantry = _applyChanges(
        before.pantry,
        transaction.changes,
        committedAt,
      );
      final cancelled = history.copyWith(
        changes: history.changes
            .map(
              (change) => change.copyWith(afterQuantity: change.beforeQuantity),
            )
            .toList(growable: false),
        status: CookingHistoryStatus.cancelled,
        updatedAt: committedAt,
        cancelledByTransactionId: undoId,
        reversedByTransactionId: undoId,
      );
      final afterHistory = _replaceHistory(before.history, cancelled);
      final after = _targetEnvelope(
        before,
        undoId,
        committedAt,
        pantry: afterPantry,
        history: afterHistory,
      );
      return _commit(
        transaction,
        _transactionChecksum(transaction),
        before,
        after,
      );
    });
  }

  Future<InventoryTransactionResult> applyHistoryAdjustment({
    required CookingHistoryAdjustmentPlan plan,
    required InventoryTransactionKind kind,
  }) {
    if (kind != InventoryTransactionKind.adjustCookingHistory &&
        kind != InventoryTransactionKind.cancelCookingHistory) {
      throw ArgumentError.value(kind, 'kind', 'Unsupported History operation.');
    }
    return _serialized(() async {
      final before = await _repository.loadConsistentSnapshot();
      final current = before.history
          .where((entry) => entry.id == plan.updatedEntry.id)
          .firstOrNull;
      if (current == null) {
        return _failure(
          InventoryTransactionOutcome.conflict,
          'history_not_found',
          before,
          plan.transaction,
        );
      }
      if (kind == InventoryTransactionKind.cancelCookingHistory &&
          (current.isCancelled ||
              current.cancelledByTransactionId != null ||
              current.reversedByTransactionId != null)) {
        return InventoryTransactionResult(
          outcome: InventoryTransactionOutcome.alreadyCancelled,
          code: 'already_cancelled',
          snapshot: before,
          transaction: plan.transaction,
        );
      }
      if (current.updatedAt.toUtc().isAfter(
        plan.transaction.createdAt.toUtc(),
      )) {
        // The plan was based on a History projection that may no longer be current.
        return _failure(
          InventoryTransactionOutcome.conflict,
          'history_changed_since_planning',
          before,
          plan.transaction,
        );
      }

      final transaction = _normalize(
        plan.transaction.copyWith(targetHistoryEntryId: current.id),
        kind: kind,
        revision: before.revision,
      );
      final validation = _validateQuantityChanges(transaction, before.pantry);
      if (validation != null) {
        return _failure(validation.$1, validation.$2, before, transaction);
      }

      final committedAt = _clock.now();
      final afterPantry = _applyChanges(
        before.pantry,
        transaction.changes,
        committedAt,
      );
      final updated = kind == InventoryTransactionKind.cancelCookingHistory
          ? plan.updatedEntry.copyWith(
              cancelledByTransactionId: transaction.transactionId,
              updatedAt: committedAt,
            )
          : plan.updatedEntry.copyWith(
              adjustedByTransactionId: transaction.transactionId,
              updatedAt: committedAt,
            );
      final afterHistory = _replaceHistory(before.history, updated);
      final after = _targetEnvelope(
        before,
        transaction.transactionId,
        committedAt,
        pantry: afterPantry,
        history: afterHistory,
      );
      return _commit(
        transaction,
        _transactionChecksum(transaction, history: updated),
        before,
        after,
      );
    });
  }

  Future<InventoryTransactionResult> replacePantry(
    List<Ingredient> pantry, {
    String source = 'pantryMutation',
  }) {
    return _serialized(() async {
      final before = await _repository.loadConsistentSnapshot();
      final id = _transactionIdGenerator.generate();
      final now = _clock.now();
      final transaction = PantryQuantityTransaction(
        transactionId: id,
        expectedRevision: before.revision,
        kind: InventoryTransactionKind.pantryMutation,
        recipeId: source,
        recipeName: source,
        servings: 1,
        changes: const <PantryQuantityChange>[],
        createdAt: now,
      );
      final pantryError = _validateCompletePantry(pantry);
      if (pantryError != null) {
        return _failure(
          InventoryTransactionOutcome.validationFailure,
          pantryError,
          before,
          transaction,
        );
      }
      final checksum = calculateChecksum(<String, dynamic>{
        'transaction': transaction.toJson(),
        'pantry': pantry.map((item) => item.toJson()).toList(growable: false),
      });
      final after = _targetEnvelope(
        before,
        id,
        now,
        pantry: pantry,
        history: before.history,
      );
      return _commit(transaction, checksum, before, after);
    });
  }

  Future<InventoryTransactionResult?> _existingResult(
    PantryQuantityTransaction transaction,
    String checksum,
    InventoryStateEnvelope snapshot,
  ) async {
    final records = await _repository.loadJournal();
    final record = records
        .where((item) => item.transactionId == transaction.transactionId)
        .firstOrNull;
    if (record == null) {
      return null;
    }
    if (record.commandChecksum != checksum || record.kind != transaction.kind) {
      return _failure(
        InventoryTransactionOutcome.recoveryRequired,
        'transaction_identity_conflict',
        snapshot,
        transaction,
      );
    }
    if (record.state == InventoryTransactionState.completed ||
        record.state == InventoryTransactionState.committed ||
        record.state == InventoryTransactionState.completing) {
      return InventoryTransactionResult(
        outcome: InventoryTransactionOutcome.alreadyCommitted,
        code: 'already_committed',
        snapshot: snapshot,
        transaction: transaction,
      );
    }
    final recovery = await _repository.recoverPendingTransactions();
    if (!recovery.allowsMutation) {
      return _failure(
        InventoryTransactionOutcome.recoveryRequired,
        recovery.code ?? 'recovery_required',
        recovery.snapshot,
        transaction,
      );
    }
    final refreshed = (await _repository.loadJournal())
        .where((item) => item.transactionId == transaction.transactionId)
        .firstOrNull;
    if (refreshed?.state == InventoryTransactionState.completed) {
      return InventoryTransactionResult(
        outcome: InventoryTransactionOutcome.alreadyCommitted,
        code: 'already_committed',
        snapshot: recovery.snapshot,
        transaction: transaction,
      );
    }
    return _failure(
      InventoryTransactionOutcome.storageFailure,
      refreshed?.errorCode ?? 'transaction_rolled_back',
      recovery.snapshot,
      transaction,
    );
  }

  Future<InventoryTransactionResult> _commit(
    PantryQuantityTransaction transaction,
    String commandChecksum,
    InventoryStateEnvelope before,
    InventoryStateEnvelope after,
  ) async {
    final result = await _repository.commit(
      InventoryCommit(
        transactionId: transaction.transactionId,
        kind: transaction.kind,
        commandChecksum: commandChecksum,
        createdAt: transaction.createdAt,
        before: before,
        after: after,
      ),
    );
    final snapshot = result.snapshot ?? before;
    final outcome = switch (result.outcome) {
      InventoryCommitOutcome.committed => InventoryTransactionOutcome.committed,
      InventoryCommitOutcome.alreadyCommitted =>
        InventoryTransactionOutcome.alreadyCommitted,
      InventoryCommitOutcome.conflict => InventoryTransactionOutcome.conflict,
      InventoryCommitOutcome.validationFailure =>
        InventoryTransactionOutcome.validationFailure,
      InventoryCommitOutcome.storageFailure ||
      InventoryCommitOutcome.rolledBack =>
        InventoryTransactionOutcome.storageFailure,
      InventoryCommitOutcome.recoveryRequired =>
        InventoryTransactionOutcome.recoveryRequired,
    };
    return InventoryTransactionResult(
      outcome: outcome,
      code: result.code,
      snapshot: snapshot,
      transaction: transaction,
    );
  }

  PantryQuantityTransaction _normalize(
    PantryQuantityTransaction transaction, {
    required InventoryTransactionKind kind,
    required int revision,
  }) {
    return transaction.copyWith(
      transactionId: transaction.transactionId.isEmpty
          ? _transactionIdGenerator.generate()
          : transaction.transactionId,
      expectedRevision: transaction.expectedRevision < 0
          ? revision
          : transaction.expectedRevision,
      kind: kind,
    );
  }

  (InventoryTransactionOutcome, String)? _validateQuantityChanges(
    PantryQuantityTransaction transaction,
    List<Ingredient> pantry,
  ) {
    if (transaction.transactionId.isEmpty) {
      return (
        InventoryTransactionOutcome.validationFailure,
        'missing_transaction_id',
      );
    }
    final pantryById = <String, Ingredient>{
      for (final ingredient in pantry) ingredient.id: ingredient,
    };
    final changedIds = <String>{};
    for (final change in transaction.changes) {
      if (change.ingredientId.isEmpty || !changedIds.add(change.ingredientId)) {
        return (
          InventoryTransactionOutcome.validationFailure,
          'duplicate_or_missing_lot_id',
        );
      }
      final current = pantryById[change.ingredientId];
      if (current == null) {
        return (InventoryTransactionOutcome.conflict, 'pantry_lot_missing');
      }
      if (current.unit.trim() != change.unit.trim()) {
        return (InventoryTransactionOutcome.conflict, 'pantry_unit_mismatch');
      }
      if (!_nearlyEqual(current.quantity, change.beforeQuantity)) {
        return (
          InventoryTransactionOutcome.conflict,
          'pantry_quantity_conflict',
        );
      }
      if (!change.beforeQuantity.isFinite ||
          !change.afterQuantity.isFinite ||
          change.beforeQuantity < 0 ||
          change.afterQuantity < 0) {
        return (
          InventoryTransactionOutcome.validationFailure,
          'invalid_quantity',
        );
      }
    }
    return null;
  }

  String? _validateCompletePantry(List<Ingredient> pantry) {
    final ids = <String>{};
    for (final ingredient in pantry) {
      if (ingredient.id.isEmpty || !ids.add(ingredient.id)) {
        return 'duplicate_or_missing_lot_id';
      }
      if (!ingredient.quantity.isFinite || ingredient.quantity < 0) {
        return 'invalid_quantity';
      }
    }
    return null;
  }

  List<Ingredient> _applyChanges(
    List<Ingredient> pantry,
    List<PantryQuantityChange> changes,
    DateTime updatedAt,
  ) {
    final changesById = <String, PantryQuantityChange>{
      for (final change in changes) change.ingredientId: change,
    };
    return pantry
        .map((ingredient) {
          final change = changesById[ingredient.id];
          return change == null
              ? ingredient
              : ingredient.copyWith(
                  quantity: change.afterQuantity,
                  updatedAt: updatedAt,
                );
        })
        .toList(growable: false);
  }

  InventoryStateEnvelope _targetEnvelope(
    InventoryStateEnvelope before,
    String transactionId,
    DateTime updatedAt, {
    required List<Ingredient> pantry,
    required List<CookingHistoryEntry> history,
  }) {
    return InventoryStateEnvelope(
      envelopeVersion: before.envelopeVersion,
      minimumReaderVersion: before.minimumReaderVersion,
      capabilities: before.capabilities,
      revision: before.revision + 1,
      lastAppliedTransactionId: transactionId,
      updatedAt: updatedAt,
      pantry: pantry,
      history: history,
    ).withComputedChecksum();
  }

  String _transactionChecksum(
    PantryQuantityTransaction transaction, {
    CookingHistoryEntry? history,
  }) {
    return calculateChecksum(<String, dynamic>{
      'transaction': transaction.toJson(),
      if (history != null) 'history': history.toJson(),
    });
  }

  InventoryTransactionResult _failure(
    InventoryTransactionOutcome outcome,
    String code,
    InventoryStateEnvelope snapshot,
    PantryQuantityTransaction transaction,
  ) {
    return InventoryTransactionResult(
      outcome: outcome,
      code: code,
      snapshot: snapshot,
      transaction: transaction,
    );
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

CookingHistoryEntry? _findHistoryForTransaction(
  List<CookingHistoryEntry> history,
  String transactionId,
) {
  for (final entry in history) {
    if (entry.originatingTransactionId == transactionId ||
        entry.id == transactionId) {
      return entry;
    }
  }
  return null;
}

List<CookingHistoryEntry> _replaceHistory(
  List<CookingHistoryEntry> history,
  CookingHistoryEntry replacement,
) {
  final result = history
      .map((entry) => entry.id == replacement.id ? replacement : entry)
      .toList(growable: false);
  result.sort((first, second) => second.createdAt.compareTo(first.createdAt));
  return result;
}

bool _nearlyEqual(double first, double second) {
  return (first - second).abs() <=
      InventoryTransactionCoordinator.quantityTolerance;
}
