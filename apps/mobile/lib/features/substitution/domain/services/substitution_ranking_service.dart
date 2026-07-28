import '../entities/ingredient_substitution.dart';
import 'ingredient_compatibility_calculator.dart';

class SubstitutionRankingService {
  const SubstitutionRankingService({
    this.calculator = const IngredientCompatibilityCalculator(),
  });

  final IngredientCompatibilityCalculator calculator;

  List<IngredientSubstitutionRecommendation> rank({
    required List<IngredientSubstitution> substitutions,
    required Set<String> pantryCanonicalIds,
  }) {
    final result = substitutions
        .map(
          (item) => IngredientSubstitutionRecommendation(
            substitution: item,
            isAvailableInPantry: pantryCanonicalIds.contains(
              item.substituteIngredientId,
            ),
            compatibilityScore: calculator.calculate(item),
            reason:
                '${item.notes} รสชาติ: ${item.flavorDifference} '
                'เนื้อสัมผัส: ${item.textureDifference} '
                'ข้อจำกัด: ${item.limitations}',
          ),
        )
        .toList();
    result.sort(_compare);
    return List.unmodifiable(result);
  }

  int _compare(
    IngredientSubstitutionRecommendation first,
    IngredientSubstitutionRecommendation second,
  ) {
    if (first.isAvailableInPantry != second.isAvailableInPantry) {
      return first.isAvailableInPantry ? -1 : 1;
    }
    final a = first.substitution;
    final b = second.substitution;
    for (final value in <int>[
      b.confidence.compareTo(a.confidence),
      b.flavorSimilarity.compareTo(a.flavorSimilarity),
      b.textureSimilarity.compareTo(a.textureSimilarity),
      b.cookingMethodCompatibility.compareTo(a.cookingMethodCompatibility),
    ]) {
      if (value != 0) return value;
    }
    return a.substituteIngredientId.compareTo(b.substituteIngredientId);
  }
}
