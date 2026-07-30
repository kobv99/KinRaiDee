import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/substitution/domain/entities/ingredient_substitution.dart';
import 'package:mobile/features/substitution/domain/services/substitution_ranking_service.dart';

void main() {
  test('ranks Pantry availability first then deterministic evidence', () {
    final result = const SubstitutionRankingService().rank(
      substitutions: [
        _record('high', 'high', confidence: 0.95),
        _record('pantry', 'pantry', confidence: 0.7),
        _record('tie-b', 'z', confidence: 0.6),
        _record('tie-a', 'a', confidence: 0.6),
      ],
      pantryCanonicalIds: {'pantry'},
    );

    expect(result.map((item) => item.substitution.substituteIngredientId), [
      'pantry',
      'high',
      'a',
      'z',
    ]);
    expect(result.first.isAvailableInPantry, isTrue);
    expect(result.first.reason, contains('ข้อจำกัด'));
  });
}

IngredientSubstitution _record(
  String id,
  String substitute, {
  required double confidence,
}) {
  return IngredientSubstitution(
    id: id,
    originalIngredientId: 'original',
    substituteIngredientId: substitute,
    confidence: confidence,
    flavorSimilarity: 0.5,
    textureSimilarity: 0.5,
    cookingMethodCompatibility: 0.5,
    suitableDishes: const ['ผัด'],
    unsuitableDishes: const ['อบ'],
    category: 'test',
    notes: 'เหตุผล',
    flavorDifference: 'รสต่าง',
    textureDifference: 'เนื้อสัมผัสต่าง',
    limitations: 'ข้อจำกัด',
  );
}
