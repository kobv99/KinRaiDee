import '../entities/shopping_recommendation.dart';

class RecommendationScorePolicy {
  const RecommendationScorePolicy({
    this.unlockedRecipeWeight = 1000,
    this.totalReadinessIncreaseWeight = 200,
    this.averageReadinessIncreaseWeight = 100,
    this.primaryRecipeWeight = 40,
    this.secondaryRecipeWeight = 15,
    this.ingredientFrequencyWeight = 10,
    this.pantrySynergyWeight = 20,
    this.impactedRecipeWeight = 5,
  }) : assert(unlockedRecipeWeight >= 0),
       assert(totalReadinessIncreaseWeight >= 0),
       assert(averageReadinessIncreaseWeight >= 0),
       assert(primaryRecipeWeight >= 0),
       assert(secondaryRecipeWeight >= 0),
       assert(ingredientFrequencyWeight >= 0),
       assert(pantrySynergyWeight >= 0),
       assert(impactedRecipeWeight >= 0);

  final double unlockedRecipeWeight;
  final double totalReadinessIncreaseWeight;
  final double averageReadinessIncreaseWeight;
  final double primaryRecipeWeight;
  final double secondaryRecipeWeight;
  final double ingredientFrequencyWeight;
  final double pantrySynergyWeight;
  final double impactedRecipeWeight;
}

class RecommendationScoreCalculator {
  const RecommendationScoreCalculator({
    this.policy = const RecommendationScorePolicy(),
  });

  final RecommendationScorePolicy policy;

  double calculate(RecommendationEvidence evidence) {
    return (evidence.recipesUnlocked * policy.unlockedRecipeWeight) +
        (evidence.totalReadinessIncrease *
            policy.totalReadinessIncreaseWeight) +
        (evidence.averageReadinessIncrease *
            policy.averageReadinessIncreaseWeight) +
        (evidence.primaryRecipeCount * policy.primaryRecipeWeight) +
        (evidence.secondaryRecipeCount * policy.secondaryRecipeWeight) +
        (evidence.ingredientFrequency * policy.ingredientFrequencyWeight) +
        (evidence.hasPantrySynergy ? policy.pantrySynergyWeight : 0) +
        (evidence.impactedRecipeCount * policy.impactedRecipeWeight);
  }
}
