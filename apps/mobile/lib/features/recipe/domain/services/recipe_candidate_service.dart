import '../../../../core/models/ingredient.dart';
import '../entities/recipe.dart';
import '../entities/recipe_ingredient.dart';
import '../entities/recipe_match.dart';
import '../entities/recipe_readiness.dart';
import 'recipe_readiness_service.dart';

class RecipeCandidateService {
  const RecipeCandidateService({required this.readinessService});

  final RecipeReadinessService readinessService;

  List<RecipeMatch> findCandidates({
    required List<Recipe> recipes,
    required List<Ingredient> pantry,
    required DateTime evaluatedAt,
  }) {
    final matches = <RecipeMatch>[];
    for (final recipe in recipes) {
      final match = evaluateCandidate(
        recipe: recipe,
        pantry: pantry,
        servings: recipe.servings > 0 ? recipe.servings : 1,
        evaluatedAt: evaluatedAt,
      );
      if (match != null) {
        matches.add(match);
      }
    }
    matches.sort(_compare);
    return List<RecipeMatch>.unmodifiable(matches);
  }

  /// Evaluates readiness for every recipe without requiring its primary
  /// ingredient to already be in Pantry. This powers intentional recipe
  /// exploration; shopping/home candidate flows keep using [findCandidates].
  List<RecipeMatch> evaluateAllRecipes({
    required List<Recipe> recipes,
    required List<Ingredient> pantry,
    required DateTime evaluatedAt,
  }) {
    final matches =
        recipes
            .map(
              (recipe) => evaluateReadiness(
                recipe: recipe,
                pantry: pantry,
                servings: recipe.servings > 0 ? recipe.servings : 1,
                evaluatedAt: evaluatedAt,
              ),
            )
            .toList(growable: false)
          ..sort(_compare);
    return List<RecipeMatch>.unmodifiable(matches);
  }

  bool isCandidate({
    required Recipe recipe,
    required List<Ingredient> pantry,
    required int servings,
    required DateTime evaluatedAt,
  }) {
    return evaluateCandidate(
          recipe: recipe,
          pantry: pantry,
          servings: servings,
          evaluatedAt: evaluatedAt,
        ) !=
        null;
  }

  RecipeMatch? evaluateCandidate({
    required Recipe recipe,
    required List<Ingredient> pantry,
    required int servings,
    required DateTime evaluatedAt,
  }) {
    final readiness = readinessService.evaluate(
      recipe: recipe,
      pantry: pantry,
      servings: servings,
      evaluatedAt: evaluatedAt,
    );
    if (!_hasPrimaryIngredientInPantry(readiness)) {
      return null;
    }
    return _toMatch(readiness);
  }

  RecipeMatch evaluateReadiness({
    required Recipe recipe,
    required List<Ingredient> pantry,
    required int servings,
    required DateTime evaluatedAt,
  }) {
    return _toMatch(
      readinessService.evaluate(
        recipe: recipe,
        pantry: pantry,
        servings: servings,
        evaluatedAt: evaluatedAt,
      ),
    );
  }

  RecipeMatch _toMatch(RecipeReadiness readiness) {
    final matched = <RecipeIngredient>[];
    final missing = <RecipeIngredient>[];
    for (final item in readiness.ingredients) {
      if (item.isAvailable) {
        matched.add(item.ingredient);
      } else {
        missing.add(item.ingredient);
      }
    }
    return RecipeMatch(
      recipe: readiness.recipe,
      matchedIngredients: List<RecipeIngredient>.unmodifiable(matched),
      missingIngredients: List<RecipeIngredient>.unmodifiable(missing),
      score: readiness.score,
    );
  }

  bool _hasPrimaryIngredientInPantry(RecipeReadiness readiness) {
    final hero = readiness.recipe.heroIngredient;
    return readiness.ingredients.any((item) {
      final role = item.ingredient.effectiveRole(
        isHero: identical(item.ingredient, hero),
      );
      if (role != RecipeIngredientRole.primary) {
        return false;
      }
      return switch (item.status) {
        RecipeIngredientReadinessStatus.available ||
        RecipeIngredientReadinessStatus.insufficient ||
        RecipeIngredientReadinessStatus.incompatibleUnit => true,
        RecipeIngredientReadinessStatus.missing ||
        RecipeIngredientReadinessStatus.unresolvedIngredient ||
        RecipeIngredientReadinessStatus.invalidQuantity => false,
      };
    });
  }

  int _compare(RecipeMatch first, RecipeMatch second) {
    final score = second.score.compareTo(first.score);
    if (score != 0) {
      return score;
    }
    final primary = first.missingPrimaryCount.compareTo(
      second.missingPrimaryCount,
    );
    if (primary != 0) {
      return primary;
    }
    final secondary = first.missingSecondaryCount.compareTo(
      second.missingSecondaryCount,
    );
    if (secondary != 0) {
      return secondary;
    }
    final popularity = second.recipe.popularity.compareTo(
      first.recipe.popularity,
    );
    if (popularity != 0) {
      return popularity;
    }
    return first.recipe.name.compareTo(second.recipe.name);
  }
}
