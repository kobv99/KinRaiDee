import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/storage_service.dart';
import '../../domain/models/cooking_history_entry.dart';

class CookingHistoryNotifier extends Notifier<List<CookingHistoryEntry>> {
  @override
  List<CookingHistoryEntry> build() {
    try {
      return StorageService.loadCookingHistory();
    } on StateError {
      return const <CookingHistoryEntry>[];
    }
  }

  void replaceFromCommittedSnapshot(List<CookingHistoryEntry> entries) {
    final sorted = List<CookingHistoryEntry>.of(entries)
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
    state = List<CookingHistoryEntry>.unmodifiable(sorted);
  }
}

final cookingHistoryProvider =
    NotifierProvider<CookingHistoryNotifier, List<CookingHistoryEntry>>(
      CookingHistoryNotifier.new,
    );
