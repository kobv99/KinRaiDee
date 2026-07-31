import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/storage_service.dart';

/// The person's preferred starting serving count for a new cooking
/// session — `null` means "use the recipe's own base servings" (the
/// previous, only behavior). Persisted so it survives app restarts.
class DefaultServingsNotifier extends Notifier<int?> {
  @override
  int? build() {
    try {
      return StorageService.loadDefaultServings();
    } on StateError {
      return null;
    }
  }

  Future<void> set(int? servings) async {
    state = servings;
    if (servings == null) {
      return;
    }
    try {
      await StorageService.saveDefaultServings(servings);
    } on StateError {
      // Storage is unavailable only in isolated tests.
    }
  }
}

final defaultServingsProvider = NotifierProvider<DefaultServingsNotifier, int?>(
  DefaultServingsNotifier.new,
);
