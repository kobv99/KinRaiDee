import '../../../../core/models/ingredient.dart';
import '../entities/recipe.dart';
import '../entities/recipe_ingredient.dart';
import '../entities/recipe_match.dart';
import 'ingredient_name_matcher.dart';

class RecipeMatcher {
  const RecipeMatcher({
    this.requiredWeight = 0.8,
    this.optionalWeight = 0.2,
  }) : assert(requiredWeight >= 0),
       assert(optionalWeight >= 0),
       assert(requiredWeight + optionalWeight > 0);

  final double requiredWeight;
  final double optionalWeight;

  List<RecipeMatch> match({
    required List<Recipe> recipes,
    required List<Ingredient> pantry,
  }) {
    final pantryNames = pantry
        .where(_isAvailable)
        .map((item) => normalizeRecipeIngredientName(item.name))
        .where((name) => name.isNotEmpty)
        .toSet();

    final results = recipes
        .map((recipe) => _matchRecipe(recipe, pantryNames))
        .toList(growable: false);

    return [...results]..sort(_compareMatches);
  }

  RecipeMatch _matchRecipe(Recipe recipe, Set<String> pantryNames) {
    final matched = <RecipeIngredient>[];
    final missing = <RecipeIngredient>[];

    for (final ingredient in recipe.ingredients) {
      if (_hasIngredient(ingredient, pantryNames)) {
        matched.add(ingredient);
      } else {
        missing.add(ingredient);
      }
    }

    return RecipeMatch(
      recipe: recipe,
      matchedIngredients: List.unmodifiable(matched),
      missingIngredients: List.unmodifiable(missing),
      score: _calculateScore(
        ingredients: recipe.ingredients,
        matchedIngredients: matched,
      ),
    );
  }

  bool _isAvailable(Ingredient ingredient) {
    return ingredient.quantity > 0 && !ingredient.isExpired;
  }

  bool _hasIngredient(
    RecipeIngredient ingredient,
    Set<String> pantryNames,
  ) {
    return pantryNames.any(
      (pantryName) => recipeIngredientMatchesPantryName(
        ingredient,
        pantryName,
      ),
    );
  }

  double _calculateScore({
    required List<RecipeIngredient> ingredients,
    required List<RecipeIngredient> matchedIngredients,
  }) {
    if (ingredients.isEmpty) {
      return 1;
    }

    final required = ingredients.where((item) => item.required).toList();
    final optional = ingredients.where((item) => !item.required).toList();
    final matchedRequired = matchedIngredients
        .where((item) => item.required)
        .length;
    final matchedOptional = matchedIngredients
        .where((item) => !item.required)
        .length;

    final requiredRatio = _ratio(matchedRequired, required.length);
    final optionalRatio = _ratio(matchedOptional, optional.length);

    if (required.isEmpty) {
      return optionalRatio;
    }

    if (optional.isEmpty) {
      return requiredRatio;
    }

    final totalWeight = requiredWeight + optionalWeight;
    return ((requiredRatio * requiredWeight) +
            (optionalRatio * optionalWeight)) /
        totalWeight;
  }

  double _ratio(int matched, int total) {
    if (total == 0) {
      return 1;
    }

    return matched / total;
  }

  int _compareMatches(RecipeMatch first, RecipeMatch second) {
    final scoreComparison = second.score.compareTo(first.score);
    if (scoreComparison != 0) {
      return scoreComparison;
    }

    final cookableComparison = second.canCook.toString().compareTo(
      first.canCook.toString(),
    );
    if (cookableComparison != 0) {
      return cookableComparison;
    }

    final requiredMissingComparison = first.missingRequiredCount.compareTo(
      second.missingRequiredCount,
    );
    if (requiredMissingComparison != 0) {
      return requiredMissingComparison;
    }

    final totalMissingComparison = first.missingIngredients.length.compareTo(
      second.missingIngredients.length,
    );
    if (totalMissingComparison != 0) {
      return totalMissingComparison;
    }

    return first.recipe.name.compareTo(second.recipe.name);
  }
}
