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

  bool get canCook => missingIngredients.where((item) => item.required).isEmpty;

  int get scorePercent => (score * 100).round();
}
