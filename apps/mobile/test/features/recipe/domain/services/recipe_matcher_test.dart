import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/services/recipe_matcher.dart';

void main() {
  const matcher = RecipeMatcher();

  group('RecipeMatcher', () {
    test(
      'returns 100 percent when required and optional ingredients match',
      () {
        final result = matcher
            .match(
              recipes: [
                _recipe(
                  id: 'complete',
                  name: 'เมนูครบ',
                  ingredients: const [
                    RecipeIngredient(
                      id: 'pork',
                      name: 'หมูสับ',
                      quantity: 100,
                      unit: 'กรัม',
                    ),
                    RecipeIngredient(
                      id: 'chili',
                      name: 'พริก',
                      quantity: 1,
                      unit: 'เม็ด',
                      required: false,
                    ),
                  ],
                ),
              ],
              pantry: [_pantry('หมูสับ'), _pantry('พริก')],
            )
            .single;

        expect(result.scorePercent, 100);
        expect(result.canCook, isTrue);
        expect(result.missingIngredients, isEmpty);
      },
    );

    test('weights required ingredients more heavily than optional ones', () {
      final recipe = _recipe(
        id: 'weighted',
        name: 'เมนูถ่วงน้ำหนัก',
        ingredients: const [
          RecipeIngredient(
            id: 'required',
            name: 'หมู',
            quantity: 100,
            unit: 'กรัม',
          ),
          RecipeIngredient(
            id: 'optional',
            name: 'พริก',
            quantity: 1,
            unit: 'เม็ด',
            required: false,
          ),
        ],
      );

      final requiredOnly = matcher
          .match(recipes: [recipe], pantry: [_pantry('หมู')])
          .single;
      final optionalOnly = matcher
          .match(recipes: [recipe], pantry: [_pantry('พริก')])
          .single;

      expect(requiredOnly.scorePercent, 80);
      expect(requiredOnly.canCook, isTrue);
      expect(optionalOnly.scorePercent, 20);
      expect(optionalOnly.canCook, isFalse);
    });

    test('matches aliases and ignores unavailable pantry ingredients', () {
      final recipe = _recipe(
        id: 'alias',
        name: 'ไข่เจียว',
        ingredients: const [
          RecipeIngredient(
            id: 'egg',
            name: 'ไข่ไก่',
            quantity: 2,
            unit: 'ฟอง',
            aliases: ['ไข่'],
          ),
        ],
      );

      final aliasMatch = matcher
          .match(recipes: [recipe], pantry: [_pantry('ไข่')])
          .single;
      final zeroQuantity = matcher
          .match(recipes: [recipe], pantry: [_pantry('ไข่', quantity: 0)])
          .single;
      final expired = matcher
          .match(
            recipes: [recipe],
            pantry: [_pantry('ไข่', expiryDate: DateTime.utc(2020, 1, 1))],
          )
          .single;

      expect(aliasMatch.scorePercent, 100);
      expect(zeroQuantity.scorePercent, 0);
      expect(expired.scorePercent, 0);
    });

    test('sorts by score, missing required count, then recipe name', () {
      final results = matcher.match(
        recipes: [
          _recipe(
            id: 'low',
            name: 'ค เมนูคะแนนต่ำ',
            ingredients: const [
              RecipeIngredient(id: 'pork', name: 'หมู', quantity: 1, unit: '份'),
              RecipeIngredient(
                id: 'egg',
                name: 'ไข่',
                quantity: 1,
                unit: 'ฟอง',
              ),
            ],
          ),
          _recipe(
            id: 'b',
            name: 'ข เมนูคะแนนเต็ม',
            ingredients: const [
              RecipeIngredient(id: 'pork', name: 'หมู', quantity: 1, unit: '份'),
            ],
          ),
          _recipe(
            id: 'a',
            name: 'ก เมนูคะแนนเต็ม',
            ingredients: const [
              RecipeIngredient(id: 'pork', name: 'หมู', quantity: 1, unit: '份'),
            ],
          ),
        ],
        pantry: [_pantry('หมู')],
      );

      expect(
        results.map((item) => item.recipe.id),
        orderedEquals(['a', 'b', 'low']),
      );
    });
  });
}

Recipe _recipe({
  required String id,
  required String name,
  required List<RecipeIngredient> ingredients,
}) {
  return Recipe(
    id: id,
    name: name,
    category: 'ทดสอบ',
    ingredients: ingredients,
    steps: const ['ปรุงให้สุก'],
  );
}

Ingredient _pantry(String name, {double quantity = 1, DateTime? expiryDate}) {
  final now = DateTime(2026, 1, 1);
  return Ingredient(
    id: name,
    name: name,
    category: 'ทดสอบ',
    emoji: '🥣',
    quantity: quantity,
    unit: 'ชิ้น',
    expiryDate: expiryDate,
    createdAt: now,
    updatedAt: now,
  );
}
