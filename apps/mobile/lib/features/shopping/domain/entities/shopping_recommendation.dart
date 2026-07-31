import '../../../recipe/domain/entities/recipe_ingredient.dart';

enum RecommendationReasonCode {
  unlocksManyRecipes,
  highRecipeFrequency,
  primaryIngredientInManyRecipes,
  improvesNearlyReadyRecipes,
  highAverageReadinessIncrease,
  pairsWithCurrentPantry,
  lowPurchaseEffortHighBenefit,
  alreadyPartiallyAvailable,
}

enum ShoppingRecommendationType {
  unlockMostRecipes,
  improveRecipeReadiness,
  completeAlmostReadyRecipes,
  frequentlyUsedIngredient,
}

class RecommendationRecipeImpact {
  const RecommendationRecipeImpact({
    required this.recipeId,
    required this.recipeName,
    required this.readinessBefore,
    required this.readinessAfter,
    required this.readinessIncrease,
    required this.becomesUnlocked,
    required this.ingredientRole,
    required this.shortageQuantity,
    required this.shortageUnitId,
  });

  final String recipeId;
  final String recipeName;
  final double readinessBefore;
  final double readinessAfter;
  final double readinessIncrease;
  final bool becomesUnlocked;
  final RecipeIngredientRole ingredientRole;
  final double shortageQuantity;
  final String shortageUnitId;

  int get readinessBeforePercent => (readinessBefore.clamp(0, 1) * 100).round();
  int get readinessAfterPercent => (readinessAfter.clamp(0, 1) * 100).round();
  int get readinessIncreasePercent =>
      (readinessIncrease.clamp(0, 1) * 100).round();

  Map<String, Object> toJson() {
    return <String, Object>{
      'recipeId': recipeId,
      'recipeName': recipeName,
      'readinessBefore': readinessBefore,
      'readinessAfter': readinessAfter,
      'readinessIncrease': readinessIncrease,
      'becomesUnlocked': becomesUnlocked,
      'ingredientRole': ingredientRole.name,
      'shortageQuantity': shortageQuantity,
      'shortageUnitId': shortageUnitId,
    };
  }
}

class RecommendationEvidence {
  RecommendationEvidence({
    required this.impactedRecipeCount,
    required this.recipesUnlocked,
    required this.averageReadinessBefore,
    required this.averageReadinessAfter,
    required this.averageReadinessIncrease,
    required this.totalReadinessIncrease,
    required this.primaryRecipeCount,
    required this.secondaryRecipeCount,
    required this.ingredientFrequency,
    required List<RecommendationReasonCode> reasonCodes,
    this.almostReadyRecipeCount = 0,
    this.hasPantrySynergy = false,
  }) : reasonCodes = List<RecommendationReasonCode>.unmodifiable(reasonCodes);

  final int impactedRecipeCount;
  final int recipesUnlocked;
  final double averageReadinessBefore;
  final double averageReadinessAfter;
  final double averageReadinessIncrease;
  final double totalReadinessIncrease;
  final int primaryRecipeCount;
  final int secondaryRecipeCount;
  final int ingredientFrequency;
  final int almostReadyRecipeCount;
  final bool hasPantrySynergy;
  final List<RecommendationReasonCode> reasonCodes;

  int get averageReadinessBeforePercent =>
      (averageReadinessBefore.clamp(0, 1) * 100).round();
  int get averageReadinessAfterPercent =>
      (averageReadinessAfter.clamp(0, 1) * 100).round();
  int get averageReadinessIncreasePercent =>
      (averageReadinessIncrease.clamp(0, 1) * 100).round();

  Map<String, Object> toJson() {
    return <String, Object>{
      'impactedRecipeCount': impactedRecipeCount,
      'recipesUnlocked': recipesUnlocked,
      'averageReadinessBefore': averageReadinessBefore,
      'averageReadinessAfter': averageReadinessAfter,
      'averageReadinessIncrease': averageReadinessIncrease,
      'totalReadinessIncrease': totalReadinessIncrease,
      'primaryRecipeCount': primaryRecipeCount,
      'secondaryRecipeCount': secondaryRecipeCount,
      'ingredientFrequency': ingredientFrequency,
      'almostReadyRecipeCount': almostReadyRecipeCount,
      'hasPantrySynergy': hasPantrySynergy,
      'reasonCodes': reasonCodes.map((reason) => reason.name).toList(),
    };
  }
}

class ShoppingRecommendation {
  ShoppingRecommendation({
    required this.canonicalIngredientId,
    required this.displayName,
    required this.emoji,
    required this.recommendedQuantity,
    required this.targetShoppingQuantity,
    required this.existingShoppingQuantity,
    required this.recommendedUnitId,
    required this.score,
    required this.evidence,
    required List<RecommendationRecipeImpact> topRecipes,
    List<ShoppingRecommendationType> types =
        const <ShoppingRecommendationType>[],
    this.reason = '',
  }) : topRecipes = List<RecommendationRecipeImpact>.unmodifiable(topRecipes),
       types = List<ShoppingRecommendationType>.unmodifiable(types);

  final String canonicalIngredientId;
  final String displayName;
  final String emoji;

  /// Additional quantity the user should add to Shopping now.
  final double recommendedQuantity;

  /// Total active Shopping coverage needed for the deterministic simulation.
  final double targetShoppingQuantity;

  /// Compatible active Shopping quantity already present when evaluated.
  final double existingShoppingQuantity;
  final String recommendedUnitId;
  final double score;
  final RecommendationEvidence evidence;
  final List<RecommendationRecipeImpact> topRecipes;
  final List<ShoppingRecommendationType> types;
  final String reason;

  bool get hasExistingShoppingCoverage => existingShoppingQuantity > 0;

  Map<String, Object> toJson() {
    return <String, Object>{
      'canonicalIngredientId': canonicalIngredientId,
      'displayName': displayName,
      'emoji': emoji,
      'recommendedQuantity': recommendedQuantity,
      'targetShoppingQuantity': targetShoppingQuantity,
      'existingShoppingQuantity': existingShoppingQuantity,
      'recommendedUnitId': recommendedUnitId,
      'score': score,
      'evidence': evidence.toJson(),
      'topRecipes': topRecipes.map((impact) => impact.toJson()).toList(),
      'types': types.map((type) => type.name).toList(),
      'reason': reason,
    };
  }
}
