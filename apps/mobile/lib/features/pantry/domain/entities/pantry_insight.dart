class PantryInsight {
  const PantryInsight({
    required this.ingredientCount,
    required this.availableRecipeCount,
    required this.almostReadyRecipeCount,
    required this.missingIngredientCount,
    required this.recommendationCount,
    this.topRecommendationName,
    this.topRecommendationRecipesUnlocked = 0,
  });

  final int ingredientCount;
  final int availableRecipeCount;
  final int almostReadyRecipeCount;
  final int missingIngredientCount;
  final int recommendationCount;
  final String? topRecommendationName;
  final int topRecommendationRecipesUnlocked;

  bool get hasRecommendations => recommendationCount > 0;
}
