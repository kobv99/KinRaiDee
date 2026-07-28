import '../entities/shopping_recommendation.dart';

class RecommendationExplanationPolicy {
  const RecommendationExplanationPolicy({
    this.highRecipeFrequencyThreshold = 3,
    this.nearlyReadyThreshold = 0.7,
  }) : assert(highRecipeFrequencyThreshold > 0),
       assert(nearlyReadyThreshold >= 0 && nearlyReadyThreshold <= 1);

  final int highRecipeFrequencyThreshold;
  final double nearlyReadyThreshold;
}

class RecommendationExplanation {
  RecommendationExplanation({
    required List<ShoppingRecommendationType> types,
    required this.reason,
  }) : types = List<ShoppingRecommendationType>.unmodifiable(types);

  final List<ShoppingRecommendationType> types;
  final String reason;
}

class RecommendationExplanationBuilder {
  const RecommendationExplanationBuilder({
    this.policy = const RecommendationExplanationPolicy(),
  });

  final RecommendationExplanationPolicy policy;

  RecommendationExplanation build({
    required String ingredientName,
    required RecommendationEvidence evidence,
    required List<RecommendationRecipeImpact> impacts,
  }) {
    final types = <ShoppingRecommendationType>[];
    if (evidence.recipesUnlocked > 0) {
      types.add(ShoppingRecommendationType.unlockMostRecipes);
    }
    if (evidence.averageReadinessIncrease > 0) {
      types.add(ShoppingRecommendationType.improveRecipeReadiness);
    }
    if (evidence.almostReadyRecipeCount > 0) {
      types.add(ShoppingRecommendationType.completeAlmostReadyRecipes);
    }
    if (evidence.ingredientFrequency >= policy.highRecipeFrequencyThreshold) {
      types.add(ShoppingRecommendationType.frequentlyUsedIngredient);
    }

    final facts = <String>[];
    if (evidence.recipesUnlocked > 0) {
      facts.add('ทำให้พร้อมทำเพิ่ม ${evidence.recipesUnlocked} เมนู');
    }
    if (evidence.averageReadinessIncreasePercent > 0) {
      facts.add(
        'เพิ่มความพร้อมเฉลี่ย ${evidence.averageReadinessIncreasePercent}%',
      );
    }
    if (evidence.almostReadyRecipeCount > 0) {
      facts.add(
        'ช่วยเติมเต็มเมนูที่เกือบพร้อม ${evidence.almostReadyRecipeCount} เมนู',
      );
    }
    if (evidence.ingredientFrequency >= policy.highRecipeFrequencyThreshold) {
      facts.add('ใช้ใน ${evidence.ingredientFrequency} เมนู');
    }
    if (evidence.hasPantrySynergy) {
      facts.add('เข้ากับวัตถุดิบที่มีใน Pantry');
    }
    if (facts.isEmpty && impacts.isNotEmpty) {
      facts.add('ช่วยเพิ่มความพร้อมของ ${impacts.length} เมนู');
    }

    return RecommendationExplanation(
      types: types,
      reason: facts.isEmpty
          ? '$ingredientName ช่วยเพิ่มทางเลือกในการทำอาหาร'
          : '$ingredientName: ${facts.join(' • ')}',
    );
  }
}
