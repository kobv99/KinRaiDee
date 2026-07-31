import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks which recipe IDs the person has marked as favorite.
///
/// NOTE: this is in-memory only (state resets on app restart). There is
/// no existing favorite-recipe persistence anywhere in the codebase (only
/// favorite *ingredients* in Pantry has real storage). Wiring durable
/// storage (a Hive box, same pattern as Pantry) is a follow-up — this
/// makes the previously-decorative heart icon on Recipe Detail actually
/// work for the current session, which is what was reported broken.
class FavoriteRecipeIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void toggle(String recipeId) {
    final next = {...state};
    if (!next.remove(recipeId)) {
      next.add(recipeId);
    }
    state = next;
  }
}

final favoriteRecipeIdsProvider = NotifierProvider<FavoriteRecipeIdsNotifier, Set<String>>(
  FavoriteRecipeIdsNotifier.new,
);
