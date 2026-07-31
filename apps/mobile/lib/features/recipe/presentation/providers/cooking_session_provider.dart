import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../pantry/application/inventory_transaction_providers.dart';
import '../../domain/entities/cooking_session.dart';
import '../../domain/entities/recipe.dart';

class CookingSessionController extends Notifier<CookingSession?> {
  @override
  CookingSession? build() => null;

  CookingSession start({required Recipe recipe, required int servings}) {
    final session = CookingSession(
      id: ref.read(transactionIdGeneratorProvider).generate(),
      recipeId: recipe.id,
      recipeName: recipe.name,
      servings: servings,
      startedAt: ref.read(appClockProvider).now(),
    );
    state = session;
    return session;
  }

  void complete() => _close(CookingSessionStatus.completed);

  void abandon() => _close(CookingSessionStatus.abandoned);

  void _close(CookingSessionStatus status) {
    final session = state;
    if (session == null || !session.isActive) {
      return;
    }
    state = session.copyWith(
      status: status,
      endedAt: ref.read(appClockProvider).now(),
    );
  }
}

final cookingSessionProvider =
    NotifierProvider<CookingSessionController, CookingSession?>(
      CookingSessionController.new,
    );
