import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/inventory_transaction_providers.dart';
import '../../domain/models/cooking_history_entry.dart';

class CookingHistoryNotifier extends Notifier<List<CookingHistoryEntry>> {
  @override
  List<CookingHistoryEntry> build() {
    final recovery = ref.watch(inventoryStartupRecoveryProvider);
    return _sorted(recovery?.snapshot.history ?? const <CookingHistoryEntry>[]);
  }

  void replaceFromCommittedSnapshot(List<CookingHistoryEntry> entries) {
    state = _sorted(entries);
  }

  static List<CookingHistoryEntry> _sorted(List<CookingHistoryEntry> entries) {
    final sorted = List<CookingHistoryEntry>.of(entries)
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
    return List<CookingHistoryEntry>.unmodifiable(sorted);
  }
}

final cookingHistoryProvider =
    NotifierProvider<CookingHistoryNotifier, List<CookingHistoryEntry>>(
      CookingHistoryNotifier.new,
    );
