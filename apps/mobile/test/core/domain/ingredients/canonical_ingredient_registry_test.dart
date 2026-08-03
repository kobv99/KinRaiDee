import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/images/image_metadata.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';

void main() {
  group('CanonicalIngredientRegistry', () {
    test('keeps generic chicken and chicken breast as distinct identities', () {
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

      expect(registry.resolve('Chicken').ingredient?.id, 'chicken');
      for (final value in <String>[
        'Chicken Breast',
        'Chicken breast',
        'Boneless Chicken Breast',
        'อกไก่',
      ]) {
        expect(registry.resolve(value).ingredient?.id, 'chicken_breast');
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
      expect(registry.ancestorIdsFor('pork_neck'), <String>{'pork'});
      expect(registry.ancestorIdsFor('unknown'), isEmpty);
      expect(registry.resolve('dragon fruit peel').isResolved, isFalse);
      final first = registry.unmappedIdFor(' Dragon   Fruit Peel ');
      final second = registry.unmappedIdFor('dragon fruit peel');
      expect(first, second);
      expect(first, 'unmapped_43a6cdcd93150f86');
      expect(first, matches(RegExp(r'^unmapped_[0-9a-f]{16}$')));
    });

    test('alias resolution surfaces the canonical ingredient image', () {
      final image = ImageMetadata(
        locationType: ImageLocationType.network,
        remoteUrl: 'https://example.com/mackerel.png',
        reviewStatus: ImageReviewStatus.approved,
      );
      final registry = CanonicalIngredientRegistry(
        ingredients: <CanonicalIngredient>[
          _ingredient(
            'mackerel',
            aliases: const <String>['ปลาทู'],
            image: image,
          ),
          _ingredient('fish', nodeType: CanonicalIngredientNodeType.family),
        ],
      );

      final byAlias = registry.resolve('ปลาทู').ingredient;
      final byId = registry.byId('mackerel');

      expect(byAlias?.image, same(image));
      expect(byId?.image, same(image));
      // Aliasing never fabricates or borrows imagery from a sibling
      // ingredient or a family/category node.
      expect(registry.byId('fish')?.image, isNull);
    });
  });
}

CanonicalIngredient _ingredient(
  String id, {
  String? canonicalName,
  String? thaiName,
  List<String> aliases = const <String>[],
  String? parentId,
  CanonicalIngredientNodeType nodeType = CanonicalIngredientNodeType.ingredient,
  ImageMetadata? image,
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
    nodeType: nodeType,
    image: image,
  );
}
