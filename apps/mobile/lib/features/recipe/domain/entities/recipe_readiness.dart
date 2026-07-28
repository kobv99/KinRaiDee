import 'recipe.dart';
import 'recipe_ingredient.dart';

enum RecipeIngredientReadinessStatus {
  available,
  insufficient,
  missing,
  incompatibleUnit,
  unresolvedIngredient,
  invalidQuantity,
}

class RecipeIngredientReadiness {
  const RecipeIngredientReadiness({
    required this.ingredient,
    required this.canonicalIngredientId,
    required this.requiredQuantity,
    required this.availableQuantity,
    required this.shortageQuantity,
    required this.availabilityRatio,
    required this.weight,
    required this.status,
  });

  final RecipeIngredient ingredient;
  final String canonicalIngredientId;
  final double requiredQuantity;
  final double availableQuantity;
  final double shortageQuantity;
  final double availabilityRatio;
  final double weight;
  final RecipeIngredientReadinessStatus status;

  bool get isOptional => !ingredient.required;
  bool get isAvailable => status == RecipeIngredientReadinessStatus.available;
  bool get needsShopping => ingredient.required && !isAvailable;
}

class RecipeReadiness {
  const RecipeReadiness({
    required this.recipe,
    required this.servings,
    required this.score,
    required this.ingredients,
  });

  final Recipe recipe;
  final int servings;
  final double score;
  final List<RecipeIngredientReadiness> ingredients;

  int get scorePercent => (score.clamp(0, 1) * 100).round();

  List<RecipeIngredientReadiness> get availableIngredients => ingredients
      .where((item) => item.isAvailable)
      .toList(growable: false);

  List<RecipeIngredientReadiness> get missingIngredients => ingredients
      .where((item) => item.needsShopping)
      .toList(growable: false);

  List<RecipeIngredientReadiness> get optionalIngredients => ingredients
      .where((item) => item.isOptional)
      .toList(growable: false);

  List<RecipeIngredientReadiness> get missingOptionalIngredients => ingredients
      .where((item) => item.isOptional && !item.isAvailable)
      .toList(growable: false);

  bool get canCook => missingIngredients.isEmpty;
}
