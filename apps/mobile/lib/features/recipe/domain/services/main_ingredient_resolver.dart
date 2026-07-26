import '../entities/recipe.dart';
import 'ingredient_name_matcher.dart';

class MainIngredientResolution {
  const MainIngredientResolution({
    required this.key,
    required this.recipeCount,
  });

  final String key;
  final int recipeCount;
}

class MainIngredientResolver {
  const MainIngredientResolver();

  MainIngredientResolution? resolve({
    required String pantryIngredientName,
    required Iterable<Recipe> recipes,
  }) {
    String? resolvedKey;
    var recipeCount = 0;

    for (final recipe in recipes) {
      final hero = recipe.heroIngredient;
      if (hero == null ||
          !recipeIngredientMatchesPantryName(hero, pantryIngredientName)) {
        continue;
      }

      final candidateKey = normalizeRecipeIngredientName(
        recipe.resolvedHeroIngredientId.isNotEmpty
            ? recipe.resolvedHeroIngredientId
            : recipe.resolvedHeroIngredientName,
      );
      if (candidateKey.isEmpty) {
        continue;
      }

      resolvedKey ??= candidateKey;
      if (resolvedKey == candidateKey) {
        recipeCount++;
      }
    }

    if (resolvedKey == null || recipeCount == 0) {
      return null;
    }

    return MainIngredientResolution(key: resolvedKey, recipeCount: recipeCount);
  }
}
