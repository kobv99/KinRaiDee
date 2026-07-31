import 'package:flutter_riverpod/flutter_riverpod.dart';

/// UI-only state for the "Recommended Purchases" surface, shared across
/// every screen that renders it (Pantry, Shopping). Living in a Notifier
/// instead of per-widget State keeps mutations confined to event handlers
/// and never to a widget's build() method, and lets every consuming screen
/// stay in sync without re-deriving its own copy of the same state.
class RecommendationUiState {
  const RecommendationUiState({this.dismissed = false, this.busyIngredientId});

  final bool dismissed;
  final String? busyIngredientId;
}

class RecommendationUiNotifier extends Notifier<RecommendationUiState> {
  @override
  RecommendationUiState build() => const RecommendationUiState();

  void dismiss() {
    state = RecommendationUiState(
      dismissed: true,
      busyIngredientId: state.busyIngredientId,
    );
  }

  void reset() {
    state = const RecommendationUiState();
  }

  void setBusyIngredient(String? ingredientId) {
    state = RecommendationUiState(
      dismissed: state.dismissed,
      busyIngredientId: ingredientId,
    );
  }
}

final recommendationUiProvider =
    NotifierProvider<RecommendationUiNotifier, RecommendationUiState>(
      RecommendationUiNotifier.new,
    );
