import '../../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../../../../core/models/ingredient.dart';
import '../../../recipe/domain/entities/recipe.dart';
import '../../../recipe/domain/services/recipe_readiness_service.dart';
import '../../../shopping/domain/entities/shopping_recommendation.dart';
import '../entities/pantry_insight.dart';

class PantryInsightPolicy {
  const PantryInsightPolicy({
    this.almostReadyThreshold = 0.70,
    this.maxMissingRequiredIngredients = 2,
  }) : assert(almostReadyThreshold >= 0 && almostReadyThreshold <= 1),
       assert(maxMissingRequiredIngredients > 0);

  final double almostReadyThreshold;
  final int maxMissingRequiredIngredients;
}

class PantryInsightService {
  const PantryInsightService({
    required this.readinessService,
    required this.registry,
    this.policy = const PantryInsightPolicy(),
  });

  final RecipeReadinessService readinessService;
  final CanonicalIngredientRegistry registry;
  final PantryInsightPolicy policy;

  PantryInsight analyze({
    required List<Ingredient> pantry,
    required List<Recipe> recipes,
    required List<ShoppingRecommendation> recommendations,
    required DateTime evaluatedAt,
  }) {
    final orderedRecipes = List<Recipe>.of(recipes)
      ..sort((first, second) => first.id.compareTo(second.id));
    final readiness = readinessService.evaluateAll(
      recipes: orderedRecipes,
      pantry: pantry,
      evaluatedAt: evaluatedAt.toUtc(),
    );

    var availableRecipeCount = 0;
    var almostReadyRecipeCount = 0;
    final missingCanonicalFamilies = <String>[];

    for (final result in readiness) {
      if (result.canCook) {
        availableRecipeCount++;
      } else if (result.score >= policy.almostReadyThreshold &&
          result.missingIngredients.length <=
              policy.maxMissingRequiredIngredients) {
        almostReadyRecipeCount++;
      }

      for (final missing in result.missingIngredients) {
        final canonicalId = registry.canonicalIdFor(
          missing.canonicalIngredientId,
        );
        if (canonicalId == null) {
          continue;
        }
        final alreadyCounted = missingCanonicalFamilies.any(
          (existing) => registry.areCompatibleIds(existing, canonicalId),
        );
        if (!alreadyCounted) {
          missingCanonicalFamilies.add(canonicalId);
        }
      }
    }

    final topRecommendation = recommendations.firstOrNull;
    return PantryInsight(
      ingredientCount: pantry.length,
      availableRecipeCount: availableRecipeCount,
      almostReadyRecipeCount: almostReadyRecipeCount,
      missingIngredientCount: missingCanonicalFamilies.length,
      recommendationCount: recommendations.length,
      topRecommendationName: topRecommendation?.displayName,
      topRecommendationRecipesUnlocked:
          topRecommendation?.evidence.recipesUnlocked ?? 0,
    );
  }
}
