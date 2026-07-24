import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/storage_service.dart';
import '../../domain/models/cooking_history_entry.dart';
import '../../domain/models/pantry_quantity_transaction.dart';

class CookingHistoryNotifier extends Notifier<List<CookingHistoryEntry>> {
  @override
  List<CookingHistoryEntry> build() {
    try {
      return StorageService.loadCookingHistory();
    } on StateError {
      return const <CookingHistoryEntry>[];
    }
  }

  Future<void> record(PantryQuantityTransaction transaction) async {
    final entry = CookingHistoryEntry.fromTransaction(transaction);
    final withoutDuplicate = state
        .where((current) => current.id != entry.id)
        .toList(growable: false);
    final updated = <CookingHistoryEntry>[entry, ...withoutDuplicate]
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
    state = List<CookingHistoryEntry>.unmodifiable(updated);
    await _persist();
  }

  Future<void> replaceEntry(CookingHistoryEntry entry) async {
    var replaced = false;
    final updated = state
        .map((current) {
          if (current.id != entry.id) {
            return current;
          }
          replaced = true;
          return entry;
        })
        .toList(growable: false);

    if (!replaced) {
      return;
    }

    updated.sort((first, second) => second.createdAt.compareTo(first.createdAt));
    state = List<CookingHistoryEntry>.unmodifiable(updated);
    await _persist();
  }

  Future<void> markCancelledForTransaction(
    PantryQuantityTransaction transaction,
  ) async {
    final id = transactionHistoryId(transaction);
    final entry = state.where((item) => item.id == id).firstOrNull;
    if (entry == null || entry.isCancelled) {
      return;
    }

    final cancelledChanges = entry.changes
        .map((change) => change.copyWith(afterQuantity: change.beforeQuantity))
        .toList(growable: false);
    await replaceEntry(
      entry.copyWith(
        changes: List<CookingHistoryChange>.unmodifiable(cancelledChanges),
        status: CookingHistoryStatus.cancelled,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _persist() async {
    try {
      await StorageService.saveCookingHistory(state);
    } on StateError {
      // Isolated provider tests may not initialize Hive.
    }
  }
}

final cookingHistoryProvider =
    NotifierProvider<CookingHistoryNotifier, List<CookingHistoryEntry>>(
      CookingHistoryNotifier.new,
    );

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}
