import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';

void main() {
  group('CanonicalIngredient taxonomyType invariant', () {
    test('throws when a family node carries a taxonomyType', () {
      expect(
        () => _ingredient(
          'pork_family',
          nodeType: CanonicalIngredientNodeType.family,
          taxonomyType: IngredientTaxonomyType.generic,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when a category node carries a taxonomyType', () {
      expect(
        () => _ingredient(
          'protein_category',
          nodeType: CanonicalIngredientNodeType.category,
          taxonomyType: IngredientTaxonomyType.generic,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('allows an ingredient node to carry a taxonomyType', () {
      final pork = _ingredient(
        'pork',
        taxonomyType: IngredientTaxonomyType.generic,
      );
      expect(pork.taxonomyType, IngredientTaxonomyType.generic);
    });

    test(
      'allows an ingredient node with no taxonomyType (unmigrated content)',
      () {
        final legacy = _ingredient('legacy_item');
        expect(legacy.taxonomyType, isNull);
      },
    );

    test('allows a family node with null taxonomyType', () {
      final family = _ingredient(
        'pork_family',
        nodeType: CanonicalIngredientNodeType.family,
        selectableAsMainIngredient: false,
      );
      expect(family.taxonomyType, isNull);
    });
  });

  group(
    'CanonicalIngredientRegistry excludes family/category from resolution',
    () {
      test(
        'resolve("หมู") finds the selectable generic, not the family node',
        () {
          final registry = CanonicalIngredientRegistry(
            ingredients: <CanonicalIngredient>[
              _ingredient(
                'pork_family',
                nodeType: CanonicalIngredientNodeType.family,
                selectableAsMainIngredient: false,
                canonicalName: 'Pork Family',
                thaiName: 'หมู',
              ),
              _ingredient(
                'pork',
                parentId: 'pork_family',
                taxonomyType: IngredientTaxonomyType.generic,
                canonicalName: 'Pork',
                thaiName: 'หมู',
                aliases: const <String>['หมูชิ้น'],
              ),
            ],
          );

          final resolution = registry.resolve('หมู');
          expect(resolution.isResolved, isTrue);
          expect(resolution.ingredient?.id, 'pork');
        },
      );

      test(
        'pork_family remains reachable via byId and hierarchy traversal',
        () {
          final registry = CanonicalIngredientRegistry(
            ingredients: <CanonicalIngredient>[
              _ingredient(
                'pork_family',
                nodeType: CanonicalIngredientNodeType.family,
                selectableAsMainIngredient: false,
              ),
              _ingredient(
                'pork',
                parentId: 'pork_family',
                taxonomyType: IngredientTaxonomyType.generic,
              ),
            ],
          );

          expect(registry.byId('pork_family')?.id, 'pork_family');
          expect(registry.ancestorIdsFor('pork'), <String>{'pork_family'});
          expect(registry.ancestorChainFor('pork'), <String>['pork_family']);
        },
      );

      test(
        'family nodes never appear as a resolve() match, even by exact id',
        () {
          final registry = CanonicalIngredientRegistry(
            ingredients: <CanonicalIngredient>[
              _ingredient(
                'pork_family',
                nodeType: CanonicalIngredientNodeType.family,
                selectableAsMainIngredient: false,
              ),
            ],
          );

          expect(registry.resolve('pork_family').isResolved, isFalse);
        },
      );

      test('category nodes are excluded the same way as family nodes', () {
        final registry = CanonicalIngredientRegistry(
          ingredients: <CanonicalIngredient>[
            _ingredient(
              'protein_category',
              nodeType: CanonicalIngredientNodeType.category,
              selectableAsMainIngredient: false,
              canonicalName: 'Protein',
              thaiName: 'โปรตีน',
            ),
            _ingredient(
              'pork',
              canonicalName: 'Pork',
              thaiName: 'หมู',
              taxonomyType: IngredientTaxonomyType.generic,
            ),
          ],
        );

        expect(registry.resolve('โปรตีน').isResolved, isFalse);
        expect(registry.resolve('หมู').ingredient?.id, 'pork');
      });

      test('resolve() with a preferredId pointing at a family node falls back '
          'instead of returning the family node', () {
        final registry = CanonicalIngredientRegistry(
          ingredients: <CanonicalIngredient>[
            _ingredient(
              'pork_family',
              nodeType: CanonicalIngredientNodeType.family,
              selectableAsMainIngredient: false,
            ),
            _ingredient(
              'pork',
              parentId: 'pork_family',
              taxonomyType: IngredientTaxonomyType.generic,
              canonicalName: 'Pork',
              thaiName: 'หมู',
            ),
          ],
        );

        final resolution = registry.resolve('หมู', preferredId: 'pork_family');
        expect(resolution.ingredient?.id, 'pork');
      });
    },
  );

  group('duplicate display names between family and generic', () {
    test('do not create an ambiguous match', () {
      final registry = CanonicalIngredientRegistry(
        ingredients: <CanonicalIngredient>[
          // Family and its generic child intentionally share the exact
          // same Thai display name, mirroring "หมู" used for both
          // pork_family (navigation) and pork (the selectable generic).
          _ingredient(
            'chicken_family',
            nodeType: CanonicalIngredientNodeType.family,
            selectableAsMainIngredient: false,
            canonicalName: 'Chicken Family',
            thaiName: 'ไก่',
          ),
          _ingredient(
            'chicken',
            parentId: 'chicken_family',
            taxonomyType: IngredientTaxonomyType.generic,
            canonicalName: 'Chicken',
            thaiName: 'ไก่',
          ),
        ],
      );

      final resolution = registry.resolve('ไก่');
      expect(resolution.matchType, isNot(CanonicalMatchType.ambiguous));
      expect(resolution.ingredient?.id, 'chicken');
    });
  });

  group('ancestorChainFor', () {
    test('returns a root-first chain across multiple nesting levels', () {
      final registry = CanonicalIngredientRegistry(
        ingredients: <CanonicalIngredient>[
          _ingredient(
            'fish_family',
            nodeType: CanonicalIngredientNodeType.family,
            selectableAsMainIngredient: false,
          ),
          _ingredient(
            'sea_fish_family',
            nodeType: CanonicalIngredientNodeType.family,
            selectableAsMainIngredient: false,
            parentId: 'fish_family',
          ),
          _ingredient(
            'mackerel',
            parentId: 'sea_fish_family',
            taxonomyType: IngredientTaxonomyType.species,
          ),
        ],
      );

      expect(registry.ancestorChainFor('mackerel'), <String>[
        'fish_family',
        'sea_fish_family',
      ]);
    });

    test('returns an empty chain for a root node', () {
      final registry = CanonicalIngredientRegistry(
        ingredients: <CanonicalIngredient>[_ingredient('shrimp')],
      );
      expect(registry.ancestorChainFor('shrimp'), isEmpty);
    });

    test('returns an empty chain for an unknown id', () {
      final registry = CanonicalIngredientRegistry(
        ingredients: <CanonicalIngredient>[_ingredient('shrimp')],
      );
      expect(registry.ancestorChainFor('unknown'), isEmpty);
    });
  });

  group('parent cycle validation', () {
    test('rejects a direct two-node cycle at construction', () {
      expect(
        () => CanonicalIngredientRegistry(
          ingredients: <CanonicalIngredient>[
            _ingredient('a', parentId: 'b'),
            _ingredient('b', parentId: 'a'),
          ],
        ),
        throwsA(
          isA<CanonicalRegistryException>().having(
            (error) => error.code,
            'code',
            'circular_ingredient_parent',
          ),
        ),
      );
    });

    test('rejects a deeper three-node cycle at construction', () {
      expect(
        () => CanonicalIngredientRegistry(
          ingredients: <CanonicalIngredient>[
            _ingredient('a', parentId: 'b'),
            _ingredient('b', parentId: 'c'),
            _ingredient('c', parentId: 'a'),
          ],
        ),
        throwsA(
          isA<CanonicalRegistryException>().having(
            (error) => error.code,
            'code',
            'circular_ingredient_parent',
          ),
        ),
      );
    });

    test('a valid deep (acyclic) hierarchy still constructs normally', () {
      final registry = CanonicalIngredientRegistry(
        ingredients: <CanonicalIngredient>[
          _ingredient(
            'fish_family',
            nodeType: CanonicalIngredientNodeType.family,
            selectableAsMainIngredient: false,
          ),
          _ingredient(
            'sea_fish_family',
            nodeType: CanonicalIngredientNodeType.family,
            selectableAsMainIngredient: false,
            parentId: 'fish_family',
          ),
          _ingredient(
            'mackerel',
            parentId: 'sea_fish_family',
            taxonomyType: IngredientTaxonomyType.species,
          ),
        ],
      );

      expect(registry.ancestorChainFor('mackerel'), <String>[
        'fish_family',
        'sea_fish_family',
      ]);
    });

    test('missing-parent behavior is unchanged', () {
      expect(
        () => CanonicalIngredientRegistry(
          ingredients: <CanonicalIngredient>[
            _ingredient('pork_neck', parentId: 'does_not_exist'),
          ],
        ),
        throwsA(
          isA<CanonicalRegistryException>().having(
            (error) => error.code,
            'code',
            'missing_parent_ingredient',
          ),
        ),
      );
    });

    test('traversal-time guards in ancestorChainFor/ancestorIdsFor remain as '
        'defensive protection even though construction now rejects cycles', () {
      final registry = CanonicalIngredientRegistry(
        ingredients: <CanonicalIngredient>[_ingredient('shrimp')],
      );
      expect(() => registry.ancestorChainFor('shrimp'), returnsNormally);
      expect(() => registry.ancestorIdsFor('shrimp'), returnsNormally);
    });
  });

  group('defaultPantryQuantity', () {
    test('accepts decimal values without truncation', () {
      final ingredient = _ingredient('garlic', defaultPantryQuantity: 1.5);
      expect(ingredient.defaultPantryQuantity, 1.5);
    });

    test('defaults to null when not provided', () {
      final ingredient = _ingredient('garlic');
      expect(ingredient.defaultPantryQuantity, isNull);
    });
  });

  group('defaultPantryUnitId', () {
    test('is computed from preferredUnitId', () {
      final ingredient = CanonicalIngredient(
        id: 'garlic',
        canonicalName: 'Garlic',
        localizedNames: const <String, String>{'th': 'กระเทียม'},
        aliases: const <String>[],
        searchKeywords: const <String>[],
        category: 'herb',
        defaultStorageType: IngredientStorageType.refrigerated,
        defaultPurchaseUnitId: 'kilogram',
        defaultInventoryUnitId: 'gram',
        preferredUnitId: 'clove',
        recommendedUnitIds: const <String>['clove', 'kilogram'],
      );
      expect(ingredient.defaultPantryUnitId, 'clove');
      expect(ingredient.defaultPantryUnitId, ingredient.preferredUnitId);
    });
  });

  group('existing behavior unchanged when new fields are absent', () {
    test('an ingredient built without taxonomyType/defaultPantryQuantity '
        'behaves exactly as before', () {
      final registry = CanonicalIngredientRegistry(
        ingredients: <CanonicalIngredient>[
          _ingredient(
            'squid',
            canonicalName: 'Squid',
            thaiName: 'ปลาหมึก',
            aliases: const <String>['หมึก'],
          ),
        ],
      );

      final squid = registry.byId('squid')!;
      expect(squid.taxonomyType, isNull);
      expect(squid.defaultPantryQuantity, isNull);
      expect(squid.defaultPantryUnitId, squid.preferredUnitId);
      expect(squid.canSelectAsMainIngredient, isTrue);
      expect(registry.resolve('ปลาหมึก').ingredient?.id, 'squid');
      expect(registry.resolve('หมึก').ingredient?.id, 'squid');
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
  IngredientTaxonomyType? taxonomyType,
  bool selectableAsMainIngredient = true,
  double? defaultPantryQuantity,
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
    taxonomyType: taxonomyType,
    selectableAsMainIngredient: selectableAsMainIngredient,
    defaultPantryQuantity: defaultPantryQuantity,
  );
}
