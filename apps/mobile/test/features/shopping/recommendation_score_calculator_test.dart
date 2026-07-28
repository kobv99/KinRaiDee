import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_recommendation.dart';
import 'package:mobile/features/shopping/domain/services/recommendation_score_calculator.dart';

void main() {
  test('calculates every deterministic impact factor', () {
    const calculator = RecommendationScoreCalculator(
      policy: RecommendationScorePolicy(
        unlockedRecipeWeight: 100,
        totalReadinessIncreaseWeight: 10,
        averageReadinessIncreaseWeight: 10,
        primaryRecipeWeight: 5,
        secondaryRecipeWeight: 2,
        ingredientFrequencyWeight: 3,
        pantrySynergyWeight: 7,
        impactedRecipeWeight: 1,
      ),
    );
    final evidence = RecommendationEvidence(
      impactedRecipeCount: 4,
      recipesUnlocked: 2,
      averageReadinessBefore: 0.5,
      averageReadinessAfter: 0.75,
      averageReadinessIncrease: 0.25,
      totalReadinessIncrease: 1,
      primaryRecipeCount: 2,
      secondaryRecipeCount: 2,
      ingredientFrequency: 4,
      hasPantrySynergy: true,
      reasonCodes: const <RecommendationReasonCode>[],
    );

    expect(calculator.calculate(evidence), 249.5);
    expect(calculator.calculate(evidence), calculator.calculate(evidence));
  });
}
