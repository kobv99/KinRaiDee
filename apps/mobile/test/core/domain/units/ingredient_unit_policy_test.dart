import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/units/ingredient_unit_policy.dart';

void main() {
  const policy = IngredientUnitPolicy();

  test('a nested species authored with whole_cleaned recommends whole', () {
    final result = policy.forDefinition(
      canonicalId: 'mackerel',
      category: 'seafood',
      defaultInventoryUnitId: 'gram',
      defaultPurchaseUnitId: 'kilogram',
      parentId: 'sea_fish_family',
      taxonomyType: IngredientTaxonomyType.species,
      ingredientForms: const <String>['whole_cleaned', 'butterflied'],
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

  test('a nested species without whole_cleaned in its authored forms remains '
      'mass-based, not assumed whole from taxonomyType+ancestry alone', () {
    final result = policy.forDefinition(
      canonicalId: 'salmon',
      category: 'seafood',
      defaultInventoryUnitId: 'gram',
      defaultPurchaseUnitId: 'kilogram',
      parentId: 'sea_fish_family',
      taxonomyType: IngredientTaxonomyType.species,
      // No ingredientForms authored — matches salmon's current content.
    );

    expect(result.preferredUnitId, isNot('whole'));
    expect(result.preferredUnitId, 'kilogram');
    expect(result.family, isNot(IngredientUnitFamily.fish));
  });

  test(
    'generic fish with no authored whole_cleaned form remains mass-based',
    () {
      final result = policy.forDefinition(
        canonicalId: 'fish',
        category: 'seafood',
        defaultInventoryUnitId: 'gram',
        defaultPurchaseUnitId: 'kilogram',
        parentId: 'fish_family',
        taxonomyType: IngredientTaxonomyType.generic,
        // Generic fish deliberately carries no ingredientForms — it must
        // never fabricate a form/texture assumption just to look "whole".
      );

      expect(result.preferredUnitId, isNot('whole'));
      expect(result.preferredUnitId, 'kilogram');
      expect(result.recommendedUnitIds, <String>['piece', 'gram', 'kilogram']);
      expect(result.family, isNot(IngredientUnitFamily.fish));
    },
  );

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

  test('a novel, never-seen species recommends whole via ancestry+taxonomyType+'
      'authored form, not a hardcoded id list', () {
    for (final parentId in <String>[
      'freshwater_fish_family',
      'sea_fish_family',
    ]) {
      final result = policy.forDefinition(
        canonicalId: 'a_new_species_never_seen_before',
        category: 'seafood',
        defaultInventoryUnitId: 'gram',
        defaultPurchaseUnitId: 'kilogram',
        parentId: parentId,
        taxonomyType: IngredientTaxonomyType.species,
        ingredientForms: const <String>['whole_cleaned'],
      );
      expect(result.preferredUnitId, 'whole');
      expect(result.family, IngredientUnitFamily.fish);
    }
  });

  test('fish_fillet is excluded from whole-animal treatment by taxonomyType '
      'even if whole_cleaned were (incorrectly) authored on it', () {
    final result = policy.forDefinition(
      canonicalId: 'fish_fillet',
      category: 'seafood',
      defaultInventoryUnitId: 'gram',
      defaultPurchaseUnitId: 'kilogram',
      parentId: 'fish_family',
      taxonomyType: IngredientTaxonomyType.form,
      ingredientForms: const <String>['whole_cleaned'],
    );
    expect(result.preferredUnitId, isNot('whole'));
    expect(result.preferredUnitId, 'kilogram');
    expect(result.family, isNot(IngredientUnitFamily.fish));
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
