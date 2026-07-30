class IngredientSubstitution {
  IngredientSubstitution({
    required this.id,
    required this.originalIngredientId,
    required this.substituteIngredientId,
    required this.confidence,
    required this.flavorSimilarity,
    required this.textureSimilarity,
    required this.cookingMethodCompatibility,
    required List<String> suitableDishes,
    required List<String> unsuitableDishes,
    required this.category,
    required this.notes,
    required this.flavorDifference,
    required this.textureDifference,
    required this.limitations,
    Map<String, Object?> extensions = const {},
  }) : suitableDishes = List.unmodifiable(suitableDishes),
       unsuitableDishes = List.unmodifiable(unsuitableDishes),
       extensions = Map.unmodifiable(extensions);

  final String id;
  final String originalIngredientId;
  final String substituteIngredientId;
  final double confidence;
  final double flavorSimilarity;
  final double textureSimilarity;
  final double cookingMethodCompatibility;
  final List<String> suitableDishes;
  final List<String> unsuitableDishes;
  final String category;
  final String notes;
  final String flavorDifference;
  final String textureDifference;
  final String limitations;
  final Map<String, Object?> extensions;
}

class IngredientSubstitutionRecommendation {
  const IngredientSubstitutionRecommendation({
    required this.substitution,
    required this.isAvailableInPantry,
    required this.compatibilityScore,
    required this.reason,
  });

  final IngredientSubstitution substitution;
  final bool isAvailableInPantry;
  final double compatibilityScore;
  final String reason;
}
