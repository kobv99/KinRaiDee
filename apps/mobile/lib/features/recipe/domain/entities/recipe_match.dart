import 'recipe.dart';
import 'recipe_ingredient.dart';

class RecipeMatch {
  const RecipeMatch({
    required this.recipe,
    required this.matchedIngredients,
    required this.missingIngredients,
    required this.score,
  });

  final Recipe recipe;
  final List<RecipeIngredient> matchedIngredients;
  final List<RecipeIngredient> missingIngredients;
  final double score;

  List<RecipeIngredient> get matchedRequiredIngredients => matchedIngredients
      .where((item) => item.required)
      .toList(growable: false);

  List<RecipeIngredient> get matchedOptionalIngredients => matchedIngredients
      .where((item) => !item.required)
      .toList(growable: false);

  List<RecipeIngredient> get missingRequiredIngredients => missingIngredients
      .where((item) => item.required)
      .toList(growable: false);

  List<RecipeIngredient> get missingOptionalIngredients => missingIngredients
      .where((item) => !item.required)
      .toList(growable: false);

  int get missingRequiredCount => missingRequiredIngredients.length;

  int get missingOptionalCount => missingOptionalIngredients.length;

  bool get canCook => missingRequiredCount == 0;

  int get scorePercent => (score.clamp(0, 1) * 100).round();
}
