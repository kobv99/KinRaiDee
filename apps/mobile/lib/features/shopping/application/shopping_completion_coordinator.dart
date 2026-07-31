import 'dart:async';

import '../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../../../core/domain/units/unit_contract.dart';
import '../../../core/models/ingredient.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/utils/transaction_id_generator.dart';
import '../../pantry/application/inventory_transaction_coordinator.dart';
import '../../pantry/domain/models/inventory_state_envelope.dart';
import '../../pantry/domain/models/inventory_transaction_record.dart';
import '../../pantry/domain/models/pantry_quantity_transaction.dart';
import '../../pantry/domain/repositories/inventory_commit_repository.dart';
import '../../pantry/domain/services/pantry_canonical_merge_service.dart';
import '../domain/entities/shopping_item.dart';
import '../domain/entities/shopping_item_status.dart';
import '../domain/entities/shopping_list.dart';
import '../domain/services/purchase_history_projector.dart';

class ShoppingCompletionCoordinator {
  ShoppingCompletionCoordinator({
    required InventoryCommitRepository repository,
    required CanonicalIngredientRegistry registry,
    required UnitConversionEngine unitEngine,
    AppClock clock = systemAppClock,
    TransactionIdGenerator? transactionIdGenerator,
  }) : this._(repository, registry, unitEngine, clock, transactionIdGenerator);

  ShoppingCompletionCoordinator._(
    this._repository,
    CanonicalIngredientRegistry registry,
    UnitConversionEngine unitEngine,
    this._clock,
    TransactionIdGenerator? transactionIdGenerator,
  ) : _mergeService = PantryCanonicalMergeService(
        registry: registry,
        unitEngine: unitEngine,
      ),
      _transactionIdGenerator =
          transactionIdGenerator ?? SecureTransactionIdGenerator();

  final InventoryCommitRepository _repository;
  final PantryCanonicalMergeService _mergeService;
  final AppClock _clock;
  final TransactionIdGenerator _transactionIdGenerator;
  Future<void> _tail = Future<void>.value();

  Future<InventoryTransactionResult> completeItem({
    required String listId,
    required int expectedListRevision,
    required String itemId,
    required DateTime createdAt,
    bool keepSeparate = false,
    String transactionId = '',
  }) {
    return _serialized(() async {
      final before = await _repository.loadConsistentSnapshot();
      final records = await _repository.loadJournal();
      final id = transactionId.isEmpty
          ? _transactionIdGenerator.generate()
          : transactionId;
      var transaction = _transaction(
        transactionId: id,
        expectedRevision: before.revision,
        kind: InventoryTransactionKind.shoppingPurchase,
        listId: listId,
        itemId: itemId,
        createdAt: createdAt,
      );
      final checksum = calculateChecksum(<String, dynamic>{
        'action': 'completeShoppingItem',
        'transactionId': id,
        'listId': listId,
        'expectedListRevision': expectedListRevision,
        'itemId': itemId,
        'keepSeparate': keepSeparate,
        'createdAt': createdAt.toUtc().toIso8601String(),
      });
      final existing = await _existingResult(
        transaction: transaction,
        checksum: checksum,
        snapshot: before,
        records: records,
      );
      if (existing != null) {
        return existing;
      }

      final list = before.shoppingLists
          .where((candidate) => candidate.id == listId)
          .firstOrNull;
      if (list == null) {
        return _failure(
          InventoryTransactionOutcome.conflict,
          'shopping_list_not_found',
          before,
          transaction,
        );
      }
      if (list.revision != expectedListRevision) {
        return _failure(
          InventoryTransactionOutcome.conflict,
          'stale_shopping_list_revision',
          before,
          transaction,
        );
      }
      final item = list.items
          .where(
            (candidate) =>
                candidate.id == itemId &&
                candidate.status == ShoppingItemStatus.active,
          )
          .firstOrNull;
      if (item == null) {
        final projected = const PurchaseHistoryProjector().project(
          snapshot: before,
          records: records,
        );
        final completed = projected
            .where(
              (entry) =>
                  entry.shoppingListId == listId &&
                  entry.shoppingItemId == itemId,
            )
            .firstOrNull;
        if (completed != null) {
          return InventoryTransactionResult(
            outcome: InventoryTransactionOutcome.alreadyCommitted,
            code: 'already_completed',
            snapshot: before,
            transaction: transaction.copyWith(
              transactionId: completed.pantryTransactionId,
            ),
          );
        }
        return _failure(
          InventoryTransactionOutcome.conflict,
          'shopping_item_not_found',
          before,
          transaction,
        );
      }

      final committedAt = _clock.now().toUtc();
      final incoming = Ingredient(
        id: 'shopping-purchase:$id',
        name: item.displayName,
        category: item.category.name,
        emoji: '',
        quantity: item.quantity,
        unit: item.unitId,
        createdAt: committedAt,
        updatedAt: committedAt,
        canonicalIngredientId: item.canonicalIngredientId,
        canonicalUnitId: item.unitId,
        canonicalMappingStatus: CanonicalMappingStatus.mapped,
      );
      final merge = _mergeService.merge(
        current: before.pantry,
        incoming: incoming,
        mode: keepSeparate
            ? PantryCanonicalMergeMode.addSeparate
            : PantryCanonicalMergeMode.add,
        at: committedAt,
      );
      final mergeError = _shoppingMergeError(merge.errorCode);
      if (mergeError != null) {
        return _failure(
          InventoryTransactionOutcome.validationFailure,
          mergeError,
          before,
          transaction,
        );
      }

      transaction = transaction.copyWith(changes: merge.changes);
      final updatedList = list.copyWith(
        revision: list.revision + 1,
        items: list.items
            .where(
              (candidate) =>
                  candidate.status == ShoppingItemStatus.active &&
                  candidate.id != item.id,
            )
            .toList(growable: false),
        updatedAt: committedAt,
      );
      final lists =
          before.shoppingLists
              .map(
                (candidate) =>
                    candidate.id == list.id ? updatedList : candidate,
              )
              .toList(growable: false)
            ..sort(
              (first, second) => second.updatedAt.compareTo(first.updatedAt),
            );
      final after = _targetEnvelope(
        before,
        transactionId: id,
        updatedAt: committedAt,
        pantry: merge.pantry,
        shoppingLists: lists,
      );
      return _commit(transaction, checksum, before, after);
    });
  }

  Future<InventoryTransactionResult> undoCompletion({
    required String purchaseTransactionId,
    required DateTime createdAt,
    String transactionId = '',
  }) {
    return _serialized(() async {
      final current = await _repository.loadConsistentSnapshot();
      final records = await _repository.loadJournal();
      final purchaseRecord = records
          .where(
            (record) =>
                record.transactionId == purchaseTransactionId &&
                record.kind == InventoryTransactionKind.shoppingPurchase,
          )
          .firstOrNull;
      final id = transactionId.isEmpty
          ? _transactionIdGenerator.generate()
          : transactionId;
      var transaction = _transaction(
        transactionId: id,
        expectedRevision: current.revision,
        kind: InventoryTransactionKind.undoShoppingPurchase,
        listId: 'unknown',
        itemId: 'unknown',
        createdAt: createdAt,
        reversesTransactionId: purchaseTransactionId,
      );
      final checksum = calculateChecksum(<String, dynamic>{
        'action': 'undoShoppingCompletion',
        'transactionId': id,
        'purchaseTransactionId': purchaseTransactionId,
        'createdAt': createdAt.toUtc().toIso8601String(),
      });
      final existing = await _existingResult(
        transaction: transaction,
        checksum: checksum,
        snapshot: current,
        records: records,
      );
      if (existing != null) {
        return existing;
      }
      if (purchaseRecord == null || !_isCommitted(purchaseRecord)) {
        return _failure(
          InventoryTransactionOutcome.conflict,
          'purchase_history_not_found',
          current,
          transaction,
        );
      }
      final purchaseBefore = purchaseRecord.beforeEnvelope;
      final purchaseAfter = purchaseRecord.afterEnvelope;
      if (purchaseBefore == null || purchaseAfter == null) {
        return _failure(
          InventoryTransactionOutcome.recoveryRequired,
          'purchase_history_snapshot_missing',
          current,
          transaction,
        );
      }
      final removed = _removedShoppingItem(purchaseBefore, purchaseAfter);
      if (removed == null) {
        return _failure(
          InventoryTransactionOutcome.recoveryRequired,
          'purchase_history_item_missing',
          current,
          transaction,
        );
      }
      final listId = removed.$1;
      final item = removed.$2;
      transaction = _transaction(
        transactionId: id,
        expectedRevision: current.revision,
        kind: InventoryTransactionKind.undoShoppingPurchase,
        listId: listId,
        itemId: item.id,
        createdAt: createdAt,
        reversesTransactionId: purchaseTransactionId,
      );
      final affectedIds = _changedPantryIds(purchaseBefore, purchaseAfter);
      final currentList = current.shoppingLists
          .where((candidate) => candidate.id == listId)
          .firstOrNull;
      if (currentList == null) {
        return _failure(
          InventoryTransactionOutcome.conflict,
          'shopping_list_not_found',
          current,
          transaction,
        );
      }
      final alreadyRestored = currentList.items.any(
        (candidate) =>
            candidate.id == item.id &&
            candidate.status == ShoppingItemStatus.active,
      );
      if (alreadyRestored &&
          _pantryMatches(current, purchaseBefore, affectedIds)) {
        return InventoryTransactionResult(
          outcome: InventoryTransactionOutcome.alreadyUndone,
          code: 'already_undone',
          snapshot: current,
          transaction: transaction,
        );
      }
      final canonicalId = _shoppingCanonicalId(item);
      if (currentList.items.any(
        (candidate) =>
            candidate.status == ShoppingItemStatus.active &&
            (candidate.id == item.id ||
                (canonicalId != null &&
                    _shoppingCanonicalId(candidate) == canonicalId)),
      )) {
        return _failure(
          InventoryTransactionOutcome.conflict,
          'shopping_item_already_recreated',
          current,
          transaction,
        );
      }
      if (!_pantryMatches(current, purchaseAfter, affectedIds)) {
        return _failure(
          InventoryTransactionOutcome.conflict,
          'purchase_pantry_state_changed',
          current,
          transaction,
        );
      }

      final committedAt = _clock.now().toUtc();
      final restoredPantry = _restorePantry(
        current.pantry,
        purchaseBefore.pantry,
        affectedIds,
      );
      final restoredItem = item.copyWith(
        status: ShoppingItemStatus.active,
        clearPurchase: true,
        updatedAt: committedAt,
      );
      final restoredItems = <ShoppingItem>[
        ...currentList.items.where(
          (candidate) =>
              candidate.status == ShoppingItemStatus.active &&
              candidate.id != restoredItem.id,
        ),
        restoredItem,
      ]..sort(_compareShoppingItems);
      final updatedList = currentList.copyWith(
        revision: currentList.revision + 1,
        items: restoredItems,
        updatedAt: committedAt,
      );
      final lists =
          current.shoppingLists
              .map(
                (candidate) =>
                    candidate.id == currentList.id ? updatedList : candidate,
              )
              .toList(growable: false)
            ..sort(
              (first, second) => second.updatedAt.compareTo(first.updatedAt),
            );
      transaction = transaction.copyWith(
        changes: _pantryChanges(current.pantry, restoredPantry, affectedIds),
      );
      final after = _targetEnvelope(
        current,
        transactionId: id,
        updatedAt: committedAt,
        pantry: restoredPantry,
        shoppingLists: lists,
      );
      return _commit(transaction, checksum, current, after);
    });
  }

  Future<void> completePresentation(String transactionId) {
    return _repository.complete(transactionId);
  }

  String? _shoppingCanonicalId(ShoppingItem item) {
    final ingredient = Ingredient(
      id: item.id,
      name: item.displayName,
      category: item.category.name,
      emoji: '',
      quantity: item.quantity,
      unit: item.unitId,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      canonicalIngredientId: item.canonicalIngredientId,
      canonicalUnitId: item.unitId,
      canonicalMappingStatus: CanonicalMappingStatus.mapped,
    );
    return _mergeService.resolveCanonicalIngredientId(ingredient);
  }

  String? _shoppingMergeError(String? errorCode) {
    return switch (errorCode) {
      null => null,
      'unknown_canonical_pantry_ingredient' =>
        'unknown_canonical_shopping_ingredient',
      'pantry_unit_conversion_required' => 'shopping_unit_conversion_required',
      _ => errorCode,
    };
  }

  (String, ShoppingItem)? _removedShoppingItem(
    InventoryStateEnvelope before,
    InventoryStateEnvelope after,
  ) {
    for (final beforeList in before.shoppingLists) {
      final afterList = after.shoppingLists
          .where((candidate) => candidate.id == beforeList.id)
          .firstOrNull;
      for (final item in beforeList.items.where(
        (candidate) => candidate.status == ShoppingItemStatus.active,
      )) {
        final afterItem = afterList?.items
            .where((candidate) => candidate.id == item.id)
            .firstOrNull;
        if (afterItem == null ||
            afterItem.status != ShoppingItemStatus.active) {
          return (beforeList.id, item);
        }
      }
    }
    return null;
  }

  Set<String> _changedPantryIds(
    InventoryStateEnvelope before,
    InventoryStateEnvelope after,
  ) {
    final beforeById = {for (final item in before.pantry) item.id: item};
    final afterById = {for (final item in after.pantry) item.id: item};
    return <String>{
      ...beforeById.keys,
      ...afterById.keys,
    }.where((id) => !_ingredientEqual(beforeById[id], afterById[id])).toSet();
  }

  bool _pantryMatches(
    InventoryStateEnvelope current,
    InventoryStateEnvelope expected,
    Set<String> affectedIds,
  ) {
    final currentById = {for (final item in current.pantry) item.id: item};
    final expectedById = {for (final item in expected.pantry) item.id: item};
    return affectedIds.every(
      (id) => _ingredientEqual(currentById[id], expectedById[id]),
    );
  }

  List<Ingredient> _restorePantry(
    List<Ingredient> current,
    List<Ingredient> purchaseBefore,
    Set<String> affectedIds,
  ) {
    final result = current
        .where((ingredient) => !affectedIds.contains(ingredient.id))
        .toList();
    result.addAll(
      purchaseBefore.where((ingredient) => affectedIds.contains(ingredient.id)),
    );
    return List<Ingredient>.unmodifiable(result);
  }

  List<PantryQuantityChange> _pantryChanges(
    List<Ingredient> before,
    List<Ingredient> after,
    Set<String> affectedIds,
  ) {
    final beforeById = {for (final item in before) item.id: item};
    final afterById = {for (final item in after) item.id: item};
    final changes = <PantryQuantityChange>[];
    for (final id in affectedIds.toList()..sort()) {
      final previous = beforeById[id];
      final next = afterById[id];
      final identity = next ?? previous;
      if (identity == null) {
        continue;
      }
      changes.add(
        PantryQuantityChange(
          ingredientId: id,
          ingredientName: identity.name,
          unit: identity.unit,
          beforeQuantity: previous?.quantity ?? 0,
          afterQuantity: next?.quantity ?? 0,
          canonicalIngredientId: identity.canonicalIngredientId,
          canonicalUnitId: identity.canonicalUnitId,
        ),
      );
    }
    return List<PantryQuantityChange>.unmodifiable(changes);
  }

  PantryQuantityTransaction _transaction({
    required String transactionId,
    required int expectedRevision,
    required InventoryTransactionKind kind,
    required String listId,
    required String itemId,
    required DateTime createdAt,
    String? reversesTransactionId,
  }) {
    return PantryQuantityTransaction(
      transactionId: transactionId,
      expectedRevision: expectedRevision,
      kind: kind,
      reversesTransactionId: reversesTransactionId,
      recipeId: 'shopping:${kind.name}:$listId:$itemId',
      recipeName: kind == InventoryTransactionKind.shoppingPurchase
          ? 'Complete Shopping item'
          : 'Undo Shopping completion',
      servings: 1,
      changes: const <PantryQuantityChange>[],
      createdAt: createdAt,
    );
  }

  InventoryStateEnvelope _targetEnvelope(
    InventoryStateEnvelope before, {
    required String transactionId,
    required DateTime updatedAt,
    required List<Ingredient> pantry,
    required List<ShoppingList> shoppingLists,
  }) {
    final capabilities = <String>{
      ...before.capabilities,
      shoppingStateCapability,
      shoppingEngineCapability,
    }.toList()..sort();
    return InventoryStateEnvelope(
      envelopeVersion: before.envelopeVersion,
      minimumReaderVersion: currentInventoryReaderVersion,
      capabilities: capabilities,
      revision: before.revision + 1,
      lastAppliedTransactionId: transactionId,
      updatedAt: updatedAt,
      pantry: pantry,
      history: before.history,
      shoppingLists: shoppingLists,
    ).withComputedChecksum();
  }

  Future<InventoryTransactionResult?> _existingResult({
    required PantryQuantityTransaction transaction,
    required String checksum,
    required InventoryStateEnvelope snapshot,
    required List<InventoryTransactionRecord> records,
  }) async {
    final record = records
        .where(
          (candidate) => candidate.transactionId == transaction.transactionId,
        )
        .firstOrNull;
    if (record == null) {
      return null;
    }
    if (record.kind != transaction.kind || record.commandChecksum != checksum) {
      return _failure(
        InventoryTransactionOutcome.recoveryRequired,
        'transaction_identity_conflict',
        snapshot,
        transaction,
      );
    }
    if (_isCommitted(record)) {
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
        .where(
          (candidate) => candidate.transactionId == transaction.transactionId,
        )
        .firstOrNull;
    return refreshed != null && _isCommitted(refreshed)
        ? InventoryTransactionResult(
            outcome: InventoryTransactionOutcome.alreadyCommitted,
            code: 'already_committed',
            snapshot: recovery.snapshot,
            transaction: transaction,
          )
        : _failure(
            InventoryTransactionOutcome.storageFailure,
            refreshed?.errorCode ?? 'transaction_rolled_back',
            recovery.snapshot,
            transaction,
          );
  }

  Future<InventoryTransactionResult> _commit(
    PantryQuantityTransaction transaction,
    String checksum,
    InventoryStateEnvelope before,
    InventoryStateEnvelope after,
  ) async {
    final committed = await _repository.commit(
      InventoryCommit(
        transactionId: transaction.transactionId,
        kind: transaction.kind,
        commandChecksum: checksum,
        createdAt: transaction.createdAt,
        before: before,
        after: after,
      ),
    );
    final outcome = switch (committed.outcome) {
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
      code: committed.code,
      snapshot: committed.snapshot ?? before,
      transaction: transaction,
    );
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

bool _isCommitted(InventoryTransactionRecord record) {
  return record.state == InventoryTransactionState.committed ||
      record.state == InventoryTransactionState.completing ||
      record.state == InventoryTransactionState.completed;
}

bool _ingredientEqual(Ingredient? first, Ingredient? second) {
  if (identical(first, second)) {
    return true;
  }
  if (first == null || second == null) {
    return false;
  }
  return calculateChecksum(first.toJson()) ==
      calculateChecksum(second.toJson());
}

int _compareShoppingItems(ShoppingItem first, ShoppingItem second) {
  final canonical = first.canonicalIngredientId.compareTo(
    second.canonicalIngredientId,
  );
  return canonical != 0 ? canonical : first.id.compareTo(second.id);
}
