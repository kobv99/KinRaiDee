import 'recipe_ingredient.dart';
import 'recipe_match.dart';

enum RecommendationBadge {
  perfectMatch,
  pantryFriendly,
  quickMeal,
  fewMissing,
  usesExpiringIngredients,
  healthyChoice,
}

class RecommendationScoreComponent {
  const RecommendationScoreComponent({
    required this.id,
    required this.rawValue,
    required this.weight,
    required this.points,
    required this.explanation,
  });

  final String id;
  final double rawValue;
  final double weight;
  final double points;
  final String explanation;
}

class RecipeRecommendation {
  const RecipeRecommendation({
    required this.match,
    required this.score,
    required this.components,
    required this.reasons,
    required this.badges,
    required this.expiringIngredientIds,
    required this.availableSubstitutions,
    required this.pantryIngredientCount,
    required this.usedPantryIngredientCount,
  });

  final RecipeMatch match;
  final double score;
  final List<RecommendationScoreComponent> components;
  final List<String> reasons;
  final List<RecommendationBadge> badges;
  final List<String> expiringIngredientIds;
  final Map<String, String> availableSubstitutions;
  final int pantryIngredientCount;
  final int usedPantryIngredientCount;

  int get scorePercent => score.clamp(0, 100).round();
  int get recipeMatchPercent => match.scorePercent;
  int get availableIngredientCount => match.matchedIngredients.length;
  int get totalIngredientCount =>
      match.matchedIngredients.length + match.missingIngredients.length;
  int get missingIngredientCount => match.missingRequiredCount;
  int get pantryCompletionPercent => totalIngredientCount == 0
      ? 100
      : ((availableIngredientCount / totalIngredientCount) * 100).round();
  int get pantryUtilizationPercent => pantryIngredientCount == 0
      ? 0
      : ((usedPantryIngredientCount / pantryIngredientCount) * 100).round();
  List<RecipeIngredient> get shoppingPreview =>
      match.missingRequiredIngredients;

  String get whyThisRecipe => reasons.join(' ');
}

enum RecommendationSort {
  bestMatch,
  highestScore,
  fastest,
  leastMissing,
  mostPantryUsed,
  newest,
}

class RecommendationFilter {
  const RecommendationFilter({
    this.minimumMatchPercent,
    this.maximumCookTimeMinutes,
    this.difficulty,
    this.cuisine,
    this.mainIngredientId,
    this.mealType,
    this.maximumMissingIngredients,
    this.pantryFriendlyOnly = false,
    this.healthyOnly = false,
  });

  final int? minimumMatchPercent;
  final int? maximumCookTimeMinutes;
  final String? difficulty;
  final String? cuisine;
  final String? mainIngredientId;
  final String? mealType;
  final int? maximumMissingIngredients;
  final bool pantryFriendlyOnly;
  final bool healthyOnly;
}
