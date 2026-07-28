import 'recipe.dart';
import 'recipe_ingredient.dart';

enum RecipeIngredientReadinessStatus {
  available,
  substituted,
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
    this.substituteCanonicalIngredientId,
  });

  final RecipeIngredient ingredient;
  final String canonicalIngredientId;
  final double requiredQuantity;
  final double availableQuantity;
  final double shortageQuantity;
  final double availabilityRatio;
  final double weight;
  final RecipeIngredientReadinessStatus status;
  final String? substituteCanonicalIngredientId;

  RecipeIngredientRole get role => ingredient.effectiveRole();
  bool get isPrimary => role == RecipeIngredientRole.primary;
  bool get isSecondary => role == RecipeIngredientRole.secondary;
  bool get isOptional => role == RecipeIngredientRole.optional;
  bool get isAvailable =>
      status == RecipeIngredientReadinessStatus.available ||
      status == RecipeIngredientReadinessStatus.substituted;
  bool get isSubstituted =>
      status == RecipeIngredientReadinessStatus.substituted;
  bool get needsShopping => !isOptional && !isAvailable;
}

class RecipeReadiness {
  RecipeReadiness({
    required this.recipe,
    required this.servings,
    required this.score,
    required List<RecipeIngredientReadiness> ingredients,
  }) : ingredients = List<RecipeIngredientReadiness>.unmodifiable(ingredients);

  final Recipe recipe;
  final int servings;
  final double score;
  final List<RecipeIngredientReadiness> ingredients;

  int get scorePercent => (score.clamp(0, 1) * 100).round();

  List<RecipeIngredientReadiness> get availableIngredients =>
      _select((item) => item.isAvailable);

  List<RecipeIngredientReadiness> get missingIngredients =>
      _select((item) => item.needsShopping);

  List<RecipeIngredientReadiness> get optionalIngredients =>
      _select((item) => item.isOptional);

  List<RecipeIngredientReadiness> get missingOptionalIngredients =>
      _select((item) => item.isOptional && !item.isAvailable);

  bool get canCook => !ingredients.any((item) => item.needsShopping);

  List<RecipeIngredientReadiness> _select(
    bool Function(RecipeIngredientReadiness item) predicate,
  ) {
    return List<RecipeIngredientReadiness>.unmodifiable(
      ingredients.where(predicate),
    );
  }
}
