import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';
import 'package:mobile/features/recipe/domain/entities/ingredient.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';

void main() {
  group('Ingredient', () {
    test('matches canonical name and aliases', () {
      final ingredient = Ingredient.fromJson(const <String, dynamic>{
        'id': 'squid',
        'name': 'ปลาหมึก',
        'category': 'seafood',
        'aliases': <String>['หมึก', 'ปลาหมึกสด'],
      });

      expect(ingredient.matches('ปลาหมึก'), isTrue);
      expect(ingredient.matches('  หมึก  '), isTrue);
      expect(ingredient.matches('กุ้ง'), isFalse);
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
            'aliases': <String>['หมึกกล้วย'],
          },
        ]),
      );
      final catalog = IngredientCatalog(bundle: bundle);

      final ingredients = await catalog.load();
      final result = catalog.findByName(ingredients, 'หมึกกล้วย');

      expect(ingredients, hasLength(1));
      expect(result?.id, 'squid');
    });
  });

  group('Recipe metadata', () {
    test('parses new fields while remaining backward compatible', () {
      final recipe = Recipe.fromJson(const <String, dynamic>{
        'id': 'squid_garlic',
        'name': 'ปลาหมึกผัดกระเทียม',
        'category': 'อาหารไทย',
        'difficulty': 'easy',
        'cookTime': 15,
        'servings': 2,
        'tags': <String>['ปลาหมึก', 'อาหารไทย'],
        'cookingMethod': 'ผัด',
        'ingredients': <Map<String, dynamic>>[],
        'steps': <String>['ผัดให้สุก'],
      });

      expect(recipe.cookTimeMinutes, 15);
      expect(recipe.servings, 2);
      expect(recipe.tags, contains('ปลาหมึก'));
      expect(recipe.cookingMethods, <String>['ผัด']);
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
