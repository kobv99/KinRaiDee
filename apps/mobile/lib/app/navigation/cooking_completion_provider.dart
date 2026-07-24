import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/pantry/domain/models/pantry_quantity_transaction.dart';

class CookingCompletionNotifier
    extends Notifier<PantryQuantityTransaction?> {
  @override
  PantryQuantityTransaction? build() => null;

  void publish(PantryQuantityTransaction transaction) {
    state = transaction;
  }

  void clear() {
    state = null;
  }
}

final cookingCompletionProvider =
    NotifierProvider<
      CookingCompletionNotifier,
      PantryQuantityTransaction?
    >(CookingCompletionNotifier.new);
