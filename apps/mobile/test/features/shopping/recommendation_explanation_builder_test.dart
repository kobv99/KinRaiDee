import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_recommendation.dart';
import 'package:mobile/features/shopping/domain/services/recommendation_explanation_builder.dart';

void main() {
  test('builds supported types and explanation from domain evidence', () {
    const builder = RecommendationExplanationBuilder();
    final evidence = RecommendationEvidence(
      impactedRecipeCount: 4,
      recipesUnlocked: 2,
      averageReadinessBefore: 0.6,
      averageReadinessAfter: 0.8,
      averageReadinessIncrease: 0.2,
      totalReadinessIncrease: 0.8,
      primaryRecipeCount: 2,
      secondaryRecipeCount: 2,
      ingredientFrequency: 4,
      almostReadyRecipeCount: 1,
      hasPantrySynergy: true,
      reasonCodes: const <RecommendationReasonCode>[],
    );

    final result = builder.build(
      ingredientName: 'Egg',
      evidence: evidence,
      impacts: const <RecommendationRecipeImpact>[],
    );

    expect(result.types, <ShoppingRecommendationType>[
      ShoppingRecommendationType.unlockMostRecipes,
      ShoppingRecommendationType.improveRecipeReadiness,
      ShoppingRecommendationType.completeAlmostReadyRecipes,
      ShoppingRecommendationType.frequentlyUsedIngredient,
    ]);
    expect(result.reason, contains('Egg'));
    expect(result.reason, contains('Pantry'));
  });
}
