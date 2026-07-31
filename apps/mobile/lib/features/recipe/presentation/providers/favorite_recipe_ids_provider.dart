import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/recipe_repository.dart';
import 'recipe_provider.dart';

/// Tracks which recipe IDs the person has marked as favorite, durably —
/// backed by the same Hive box Pantry's favorite-ingredient-names uses
/// (`StorageService.favoriteRecipeIdsKey`), via [RecipeRepository].
class FavoriteRecipeIdsNotifier extends Notifier<Set<String>> {
  RecipeRepository get _repository => ref.read(recipeRepositoryProvider);

  @override
  Set<String> build() {
    try {
      return Set<String>.unmodifiable(_repository.getFavoriteRecipeIds());
    } on StateError {
      // Storage is unavailable only in isolated tests.
      return const <String>{};
    }
  }

  Future<void> toggle(String recipeId) async {
    final next = {...state};
    if (!next.remove(recipeId)) {
      next.add(recipeId);
    }
    state = Set<String>.unmodifiable(next);
    try {
      await _repository.saveFavoriteRecipeIds(next);
    } on StateError {
      // Storage is unavailable only in isolated tests.
    }
  }
}

final favoriteRecipeIdsProvider = NotifierProvider<FavoriteRecipeIdsNotifier, Set<String>>(
  FavoriteRecipeIdsNotifier.new,
);
