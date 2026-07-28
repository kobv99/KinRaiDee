import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/units/ingredient_unit_policy.dart';

void main() {
  const policy = IngredientUnitPolicy();

  test('fish recommends practical count and mass units only', () {
    final result = policy.forDefinition(
      canonicalId: 'fish',
      category: 'seafood',
      defaultInventoryUnitId: 'gram',
      defaultPurchaseUnitId: 'kilogram',
    );

    expect(result.preferredUnitId, 'whole');
    expect(result.recommendedUnitIds, <String>[
      'whole',
      'piece',
      'gram',
      'kilogram',
    ]);
    expect(result.recommendedUnitIds, isNot(contains('liter')));
    expect(result.recommendedUnitIds, isNot(contains('bottle')));
    expect(result.family, IngredientUnitFamily.fish);
  });

  test('cooking oil recommends liquid purchase units only', () {
    final result = policy.forDefinition(
      canonicalId: 'cooking_oil',
      category: 'seasoning',
      defaultInventoryUnitId: 'tablespoon',
      defaultPurchaseUnitId: 'liter',
    );

    expect(result.preferredUnitId, 'bottle');
    expect(result.recommendedUnitIds, <String>[
      'bottle',
      'milliliter',
      'liter',
    ]);
    expect(result.recommendedUnitIds, isNot(contains('piece')));
    expect(result.recommendedUnitIds, isNot(contains('whole')));
    expect(result.family, IngredientUnitFamily.liquid);
  });

  test('egg defaults to egg and keeps pack as the only alternative', () {
    final result = policy.forDefinition(
      canonicalId: 'egg',
      category: 'protein',
      defaultInventoryUnitId: 'egg',
      defaultPurchaseUnitId: 'egg',
    );

    expect(result.preferredUnitId, 'egg');
    expect(result.recommendedUnitIds, <String>['egg', 'pack']);
    expect(result.family, IngredientUnitFamily.egg);
  });
}
