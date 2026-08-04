import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';
import 'package:mobile/features/recipe/data/datasources/local_recipe_datasource.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ingredient', () {
    test('matches canonical name and aliases', () {
      final registry = CanonicalIngredientRegistry(
        ingredients: <CanonicalIngredient>[
          CanonicalIngredient(
            id: 'squid',
            canonicalName: 'Squid',
            localizedNames: const <String, String>{'th': 'ปลาหมึก'},
            aliases: const <String>['หมึก', 'ปลาหมึกสด'],
            searchKeywords: const <String>[],
            category: 'seafood',
            defaultStorageType: IngredientStorageType.refrigerated,
            defaultPurchaseUnitId: 'kilogram',
            defaultInventoryUnitId: 'gram',
          ),
        ],
      );

      expect(registry.resolve('ปลาหมึก').ingredient?.id, 'squid');
      expect(registry.resolve('  หมึก  ').ingredient?.id, 'squid');
      expect(registry.resolve('กุ้ง').isResolved, isFalse);
    });
  });

  group('IngredientCatalog', () {
    test('loads master data and resolves an alias', () async {
      final bundle = _MemoryAssetBundle(
        jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'squid',
            'name': 'ปลาหมึก',
            'category': 'seafood',
            'defaultUnit': 'กรัม',
            'aliases': <String>['หมึกกล้วย'],
            'ingredientForms': <String>['whole_cleaned', 'sliced'],
            'textures': <String>['tender'],
            'supportedCookingMethods': <String>['ย่าง', 'ผัด'],
          },
        ]),
      );
      final catalog = IngredientCatalog(bundle: bundle);

      final ingredients = await catalog.load();
      final result = catalog.findByName(ingredients, 'หมึกกล้วย');

      expect(ingredients, hasLength(1));
      expect(result?.id, 'squid');
      expect(result?.ingredientForms, <String>['whole_cleaned', 'sliced']);
      expect(result?.textures, <String>['tender']);
      expect(result?.supportedCookingMethods, <String>['ย่าง', 'ผัด']);
    });

    test(
      'bundled registry is unique and covers every recipe identity',
      () async {
        final catalog = IngredientCatalog();
        final definitions = await catalog.load();
        final registry = await catalog.loadRegistry();
        final recipes = await const LocalRecipeDataSource().loadRecipes();
        final unitEngine = UnitConversionEngine.standard();
        final ids = definitions.map((ingredient) => ingredient.id).toList();

        expect(ids.toSet(), hasLength(ids.length));
        for (final definition in definitions) {
          expect(definition.canonicalName, isNotEmpty);
          expect(definition.emoji, isNotEmpty);
          expect(definition.defaultPurchaseUnitId, isNotEmpty);
          expect(definition.defaultInventoryUnitId, isNotEmpty);
          expect(definition.preferredUnitId, isNotEmpty);
          expect(definition.recommendedUnitIds, isNotEmpty);
          expect(
            definition.recommendedUnitIds,
            contains(definition.preferredUnitId),
          );
          expect(
            definition.recommendedUnitIds.every(
              (unitId) => unitEngine.resolveUnit(unitId) != null,
            ),
            isTrue,
          );
          expect(definition.unitFamily, isNotNull);
          expect(definition.metadata.schemaVersion, greaterThan(0));
          expect(definition.metadata.revision, greaterThan(0));
        }
        for (final recipe in recipes) {
          for (final ingredient in recipe.ingredients) {
            expect(
              registry.byId(ingredient.canonicalIngredientId),
              isNotNull,
              reason:
                  '${recipe.id}/${ingredient.canonicalIngredientId} '
                  'must exist in the canonical registry',
            );
          }
        }
        expect(registry.byId('fish')?.preferredUnitId, 'whole');
        expect(registry.byId('fish')?.canSelectAsMainIngredient, isFalse);
        expect(registry.byId('mackerel')?.canSelectAsMainIngredient, isTrue);
        expect(
          registry.byId('mackerel')?.ingredientForms,
          contains('whole_cleaned'),
        );
        expect(registry.canonicalIdFor('chicken_breast'), 'chicken_breast');
        expect(registry.byId('pork')?.preferredUnitId, 'kilogram');
        expect(registry.byId('egg')?.preferredUnitId, 'egg');
        expect(registry.byId('cooking_oil')?.preferredUnitId, 'bottle');
        expect(registry.byId('tofu')?.preferredUnitId, 'block');
      },
    );
  });

  group('IngredientCatalog taxonomyType/defaultPantryQuantity parsing', () {
    Map<String, dynamic> entry(
      String id, {
      Object? taxonomyType,
      Object? defaultPantryQuantity,
    }) {
      final json = <String, dynamic>{
        'id': id,
        'name': id,
        'category': 'protein',
        'defaultUnit': 'กรัม',
      };
      if (taxonomyType != null) {
        json['taxonomyType'] = taxonomyType;
      }
      if (defaultPantryQuantity != null) {
        json['defaultPantryQuantity'] = defaultPantryQuantity;
      }
      return json;
    }

    test('parses all seven IngredientTaxonomyType enum values', () async {
      final bundle = _MemoryAssetBundle(
        jsonEncode(<Map<String, dynamic>>[
          entry('t_generic', taxonomyType: 'generic'),
          entry('t_whole', taxonomyType: 'whole'),
          entry('t_species', taxonomyType: 'species'),
          entry('t_cut', taxonomyType: 'cut'),
          entry('t_organ', taxonomyType: 'organ'),
          entry('t_form', taxonomyType: 'form'),
          entry('t_product', taxonomyType: 'product'),
        ]),
      );
      final ingredients = await IngredientCatalog(bundle: bundle).load();
      final byId = {for (final i in ingredients) i.id: i};

      expect(byId['t_generic']?.taxonomyType, IngredientTaxonomyType.generic);
      expect(byId['t_whole']?.taxonomyType, IngredientTaxonomyType.whole);
      expect(byId['t_species']?.taxonomyType, IngredientTaxonomyType.species);
      expect(byId['t_cut']?.taxonomyType, IngredientTaxonomyType.cut);
      expect(byId['t_organ']?.taxonomyType, IngredientTaxonomyType.organ);
      expect(byId['t_form']?.taxonomyType, IngredientTaxonomyType.form);
      expect(byId['t_product']?.taxonomyType, IngredientTaxonomyType.product);
    });

    test('leaves taxonomyType and defaultPantryQuantity null for legacy '
        'definitions that omit both fields', () async {
      final bundle = _MemoryAssetBundle(
        jsonEncode(<Map<String, dynamic>>[entry('legacy_item')]),
      );
      final ingredients = await IngredientCatalog(bundle: bundle).load();

      expect(ingredients.single.taxonomyType, isNull);
      expect(ingredients.single.defaultPantryQuantity, isNull);
    });

    test(
      'preserves decimal defaultPantryQuantity values such as 0.5',
      () async {
        final bundle = _MemoryAssetBundle(
          jsonEncode(<Map<String, dynamic>>[
            entry('half_unit', defaultPantryQuantity: 0.5),
          ]),
        );
        final ingredients = await IngredientCatalog(bundle: bundle).load();

        expect(ingredients.single.defaultPantryQuantity, 0.5);
      },
    );

    test('throws clearly on an unrecognized taxonomyType instead of '
        'inferring one from parentId', () async {
      final bundle = _MemoryAssetBundle(
        jsonEncode(<Map<String, dynamic>>[
          entry('bad_type', taxonomyType: 'not_a_real_type'),
        ]),
      );
      final catalog = IngredientCatalog(bundle: bundle);

      expect(catalog.load(), throwsA(isA<FormatException>()));
    });
  });

  group('Recipe metadata', () {
    test('parses new fields while remaining backward compatible', () {
      final recipe = Recipe.fromJson(const <String, dynamic>{
        'version': 1,
        'id': 'squid_garlic',
        'name': 'ปลาหมึกผัดกระเทียม',
        'category': 'อาหารไทย',
        'difficulty': 'easy',
        'cookTime': 15,
        'servings': 2,
        'tags': <String>['ปลาหมึก', 'อาหารไทย'],
        'cookingMethod': 'ผัด',
        'heroIngredientId': 'squid',
        'heroIngredientName': 'ปลาหมึก',
        'popularity': 90,
        'ingredients': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'squid',
            'name': 'ปลาหมึก',
            'quantity': 200,
            'unit': 'กรัม',
          },
        ],
        'steps': <String>['ผัดให้สุก'],
      });

      expect(recipe.version, 1);
      expect(recipe.cookTimeMinutes, 15);
      expect(recipe.servings, 2);
      expect(recipe.tags, contains('ปลาหมึก'));
      expect(recipe.cookingMethods, <String>['ผัด']);
      expect(recipe.resolvedHeroIngredientId, 'squid');
      expect(recipe.resolvedHeroIngredientName, 'ปลาหมึก');
      expect(recipe.popularity, 90);
    });
  });
}

class _MemoryAssetBundle extends CachingAssetBundle {
  _MemoryAssetBundle(this.source);

  final String source;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(source));
    return ByteData.view(bytes.buffer);
  }
}
