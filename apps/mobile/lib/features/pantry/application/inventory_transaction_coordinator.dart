import 'dart:async';

import '../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../../../core/domain/units/unit_contract.dart';
import '../../../core/models/ingredient.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/utils/transaction_id_generator.dart';
import '../../shopping/domain/entities/shopping_category.dart';
import '../../shopping/domain/entities/shopping_item.dart';
import '../../shopping/domain/entities/shopping_item_status.dart';
import '../../shopping/domain/entities/shopping_list.dart';
import '../../shopping/domain/entities/shopping_purchase.dart';
import '../../shopping/domain/entities/shopping_source.dart';
import '../../shopping/domain/models/shopping_mutation.dart';
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
    CanonicalIngredientRegistry? canonicalIngredientRegistry,
    UnitConversionEngine? unitConversionEngine,
  }) : // Private fields keep the coordinator contract intentionally narrow.
       // ignore: prefer_initializing_formals
       _repository = repository,
       // ignore: prefer_initializing_formals
       _clock = clock,
       _transactionIdGenerator =
           transactionIdGenerator ?? SecureTransactionIdGenerator(),
       // ignore: prefer_initializing_formals
       _canonicalIngredientRegistry = canonicalIngredientRegistry,
       // ignore: prefer_initializing_formals
       _unitConversionEngine = unitConversionEngine;

  static const double quantityTolerance = 0.000001;

  final InventoryCommitRepository _repository;
  final AppClock _clock;
  final TransactionIdGenerator _transactionIdGenerator;
  final CanonicalIngredientRegistry? _canonicalIngredientRegistry;
  final UnitConversionEngine? _unitConversionEngine;
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
                canonicalIngredientId: change.canonicalIngredientId,
                canonicalUnitId: change.canonicalUnitId,
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

  Future<InventoryTransactionResult> deleteCookingHistory(String entryId) {
    return _serialized(() async {
      final before = await _repository.loadConsistentSnapshot();
      final normalizedEntryId = entryId.trim();
      if (normalizedEntryId.isEmpty) {
        final invalid = PantryQuantityTransaction(
          transactionId: _transactionIdGenerator.generate(),
          expectedRevision: before.revision,
          kind: InventoryTransactionKind.deleteCookingHistory,
          recipeId: 'history-retention',
          recipeName: 'Cooking history retention',
          servings: 1,
          changes: const <PantryQuantityChange>[],
          createdAt: _clock.now(),
        );
        return _failure(
          InventoryTransactionOutcome.validationFailure,
          'missing_history_entry_id',
          before,
          invalid,
        );
      }
      if (!before.history.any((entry) => entry.id == normalizedEntryId)) {
        return InventoryTransactionResult(
          outcome: InventoryTransactionOutcome.alreadyCommitted,
          code: 'history_entry_already_deleted',
          snapshot: before,
        );
      }

      final committedAt = _clock.now();
      final transaction = PantryQuantityTransaction(
        transactionId: _transactionIdGenerator.generate(),
        expectedRevision: before.revision,
        kind: InventoryTransactionKind.deleteCookingHistory,
        targetHistoryEntryId: normalizedEntryId,
        recipeId: 'history-retention',
        recipeName: 'Cooking history retention',
        servings: 1,
        changes: const <PantryQuantityChange>[],
        createdAt: committedAt,
      );
      final afterHistory = before.history
          .where((entry) => entry.id != normalizedEntryId)
          .toList(growable: false);
      final after = _targetEnvelope(
        before,
        transaction.transactionId,
        committedAt,
        pantry: before.pantry,
        history: afterHistory,
      );
      final checksum = calculateChecksum(<String, dynamic>{
        'transaction': transaction.toJson(),
        'retainedHistoryIds': afterHistory
            .map((entry) => entry.id)
            .toList(growable: false),
      });
      return _commit(transaction, checksum, before, after);
    });
  }

  Future<InventoryTransactionResult> clearCookingHistory() {
    return _serialized(() async {
      final before = await _repository.loadConsistentSnapshot();
      if (before.history.isEmpty) {
        return InventoryTransactionResult(
          outcome: InventoryTransactionOutcome.alreadyCommitted,
          code: 'history_already_empty',
          snapshot: before,
        );
      }

      final committedAt = _clock.now();
      final transaction = PantryQuantityTransaction(
        transactionId: _transactionIdGenerator.generate(),
        expectedRevision: before.revision,
        kind: InventoryTransactionKind.clearCookingHistory,
        targetHistoryEntryId: '*',
        recipeId: 'history-retention',
        recipeName: 'Cooking history retention',
        servings: 1,
        changes: const <PantryQuantityChange>[],
        createdAt: committedAt,
      );
      final checksum = calculateChecksum(<String, dynamic>{
        'transaction': transaction.toJson(),
        'deletedHistoryIds': before.history
            .map((entry) => entry.id)
            .toList(growable: false),
      });
      final after = _targetEnvelope(
        before,
        transaction.transactionId,
        committedAt,
        pantry: before.pantry,
        history: const <CookingHistoryEntry>[],
      );
      return _commit(transaction, checksum, before, after);
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

  /// Applies Shopping state through the same durable journal and envelope used
  /// by Pantry and Cooking History.
  Future<InventoryTransactionResult> mutateShopping(
    ShoppingMutation requested,
  ) {
    return _serialized(() async {
      final before = await _repository.loadConsistentSnapshot();
      final command = requested.copyWith(
        transactionId: requested.transactionId.isEmpty
            ? _transactionIdGenerator.generate()
            : requested.transactionId,
        expectedRevision: requested.expectedRevision < 0
            ? before.revision
            : requested.expectedRevision,
      );
      var transaction = PantryQuantityTransaction(
        transactionId: command.transactionId,
        expectedRevision: command.expectedRevision,
        kind: _shoppingTransactionKind(command.type),
        reversesTransactionId: _shoppingPurchaseTransactionId(command, before),
        recipeId: 'shopping:${command.type.name}:${command.listId}',
        recipeName: 'Shopping ${command.type.name}',
        servings: 1,
        changes: const <PantryQuantityChange>[],
        createdAt: command.createdAt,
      );
      final checksum = calculateChecksum(<String, dynamic>{
        'shoppingMutation': command.toJson(),
      });
      final existing = await _existingResult(transaction, checksum, before);
      if (existing != null) {
        return existing;
      }
      final semanticNoOp = _shoppingSemanticNoOp(command, before, transaction);
      if (semanticNoOp != null) {
        return semanticNoOp;
      }
      if (command.expectedRevision != before.revision) {
        return _failure(
          InventoryTransactionOutcome.conflict,
          'stale_inventory_revision',
          before,
          transaction,
        );
      }

      final validation = _validateShoppingMutation(command, before);
      if (validation != null) {
        return _failure(validation.$1, validation.$2, before, transaction);
      }

      final committedAt = _clock.now().toUtc();
      final lists = List<ShoppingList>.of(before.shoppingLists);
      final index = lists.indexWhere((list) => list.id == command.listId);
      var pantry = List<Ingredient>.of(before.pantry);
      ShoppingList? updatedList;
      switch (command.type) {
        case ShoppingMutationType.upsertList:
          final requestedList = _upgradeShoppingList(command.list!);
          final persisted = requestedList.copyWith(
            revision: index < 0 ? 0 : lists[index].revision + 1,
            updatedAt: committedAt,
          );
          if (index < 0) {
            lists.add(persisted);
          } else {
            lists[index] = persisted;
          }
          updatedList = persisted;
        case ShoppingMutationType.removeList:
          lists.removeAt(index);
        case ShoppingMutationType.addItem:
          final current = lists[index];
          final item = _upgradeShoppingItem(
            command.item!,
          ).copyWith(updatedAt: committedAt);
          updatedList = _withShoppingItems(current, <ShoppingItem>[
            ...current.items,
            item,
          ], committedAt);
          lists[index] = updatedList;
        case ShoppingMutationType.removeItem:
          final current = lists[index];
          updatedList = _withShoppingItems(
            current,
            current.items
                .where((item) => item.id != command.itemId)
                .toList(growable: false),
            committedAt,
          );
          lists[index] = updatedList;
        case ShoppingMutationType.updateQuantity:
          final current = lists[index];
          final currentItem = _findShoppingItem(current, command.itemId!)!;
          final targetUnitId = _unitConversionEngine!.resolveUnitId(
            command.unitId ?? currentItem.unitId,
          )!;
          final rounded = _roundShoppingQuantity(
            command.quantity!,
            targetUnitId,
          );
          updatedList = _withShoppingItems(
            current,
            current.items
                .map(
                  (item) => item.id == currentItem.id
                      ? _upgradeShoppingItem(item).copyWith(
                          quantity: rounded,
                          unitId: targetUnitId,
                          updatedAt: committedAt,
                        )
                      : _upgradeShoppingItem(item),
                )
                .toList(growable: false),
            committedAt,
          );
          lists[index] = updatedList;
        case ShoppingMutationType.markPurchased:
          final current = lists[index];
          final currentItem = _findShoppingItem(current, command.itemId!)!;
          final purchase = _applyShoppingPurchase(
            pantry,
            currentItem,
            transaction.transactionId,
            committedAt,
          );
          pantry = purchase.pantry;
          transaction = transaction.copyWith(
            changes: <PantryQuantityChange>[purchase.change],
          );
          updatedList = _withShoppingItems(
            current,
            current.items
                .map(
                  (item) => item.id == currentItem.id
                      ? _upgradeShoppingItem(item).copyWith(
                          status: ShoppingItemStatus.purchased,
                          purchase: purchase.receipt,
                          updatedAt: committedAt,
                        )
                      : _upgradeShoppingItem(item),
                )
                .toList(growable: false),
            committedAt,
          );
          lists[index] = updatedList;
        case ShoppingMutationType.markUnpurchased:
          final current = lists[index];
          final currentItem = _findShoppingItem(current, command.itemId!)!;
          final undo = _undoShoppingPurchase(pantry, currentItem, committedAt);
          pantry = undo.pantry;
          transaction = transaction.copyWith(
            changes: <PantryQuantityChange>[undo.change],
          );
          updatedList = _withShoppingItems(
            current,
            current.items
                .map(
                  (item) => item.id == currentItem.id
                      ? _upgradeShoppingItem(item).copyWith(
                          status: ShoppingItemStatus.active,
                          clearPurchase: true,
                          updatedAt: committedAt,
                        )
                      : _upgradeShoppingItem(item),
                )
                .toList(growable: false),
            committedAt,
          );
          lists[index] = updatedList;
        case ShoppingMutationType.archiveCompleted:
          final current = lists[index];
          updatedList = _withShoppingItems(
            current,
            current.items
                .map(
                  (item) => item.status == ShoppingItemStatus.purchased
                      ? _upgradeShoppingItem(item).copyWith(
                          status: ShoppingItemStatus.archived,
                          updatedAt: committedAt,
                        )
                      : _upgradeShoppingItem(item),
                )
                .toList(growable: false),
            committedAt,
          );
          lists[index] = updatedList;
        case ShoppingMutationType.restoreArchived:
          final current = lists[index];
          updatedList = _withShoppingItems(
            current,
            current.items
                .map(
                  (item) => item.status == ShoppingItemStatus.archived
                      ? _upgradeShoppingItem(item).copyWith(
                          status: ShoppingItemStatus.purchased,
                          updatedAt: committedAt,
                        )
                      : _upgradeShoppingItem(item),
                )
                .toList(growable: false),
            committedAt,
          );
          lists[index] = updatedList;
        case ShoppingMutationType.clearCompleted:
          final current = lists[index];
          updatedList = _withShoppingItems(
            current,
            current.items
                .where((item) => item.status == ShoppingItemStatus.active)
                .map(_upgradeShoppingItem)
                .toList(growable: false),
            committedAt,
          );
          lists[index] = updatedList;
      }
      final listError = updatedList == null
          ? null
          : _validateShoppingList(
              updatedList,
              registry: _canonicalIngredientRegistry!,
              unitEngine: _unitConversionEngine!,
            );
      final pantryError = _validateCompletePantry(pantry);
      if (listError != null || pantryError != null) {
        return _failure(
          InventoryTransactionOutcome.validationFailure,
          listError ?? pantryError!,
          before,
          transaction,
        );
      }
      lists.sort(
        (first, second) => second.updatedAt.compareTo(first.updatedAt),
      );
      final after = _targetEnvelope(
        before,
        transaction.transactionId,
        committedAt,
        pantry: pantry,
        history: before.history,
        shoppingLists: lists,
      );
      return _commit(transaction, checksum, before, after);
    });
  }

  /// Persists the canonical identity projection through the same durable
  /// journal as cooking transactions, before Riverpod publishes the state.
  Future<InventoryTransactionResult> migrateCanonicalIngredients({
    required List<Ingredient> pantry,
    required List<CookingHistoryEntry> history,
    required int targetSchemaVersion,
  }) {
    return _serialized(() async {
      final before = await _repository.loadConsistentSnapshot();
      final unchanged =
          calculateChecksum(<String, dynamic>{
            'pantry': before.pantry.map((item) => item.toJson()).toList(),
            'history': before.history.map((item) => item.toJson()).toList(),
          }) ==
          calculateChecksum(<String, dynamic>{
            'pantry': pantry.map((item) => item.toJson()).toList(),
            'history': history.map((item) => item.toJson()).toList(),
          });
      final now = _clock.now();
      final transaction = PantryQuantityTransaction(
        transactionId: _transactionIdGenerator.generate(),
        schemaVersion: targetSchemaVersion,
        expectedRevision: before.revision,
        kind: InventoryTransactionKind.canonicalIngredientMigration,
        recipeId: 'canonical_ingredient_migration_v$targetSchemaVersion',
        recipeName: 'Canonical ingredient migration',
        servings: 1,
        changes: const <PantryQuantityChange>[],
        createdAt: now,
      );
      if (unchanged) {
        return InventoryTransactionResult(
          outcome: InventoryTransactionOutcome.alreadyCommitted,
          code: 'canonical_migration_not_required',
          snapshot: before,
          transaction: transaction,
        );
      }

      final validation = _validateCanonicalMigration(pantry, history);
      if (validation != null) {
        return _failure(
          InventoryTransactionOutcome.validationFailure,
          validation,
          before,
          transaction,
        );
      }
      final checksum = calculateChecksum(<String, dynamic>{
        'transaction': transaction.toJson(),
        'targetSchemaVersion': targetSchemaVersion,
        'pantry': pantry.map((item) => item.toJson()).toList(growable: false),
        'history': history.map((item) => item.toJson()).toList(growable: false),
      });
      final after = _targetEnvelope(
        before,
        transaction.transactionId,
        now,
        pantry: pantry,
        history: history,
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

  String? _validateCanonicalMigration(
    List<Ingredient> pantry,
    List<CookingHistoryEntry> history,
  ) {
    final pantryError = _validateCompletePantry(pantry);
    if (pantryError != null) {
      return pantryError;
    }
    if (pantry.any(
      (item) =>
          item.schemaVersion < 2 ||
          item.canonicalIngredientId.isEmpty ||
          item.canonicalUnitId.isEmpty ||
          item.canonicalMappingStatus == CanonicalMappingStatus.legacy,
    )) {
      return 'incomplete_canonical_pantry_mapping';
    }
    if (history.any(
      (entry) =>
          entry.schemaVersion < 2 ||
          entry.changes.any(
            (change) =>
                change.canonicalIngredientId.isEmpty ||
                change.canonicalUnitId.isEmpty ||
                change.canonicalMappingStatus == CanonicalMappingStatus.legacy,
          ),
    )) {
      return 'incomplete_canonical_history_mapping';
    }
    return null;
  }

  (InventoryTransactionOutcome, String)? _validateShoppingMutation(
    ShoppingMutation command,
    InventoryStateEnvelope before,
  ) {
    final registry = _canonicalIngredientRegistry;
    final unitEngine = _unitConversionEngine;
    if (registry == null || unitEngine == null) {
      return (
        InventoryTransactionOutcome.validationFailure,
        'shopping_contract_unavailable',
      );
    }
    if (command.listId.trim().isEmpty) {
      return (
        InventoryTransactionOutcome.validationFailure,
        'missing_shopping_list_id',
      );
    }
    final listIds = <String>{};
    for (final list in before.shoppingLists) {
      if (list.id.isEmpty || !listIds.add(list.id)) {
        return (
          InventoryTransactionOutcome.recoveryRequired,
          'invalid_durable_shopping_state',
        );
      }
    }
    final existing = before.shoppingLists
        .where((list) => list.id == command.listId)
        .firstOrNull;
    switch (command.type) {
      case ShoppingMutationType.removeList:
        if (existing == null) {
          return (
            InventoryTransactionOutcome.conflict,
            'shopping_list_not_found',
          );
        }
        if (command.expectedListRevision != existing.revision) {
          return (
            InventoryTransactionOutcome.conflict,
            'stale_shopping_list_revision',
          );
        }
        if (existing.items.any((item) => item.purchase != null)) {
          return (
            InventoryTransactionOutcome.validationFailure,
            'shopping_list_has_purchase_history',
          );
        }
      case ShoppingMutationType.upsertList:
        final list = command.list;
        if (list == null || list.id != command.listId) {
          return (
            InventoryTransactionOutcome.validationFailure,
            'shopping_list_identity_mismatch',
          );
        }
        if (command.expectedListRevision != list.revision) {
          return (
            InventoryTransactionOutcome.validationFailure,
            'shopping_list_revision_mismatch',
          );
        }
        if (existing == null && list.revision != 0) {
          return (
            InventoryTransactionOutcome.conflict,
            'invalid_new_shopping_list_revision',
          );
        }
        if (existing == null &&
            list.items.any(
              (item) => item.status != ShoppingItemStatus.active,
            )) {
          return (
            InventoryTransactionOutcome.validationFailure,
            'new_shopping_list_has_completed_items',
          );
        }
        if (existing != null &&
            (list.revision != existing.revision ||
                list.createdAt.toUtc() != existing.createdAt.toUtc())) {
          return (
            InventoryTransactionOutcome.conflict,
            'stale_shopping_list_revision',
          );
        }
        if (existing != null &&
            !_completedShoppingItemsArePreserved(existing, list)) {
          return (
            InventoryTransactionOutcome.conflict,
            'completed_shopping_item_is_immutable',
          );
        }
        final listError = _validateShoppingList(
          _upgradeShoppingList(list),
          registry: registry,
          unitEngine: unitEngine,
        );
        if (listError != null) {
          return (InventoryTransactionOutcome.validationFailure, listError);
        }
      case ShoppingMutationType.addItem:
        final listError = _validateExistingShoppingListRevision(
          command,
          existing,
        );
        if (listError != null) {
          return listError;
        }
        final item = command.item;
        if (item == null ||
            item.id != command.itemId ||
            item.status != ShoppingItemStatus.active ||
            item.purchase != null) {
          return (
            InventoryTransactionOutcome.validationFailure,
            'invalid_new_shopping_item',
          );
        }
        if (existing!.items.any((current) => current.id == item.id)) {
          return (
            InventoryTransactionOutcome.conflict,
            'duplicate_shopping_item_id',
          );
        }
      case ShoppingMutationType.removeItem:
        final listError = _validateExistingShoppingListRevision(
          command,
          existing,
        );
        if (listError != null) {
          return listError;
        }
        final item = _findShoppingItem(existing!, command.itemId ?? '');
        if (item == null) {
          return (
            InventoryTransactionOutcome.conflict,
            'shopping_item_not_found',
          );
        }
        if (item.status != ShoppingItemStatus.active) {
          return (
            InventoryTransactionOutcome.validationFailure,
            'completed_item_requires_clear',
          );
        }
      case ShoppingMutationType.updateQuantity:
        final listError = _validateExistingShoppingListRevision(
          command,
          existing,
        );
        if (listError != null) {
          return listError;
        }
        final item = _findShoppingItem(existing!, command.itemId ?? '');
        if (item == null) {
          return (
            InventoryTransactionOutcome.conflict,
            'shopping_item_not_found',
          );
        }
        if (item.status != ShoppingItemStatus.active) {
          return (
            InventoryTransactionOutcome.validationFailure,
            'completed_shopping_item_is_immutable',
          );
        }
        final quantity = command.quantity;
        final targetUnitId = unitEngine.resolveUnitId(
          command.unitId ?? item.unitId,
        );
        if (quantity == null ||
            !quantity.isFinite ||
            quantity <= 0 ||
            targetUnitId == null ||
            _roundShoppingQuantity(quantity, targetUnitId) <= 0) {
          return (
            InventoryTransactionOutcome.validationFailure,
            'invalid_shopping_quantity',
          );
        }
        final canonical = registry.byId(item.canonicalIngredientId)!;
        if (!unitEngine
            .tryConvert(
              quantity,
              fromUnit: targetUnitId,
              toUnit: canonical.defaultPurchaseUnitId,
            )
            .isSuccess) {
          return (
            InventoryTransactionOutcome.validationFailure,
            'invalid_shopping_unit_conversion',
          );
        }
      case ShoppingMutationType.markPurchased:
        final listError = _validateExistingShoppingListRevision(
          command,
          existing,
        );
        if (listError != null) {
          return listError;
        }
        final item = _findShoppingItem(existing!, command.itemId ?? '');
        if (item == null) {
          return (
            InventoryTransactionOutcome.conflict,
            'shopping_item_not_found',
          );
        }
        if (item.status != ShoppingItemStatus.active || item.purchase != null) {
          return (
            InventoryTransactionOutcome.validationFailure,
            'invalid_purchase_state',
          );
        }
        final purchaseError = _validateShoppingPurchaseTarget(
          item,
          before.pantry,
          registry: registry,
          unitEngine: unitEngine,
        );
        if (purchaseError != null) {
          return purchaseError;
        }
      case ShoppingMutationType.markUnpurchased:
        final listError = _validateExistingShoppingListRevision(
          command,
          existing,
        );
        if (listError != null) {
          return listError;
        }
        final item = _findShoppingItem(existing!, command.itemId ?? '');
        if (item == null) {
          return (
            InventoryTransactionOutcome.conflict,
            'shopping_item_not_found',
          );
        }
        if (item.status == ShoppingItemStatus.active || item.purchase == null) {
          return (
            InventoryTransactionOutcome.validationFailure,
            'invalid_purchase_undo_state',
          );
        }
        final undoError = _validateShoppingUndoTarget(item, before.pantry);
        if (undoError != null) {
          return undoError;
        }
      case ShoppingMutationType.archiveCompleted ||
          ShoppingMutationType.restoreArchived ||
          ShoppingMutationType.clearCompleted:
        final listError = _validateExistingShoppingListRevision(
          command,
          existing,
        );
        if (listError != null) {
          return listError;
        }
    }
    return null;
  }

  (InventoryTransactionOutcome, String)? _validateExistingShoppingListRevision(
    ShoppingMutation command,
    ShoppingList? existing,
  ) {
    if (existing == null) {
      return (InventoryTransactionOutcome.conflict, 'shopping_list_not_found');
    }
    if (command.expectedListRevision != existing.revision) {
      return (
        InventoryTransactionOutcome.conflict,
        'stale_shopping_list_revision',
      );
    }
    return null;
  }

  (InventoryTransactionOutcome, String)? _validateShoppingPurchaseTarget(
    ShoppingItem item,
    List<Ingredient> pantry, {
    required CanonicalIngredientRegistry registry,
    required UnitConversionEngine unitEngine,
  }) {
    final canonicalId = registry.canonicalIdFor(item.canonicalIngredientId);
    for (final lot in pantry) {
      if (registry.canonicalIdFor(lot.canonicalIngredientId) != canonicalId) {
        continue;
      }
      final lotUnitId = unitEngine.resolveUnitId(
        lot.canonicalUnitId.isEmpty ? lot.unit : lot.canonicalUnitId,
      );
      if (lotUnitId == null ||
          !unitEngine
              .tryConvert(
                item.quantity,
                fromUnit: item.unitId,
                toUnit: lotUnitId,
              )
              .isSuccess) {
        return (
          InventoryTransactionOutcome.validationFailure,
          'invalid_shopping_unit_conversion',
        );
      }
    }
    return null;
  }

  (InventoryTransactionOutcome, String)? _validateShoppingUndoTarget(
    ShoppingItem item,
    List<Ingredient> pantry,
  ) {
    final purchase = item.purchase!;
    final lot = pantry
        .where((candidate) => candidate.id == purchase.pantryLotId)
        .firstOrNull;
    if (lot == null) {
      return (
        InventoryTransactionOutcome.conflict,
        'purchase_pantry_lot_missing',
      );
    }
    if (lot.canonicalIngredientId != item.canonicalIngredientId ||
        lot.canonicalUnitId != purchase.pantryUnitId ||
        !_nearlyEqual(lot.quantity, purchase.afterQuantity)) {
      return (
        InventoryTransactionOutcome.conflict,
        'purchase_pantry_state_changed',
      );
    }
    return null;
  }

  String? _validateShoppingList(
    ShoppingList list, {
    required CanonicalIngredientRegistry registry,
    required UnitConversionEngine unitEngine,
  }) {
    if (list.metadataVersion != 1 ||
        list.id.trim().isEmpty ||
        list.name.trim().isEmpty ||
        list.revision < 0 ||
        list.updatedAt.toUtc().isBefore(list.createdAt.toUtc())) {
      return 'invalid_shopping_list';
    }
    final itemIds = <String>{};
    final activeIdentities = <String>{};
    for (final item in list.items) {
      final canonicalId = registry.canonicalIdFor(item.canonicalIngredientId);
      final unitId = unitEngine.resolveUnitId(item.unitId);
      if (item.metadataVersion != currentShoppingItemVersion ||
          item.id.trim().isEmpty ||
          !itemIds.add(item.id) ||
          item.displayName.trim().isEmpty ||
          !item.quantity.isFinite ||
          item.quantity <= 0 ||
          item.updatedAt.toUtc().isBefore(item.createdAt.toUtc())) {
        return 'invalid_shopping_item';
      }
      if (canonicalId == null || canonicalId != item.canonicalIngredientId) {
        return 'unknown_canonical_shopping_ingredient';
      }
      if (unitId == null || unitId != item.unitId) {
        return 'unknown_canonical_shopping_unit';
      }
      final canonical = registry.byId(canonicalId)!;
      if (!unitEngine
          .tryConvert(
            item.quantity,
            fromUnit: unitId,
            toUnit: canonical.defaultPurchaseUnitId,
          )
          .isSuccess) {
        return 'invalid_shopping_unit_conversion';
      }
      if (item.category !=
          ShoppingCategory.fromCanonicalCategory(canonical.category)) {
        return 'shopping_category_mismatch';
      }
      if (item.source != ShoppingSource.manual &&
          item.sourceReferenceIds.isEmpty) {
        return 'missing_shopping_source_reference';
      }
      if (item.status == ShoppingItemStatus.active) {
        if (item.purchase != null) {
          return 'active_shopping_item_has_purchase';
        }
        if (!activeIdentities.add(canonicalId)) {
          return 'duplicate_active_shopping_ingredient';
        }
      } else {
        final purchase = item.purchase;
        if (purchase == null ||
            purchase.metadataVersion != currentShoppingPurchaseVersion ||
            purchase.transactionId.trim().isEmpty ||
            purchase.pantryLotId.trim().isEmpty ||
            purchase.pantryUnitId.trim().isEmpty ||
            !purchase.beforeQuantity.isFinite ||
            !purchase.afterQuantity.isFinite ||
            purchase.beforeQuantity < 0 ||
            purchase.afterQuantity <= purchase.beforeQuantity ||
            unitEngine.resolveUnitId(purchase.pantryUnitId) !=
                purchase.pantryUnitId) {
          return 'invalid_shopping_purchase';
        }
      }
    }
    return null;
  }

  InventoryTransactionKind _shoppingTransactionKind(ShoppingMutationType type) {
    return switch (type) {
      ShoppingMutationType.markPurchased =>
        InventoryTransactionKind.shoppingPurchase,
      ShoppingMutationType.markUnpurchased =>
        InventoryTransactionKind.undoShoppingPurchase,
      _ => InventoryTransactionKind.shoppingMutation,
    };
  }

  String? _shoppingPurchaseTransactionId(
    ShoppingMutation command,
    InventoryStateEnvelope snapshot,
  ) {
    if (command.type != ShoppingMutationType.markUnpurchased) {
      return null;
    }
    final list = snapshot.shoppingLists
        .where((candidate) => candidate.id == command.listId)
        .firstOrNull;
    return list == null
        ? null
        : _findShoppingItem(
            list,
            command.itemId ?? '',
          )?.purchase?.transactionId;
  }

  InventoryTransactionResult? _shoppingSemanticNoOp(
    ShoppingMutation command,
    InventoryStateEnvelope snapshot,
    PantryQuantityTransaction transaction,
  ) {
    final list = snapshot.shoppingLists
        .where((candidate) => candidate.id == command.listId)
        .firstOrNull;
    if (list == null) {
      return null;
    }
    final item = _findShoppingItem(list, command.itemId ?? '');
    final code = switch (command.type) {
      ShoppingMutationType.markPurchased
          when item != null && item.status != ShoppingItemStatus.active =>
        'already_purchased',
      ShoppingMutationType.markUnpurchased
          when item != null && item.status == ShoppingItemStatus.active =>
        'already_unpurchased',
      ShoppingMutationType.archiveCompleted
          when !list.items.any(
            (current) => current.status == ShoppingItemStatus.purchased,
          ) =>
        'already_archived',
      ShoppingMutationType.restoreArchived
          when !list.items.any(
            (current) => current.status == ShoppingItemStatus.archived,
          ) =>
        'already_restored',
      ShoppingMutationType.clearCompleted
          when list.items.every(
            (current) => current.status == ShoppingItemStatus.active,
          ) =>
        'completed_items_already_clear',
      _ => null,
    };
    if (code == null) {
      return null;
    }
    return InventoryTransactionResult(
      outcome: InventoryTransactionOutcome.alreadyCommitted,
      code: code,
      snapshot: snapshot,
      transaction: transaction,
    );
  }

  ShoppingList _upgradeShoppingList(ShoppingList list) {
    return list.copyWith(
      items: list.items.map(_upgradeShoppingItem).toList(growable: false),
    );
  }

  ShoppingItem _upgradeShoppingItem(ShoppingItem item) {
    return item.copyWith(
      metadataVersion: currentShoppingItemVersion,
      sourceReferenceIds: item.sourceReferenceIds,
    );
  }

  ShoppingList _withShoppingItems(
    ShoppingList current,
    List<ShoppingItem> items,
    DateTime committedAt,
  ) {
    final sorted = items.map(_upgradeShoppingItem).toList()
      ..sort(_compareShoppingItems);
    return current.copyWith(
      revision: current.revision + 1,
      items: sorted,
      updatedAt: committedAt,
    );
  }

  ShoppingItem? _findShoppingItem(ShoppingList list, String itemId) {
    return list.items.where((item) => item.id == itemId).firstOrNull;
  }

  bool _completedShoppingItemsArePreserved(
    ShoppingList current,
    ShoppingList requested,
  ) {
    final requestedById = <String, ShoppingItem>{
      for (final item in requested.items) item.id: item,
    };
    for (final item in current.items.where(
      (candidate) => candidate.status != ShoppingItemStatus.active,
    )) {
      final replacement = requestedById[item.id];
      if (replacement == null ||
          calculateChecksum(item.toJson()) !=
              calculateChecksum(replacement.toJson())) {
        return false;
      }
    }
    return true;
  }

  double _roundShoppingQuantity(double quantity, String unitId) {
    return _unitConversionEngine!.precisionPolicy.apply(
      quantity,
      decimalPlaces: _unitConversionEngine.resolveUnit(unitId)?.decimalPlaces,
    );
  }

  _ShoppingPantryChange _applyShoppingPurchase(
    List<Ingredient> before,
    ShoppingItem item,
    String transactionId,
    DateTime committedAt,
  ) {
    final registry = _canonicalIngredientRegistry!;
    final unitEngine = _unitConversionEngine!;
    final canonical = registry.byId(item.canonicalIngredientId)!;
    final candidates =
        before
            .where(
              (lot) =>
                  lot.quantity >= 0 &&
                  !lot.isExpiredAt(committedAt) &&
                  registry.canonicalIdFor(lot.canonicalIngredientId) ==
                      canonical.id,
            )
            .toList()
          ..sort((first, second) {
            final firstUnit = unitEngine.resolveUnitId(
              first.canonicalUnitId.isEmpty
                  ? first.unit
                  : first.canonicalUnitId,
            );
            final secondUnit = unitEngine.resolveUnitId(
              second.canonicalUnitId.isEmpty
                  ? second.unit
                  : second.canonicalUnitId,
            );
            final exact = (firstUnit == item.unitId ? 0 : 1).compareTo(
              secondUnit == item.unitId ? 0 : 1,
            );
            if (exact != 0) {
              return exact;
            }
            final created = first.createdAt.compareTo(second.createdAt);
            return created != 0 ? created : first.id.compareTo(second.id);
          });

    if (candidates.isNotEmpty) {
      final lot = candidates.first;
      final pantryUnitId = unitEngine.resolveUnitId(
        lot.canonicalUnitId.isEmpty ? lot.unit : lot.canonicalUnitId,
      )!;
      final added = unitEngine
          .tryConvert(
            item.quantity,
            fromUnit: item.unitId,
            toUnit: pantryUnitId,
          )
          .value!;
      final afterQuantity = _roundShoppingQuantity(
        lot.quantity + added,
        pantryUnitId,
      );
      final updated = lot.copyWith(
        quantity: afterQuantity,
        updatedAt: committedAt,
      );
      final pantry = before
          .map((current) => current.id == lot.id ? updated : current)
          .toList(growable: false);
      return _ShoppingPantryChange(
        pantry: pantry,
        receipt: ShoppingPurchase(
          transactionId: transactionId,
          pantryLotId: lot.id,
          createdPantryLot: false,
          pantryUnitId: pantryUnitId,
          beforeQuantity: lot.quantity,
          afterQuantity: afterQuantity,
          purchasedAt: committedAt,
        ),
        change: PantryQuantityChange(
          ingredientId: lot.id,
          ingredientName: lot.name,
          unit: lot.unit,
          beforeQuantity: lot.quantity,
          afterQuantity: afterQuantity,
          canonicalIngredientId: canonical.id,
          canonicalUnitId: pantryUnitId,
        ),
      );
    }

    final pantryLotId = 'shopping-purchase:$transactionId';
    final lot = Ingredient(
      id: pantryLotId,
      name: canonical.displayName(),
      category: canonical.category,
      emoji: canonical.emoji,
      quantity: item.quantity,
      unit: unitEngine.resolveUnit(item.unitId)!.displayName,
      createdAt: committedAt,
      updatedAt: committedAt,
      canonicalIngredientId: canonical.id,
      canonicalUnitId: item.unitId,
      canonicalMappingStatus: CanonicalMappingStatus.mapped,
    );
    return _ShoppingPantryChange(
      pantry: <Ingredient>[...before, lot],
      receipt: ShoppingPurchase(
        transactionId: transactionId,
        pantryLotId: pantryLotId,
        createdPantryLot: true,
        pantryUnitId: item.unitId,
        beforeQuantity: 0,
        afterQuantity: item.quantity,
        purchasedAt: committedAt,
      ),
      change: PantryQuantityChange(
        ingredientId: pantryLotId,
        ingredientName: lot.name,
        unit: lot.unit,
        beforeQuantity: 0,
        afterQuantity: item.quantity,
        canonicalIngredientId: canonical.id,
        canonicalUnitId: item.unitId,
      ),
    );
  }

  _ShoppingPantryChange _undoShoppingPurchase(
    List<Ingredient> before,
    ShoppingItem item,
    DateTime committedAt,
  ) {
    final receipt = item.purchase!;
    final lot = before
        .where((candidate) => candidate.id == receipt.pantryLotId)
        .first;
    final pantry = receipt.createdPantryLot
        ? before
              .where((current) => current.id != receipt.pantryLotId)
              .toList(growable: false)
        : before
              .map(
                (current) => current.id == receipt.pantryLotId
                    ? current.copyWith(
                        quantity: receipt.beforeQuantity,
                        updatedAt: committedAt,
                      )
                    : current,
              )
              .toList(growable: false);
    return _ShoppingPantryChange(
      pantry: pantry,
      receipt: receipt,
      change: PantryQuantityChange(
        ingredientId: lot.id,
        ingredientName: lot.name,
        unit: lot.unit,
        beforeQuantity: receipt.afterQuantity,
        afterQuantity: receipt.beforeQuantity,
        canonicalIngredientId: item.canonicalIngredientId,
        canonicalUnitId: receipt.pantryUnitId,
      ),
    );
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
    List<ShoppingList>? shoppingLists,
  }) {
    final targetCapabilities = <String>{...before.capabilities};
    if (shoppingLists != null) {
      targetCapabilities
        ..add(shoppingStateCapability)
        ..add(shoppingEngineCapability);
    }
    return InventoryStateEnvelope(
      envelopeVersion: before.envelopeVersion,
      minimumReaderVersion: shoppingLists == null
          ? before.minimumReaderVersion
          : currentInventoryReaderVersion,
      capabilities: targetCapabilities.toList()..sort(),
      revision: before.revision + 1,
      lastAppliedTransactionId: transactionId,
      updatedAt: updatedAt,
      pantry: pantry,
      history: history,
      shoppingLists: shoppingLists ?? before.shoppingLists,
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

class _ShoppingPantryChange {
  const _ShoppingPantryChange({
    required this.pantry,
    required this.receipt,
    required this.change,
  });

  final List<Ingredient> pantry;
  final ShoppingPurchase receipt;
  final PantryQuantityChange change;
}

int _compareShoppingItems(ShoppingItem first, ShoppingItem second) {
  final status = first.status.index.compareTo(second.status.index);
  if (status != 0) {
    return status;
  }
  final canonical = first.canonicalIngredientId.compareTo(
    second.canonicalIngredientId,
  );
  return canonical != 0 ? canonical : first.id.compareTo(second.id);
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
