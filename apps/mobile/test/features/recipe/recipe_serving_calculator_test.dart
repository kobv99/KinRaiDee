import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart' as pantry_model;
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/services/recipe_serving_calculator.dart';

void main() {
  group('RecipeServingCalculator', () {
    test('scales every ingredient from the recipe base servings', () {
      final plan = const RecipeServingCalculator().calculate(
        recipe: _shrimpRecipe(),
        pantry: const <pantry_model.Ingredient>[],
        servings: 4,
      );

      expect(plan.scaleFactor, 2);
      expect(plan.servings, 4);
      expect(plan.ingredients[0].requiredQuantity, 400);
      expect(plan.ingredients[1].requiredQuantity, 8);
    });

    test('converts kilograms in pantry to recipe grams', () {
      final plan = const RecipeServingCalculator().calculate(
        recipe: _shrimpRecipe(),
        pantry: <pantry_model.Ingredient>[
          _pantryIngredient(
            id: 'shrimp',
            name: 'กุ้งขาว',
            quantity: 1,
            unit: 'กิโลกรัม',
          ),
          _pantryIngredient(
            id: 'garlic',
            name: 'กระเทียม',
            quantity: 20,
            unit: 'กลีบ',
          ),
        ],
        servings: 4,
      );

      final shrimp = plan.ingredients.first;
      final garlic = plan.ingredients.last;

      expect(shrimp.status, PantryQuantityStatus.enough);
      expect(shrimp.pantryQuantityInRecipeUnit, 1000);
      expect(garlic.status, PantryQuantityStatus.enough);
      expect(plan.hasEnoughRequiredIngredients, isTrue);
    });

    test('reports the exact shortage after scaling', () {
      final plan = const RecipeServingCalculator().calculate(
        recipe: _shrimpRecipe(),
        pantry: <pantry_model.Ingredient>[
          _pantryIngredient(
            id: 'shrimp',
            name: 'กุ้ง',
            quantity: 250,
            unit: 'กรัม',
          ),
          _pantryIngredient(
            id: 'garlic',
            name: 'กระเทียม',
            quantity: 8,
            unit: 'กลีบ',
          ),
        ],
        servings: 4,
      );

      final shrimp = plan.ingredients.first;

      expect(shrimp.status, PantryQuantityStatus.insufficient);
      expect(shrimp.requiredQuantity, 400);
      expect(shrimp.shortageQuantity, 150);
      expect(plan.missingRequiredCount, 1);
    });

    test('marks an existing ingredient with an incompatible unit', () {
      final plan = const RecipeServingCalculator().calculate(
        recipe: _shrimpRecipe(),
        pantry: <pantry_model.Ingredient>[
          _pantryIngredient(
            id: 'shrimp',
            name: 'กุ้ง',
            quantity: 1,
            unit: 'แพ็ก',
          ),
        ],
        servings: 2,
      );

      expect(
        plan.ingredients.first.status,
        PantryQuantityStatus.incompatibleUnit,
      );
    });

    test(
      'uses ingredient family aliases such as pork neck for pork recipes',
      () {
        const recipe = Recipe(
          id: 'pork_grill',
          name: 'หมูย่าง',
          category: 'อาหารไทย',
          servings: 2,
          ingredients: <RecipeIngredient>[
            RecipeIngredient(
              id: 'pork',
              name: 'หมู',
              quantity: 300,
              unit: 'กรัม',
              aliases: <String>['เนื้อหมู', 'หมูสด'],
            ),
          ],
          steps: <String>['ย่างหมูให้สุก'],
        );
        final plan = const RecipeServingCalculator().calculate(
          recipe: recipe,
          pantry: <pantry_model.Ingredient>[
            _pantryIngredient(
              id: 'pork-neck',
              name: 'สันคอหมู',
              quantity: 1,
              unit: 'กิโลกรัม',
            ),
          ],
          servings: 4,
        );

        expect(plan.ingredients.single.status, PantryQuantityStatus.enough);
        expect(plan.ingredients.single.requiredQuantity, 600);
      },
    );
  });

  group('RecipeUnitConverter', () {
    test('converts liters and tablespoons to compatible recipe units', () {
      expect(
        RecipeUnitConverter.convert(1, fromUnit: 'ลิตร', toUnit: 'มิลลิลิตร'),
        1000,
      );
      expect(
        RecipeUnitConverter.convert(2, fromUnit: 'ช้อนโต๊ะ', toUnit: 'ช้อนชา'),
        6,
      );
    });
  });
}

Recipe _shrimpRecipe() {
  return const Recipe(
    id: 'shrimp_garlic',
    name: 'กุ้งกระเทียม',
    category: 'อาหารไทย',
    servings: 2,
    ingredients: <RecipeIngredient>[
      RecipeIngredient(
        id: 'shrimp',
        name: 'กุ้ง',
        quantity: 200,
        unit: 'กรัม',
        aliases: <String>['กุ้งสด', 'กุ้งขาว'],
      ),
      RecipeIngredient(
        id: 'garlic',
        name: 'กระเทียม',
        quantity: 4,
        unit: 'กลีบ',
        aliases: <String>['กระเทียมสด'],
      ),
    ],
    steps: <String>['ผัดกุ้งกับกระเทียม'],
  );
}

pantry_model.Ingredient _pantryIngredient({
  required String id,
  required String name,
  required double quantity,
  required String unit,
}) {
  final now = DateTime(2026, 7, 24, 12);
  return pantry_model.Ingredient(
    id: id,
    name: name,
    category: 'วัตถุดิบ',
    emoji: '🍽️',
    quantity: quantity,
    unit: unit,
    createdAt: now,
    updatedAt: now,
  );
}
