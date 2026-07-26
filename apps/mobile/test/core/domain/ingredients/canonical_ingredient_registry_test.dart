import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';

void main() {
  group('CanonicalIngredientRegistry', () {
    test('normalizes chicken aliases and localized names to one identity', () {
      final registry = CanonicalIngredientRegistry(
        ingredients: <CanonicalIngredient>[
          _ingredient('chicken', canonicalName: 'Chicken', thaiName: 'ไก่'),
          _ingredient(
            'chicken_breast',
            canonicalName: 'Chicken breast',
            thaiName: 'อกไก่',
          ),
        ],
        redirects: defaultCanonicalIngredientRedirects,
      );

      for (final value in <String>[
        'Chicken Breast',
        'Chicken breast',
        'Chicken',
        'Boneless Chicken Breast',
        'อกไก่',
      ]) {
        expect(registry.resolve(value).ingredient?.id, 'chicken');
      }
    });

    test('forbids duplicate IDs and reports ambiguous aliases', () {
      expect(
        () => CanonicalIngredientRegistry(
          ingredients: <CanonicalIngredient>[
            _ingredient('egg'),
            _ingredient('egg'),
          ],
        ),
        throwsA(
          isA<CanonicalRegistryException>().having(
            (error) => error.code,
            'code',
            'duplicate_ingredient_id',
          ),
        ),
      );

      final registry = CanonicalIngredientRegistry(
        ingredients: <CanonicalIngredient>[
          _ingredient('a', aliases: const <String>['shared']),
          _ingredient('b', aliases: const <String>['shared']),
        ],
      );
      final result = registry.resolve('shared');
      expect(result.matchType, CanonicalMatchType.ambiguous);
      expect(result.candidateIds, <String>['a', 'b']);
    });

    test('supports family compatibility and deterministic unknown IDs', () {
      final registry = CanonicalIngredientRegistry(
        ingredients: <CanonicalIngredient>[
          _ingredient('pork'),
          _ingredient('pork_neck', parentId: 'pork'),
        ],
      );

      expect(registry.areCompatibleIds('pork', 'pork_neck'), isTrue);
      expect(registry.resolve('dragon fruit peel').isResolved, isFalse);
      final first = registry.unmappedIdFor(' Dragon   Fruit Peel ');
      final second = registry.unmappedIdFor('dragon fruit peel');
      expect(first, second);
      expect(first, matches(RegExp(r'^unmapped_[0-9a-f]{16}$')));
    });
  });
}

CanonicalIngredient _ingredient(
  String id, {
  String? canonicalName,
  String? thaiName,
  List<String> aliases = const <String>[],
  String? parentId,
}) {
  return CanonicalIngredient(
    id: id,
    canonicalName: canonicalName ?? id,
    localizedNames: thaiName == null
        ? const <String, String>{}
        : <String, String>{'th': thaiName},
    aliases: aliases,
    searchKeywords: const <String>[],
    category: 'test',
    defaultStorageType: IngredientStorageType.refrigerated,
    defaultPurchaseUnitId: 'kilogram',
    defaultInventoryUnitId: 'gram',
    parentId: parentId,
  );
}
