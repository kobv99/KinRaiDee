import '../../../pantry/domain/models/inventory_state_envelope.dart';
import '../../../pantry/domain/models/inventory_transaction_record.dart';
import '../../../pantry/domain/models/pantry_quantity_transaction.dart';
import '../entities/purchase_history_entry.dart';
import '../entities/shopping_item.dart';
import '../entities/shopping_item_status.dart';

class PurchaseHistoryProjector {
  const PurchaseHistoryProjector();

  List<PurchaseHistoryEntry> project({
    required InventoryStateEnvelope snapshot,
    required Iterable<InventoryTransactionRecord> records,
  }) {
    final ordered = records
        .where(_isCommitted)
        .toList(growable: false)
      ..sort(_compareRecords);
    final openByIdentity = <String, List<PurchaseHistoryEntry>>{};
    final projectedTransactionIds = <String>{};

    for (final record in ordered) {
      switch (record.kind) {
        case InventoryTransactionKind.shoppingPurchase:
          final entry = _purchaseFromRecord(record);
          if (entry == null) {
            continue;
          }
          projectedTransactionIds.add(entry.pantryTransactionId);
          openByIdentity
              .putIfAbsent(_identity(entry.shoppingListId, entry.shoppingItemId), () => <PurchaseHistoryEntry>[])
              .add(entry);
        case InventoryTransactionKind.undoShoppingPurchase:
          final restored = _restoredShoppingIdentity(record);
          if (restored == null) {
            continue;
          }
          final purchases = openByIdentity[_identity(restored.$1, restored.$2)];
          if (purchases == null || purchases.isEmpty) {
            continue;
          }
          purchases.removeLast();
        default:
          break;
      }
    }

    // Older envelopes stored the purchase receipt on a completed Shopping item.
    // Keep those records readable when their transaction journal is unavailable.
    for (final list in snapshot.shoppingLists) {
      for (final item in list.items) {
        final purchase = item.purchase;
        if (item.status == ShoppingItemStatus.active ||
            purchase == null ||
            projectedTransactionIds.contains(purchase.transactionId)) {
          continue;
        }
        final entry = PurchaseHistoryEntry(
          id: purchase.transactionId,
          purchasedAt: purchase.purchasedAt,
          ingredientId: item.id,
          canonicalIngredientId: item.canonicalIngredientId,
          ingredientName: item.displayName,
          quantity: item.quantity,
          unitId: item.unitId,
          sourceRecipeIds: item.sourceReferenceIds,
          shoppingListId: list.id,
          shoppingItemId: item.id,
          pantryTransactionId: purchase.transactionId,
          pantryLotIds: <String>[purchase.pantryLotId],
        );
        openByIdentity
            .putIfAbsent(_identity(list.id, item.id), () => <PurchaseHistoryEntry>[])
            .add(entry);
      }
    }

    final result = openByIdentity.values.expand((entries) => entries).toList()
      ..sort((first, second) {
        final time = second.purchasedAt.compareTo(first.purchasedAt);
        return time != 0 ? time : first.id.compareTo(second.id);
      });
    return List<PurchaseHistoryEntry>.unmodifiable(result);
  }

  PurchaseHistoryEntry? _purchaseFromRecord(InventoryTransactionRecord record) {
    final before = record.beforeEnvelope;
    final after = record.afterEnvelope;
    if (before == null || after == null) {
      return null;
    }

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
        if (afterItem != null && afterItem.status == ShoppingItemStatus.active) {
          continue;
        }
        return PurchaseHistoryEntry(
          id: record.transactionId,
          purchasedAt: record.createdAt,
          ingredientId: item.id,
          canonicalIngredientId: item.canonicalIngredientId,
          ingredientName: item.displayName,
          quantity: item.quantity,
          unitId: item.unitId,
          sourceRecipeIds: item.sourceReferenceIds,
          shoppingListId: beforeList.id,
          shoppingItemId: item.id,
          pantryTransactionId: record.transactionId,
          pantryLotIds: _changedPantryLotIds(before, after),
        );
      }
    }
    return null;
  }

  (String, String)? _restoredShoppingIdentity(
    InventoryTransactionRecord record,
  ) {
    final before = record.beforeEnvelope;
    final after = record.afterEnvelope;
    if (before == null || after == null) {
      return null;
    }
    for (final afterList in after.shoppingLists) {
      final beforeList = before.shoppingLists
          .where((candidate) => candidate.id == afterList.id)
          .firstOrNull;
      for (final item in afterList.items.where(
        (candidate) => candidate.status == ShoppingItemStatus.active,
      )) {
        final previous = beforeList?.items
            .where((candidate) => candidate.id == item.id)
            .firstOrNull;
        if (previous == null || previous.status != ShoppingItemStatus.active) {
          return (afterList.id, item.id);
        }
      }
    }
    return null;
  }

  List<String> _changedPantryLotIds(
    InventoryStateEnvelope before,
    InventoryStateEnvelope after,
  ) {
    final beforeById = {for (final item in before.pantry) item.id: item.toJson()};
    final afterById = {for (final item in after.pantry) item.id: item.toJson()};
    final ids = <String>{...beforeById.keys, ...afterById.keys};
    final changed = ids
        .where((id) => !_mapsEqual(beforeById[id], afterById[id]))
        .toList()
      ..sort();
    return List<String>.unmodifiable(changed);
  }
}

bool _isCommitted(InventoryTransactionRecord record) {
  return record.state == InventoryTransactionState.committed ||
      record.state == InventoryTransactionState.completing ||
      record.state == InventoryTransactionState.completed;
}

int _compareRecords(
  InventoryTransactionRecord first,
  InventoryTransactionRecord second,
) {
  final time = first.createdAt.compareTo(second.createdAt);
  return time != 0 ? time : first.transactionId.compareTo(second.transactionId);
}

String _identity(String listId, String itemId) => '$listId::$itemId';

bool _mapsEqual(Map<String, dynamic>? first, Map<String, dynamic>? second) {
  if (identical(first, second)) {
    return true;
  }
  if (first == null || second == null || first.length != second.length) {
    return false;
  }
  for (final entry in first.entries) {
    if (second[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
