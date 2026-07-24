import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart' as pantry_model;
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/services/pantry_deduction_planner.dart';
import 'package:mobile/features/recipe/domain/services/recipe_serving_calculator.dart';

void main() {
  group('PantryDeductionPlanner', () {
    test('deducts the lot that expires first before newer Pantry lots', () {
      final now = DateTime(2026, 7, 24, 12);
      final recipe = _recipe(
        ingredients: const <RecipeIngredient>[
          RecipeIngredient(
            id: 'shrimp',
            name: 'กุ้ง',
            quantity: 200,
            unit: 'กรัม',
            aliases: <String>['กุ้งขาว'],
          ),
        ],
      );
      final pantry = <pantry_model.Ingredient>[
        _pantry(
          id: 'later-lot',
          name: 'กุ้งขาว',
          quantity: 300,
          unit: 'กรัม',
          expiryDate: DateTime(2026, 7, 30),
          createdAt: now,
        ),
        _pantry(
          id: 'soon-lot',
          name: 'กุ้งขาว',
          quantity: 100,
          unit: 'กรัม',
          expiryDate: DateTime(2026, 7, 25),
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ];
      final servingPlan = const RecipeServingCalculator().calculate(
        recipe: recipe,
        pantry: pantry,
        servings: 2,
      );
      const planner = PantryDeductionPlanner();
      final plan = planner.build(servingPlan: servingPlan, pantry: pantry);
      final line = plan.lines.single;
      final transaction = planner.createTransaction(
        plan: plan,
        selectedLineKeys: <String>{line.key},
        quantitiesByLineKey: <String, double>{line.key: 200},
        createdAt: now,
      );
      final changes = <String, double>{
        for (final change in transaction.changes)
          change.ingredientId: change.afterQuantity,
      };

      expect(line.allocations.first.pantryIngredientId, 'soon-lot');
      expect(changes['soon-lot'], 0);
      expect(changes['later-lot'], 200);
      expect(transaction.recipeName, 'เมนูทดสอบ');
      expect(transaction.servings, 2);
    });

    test('converts grams to kilograms and respects an edited quantity', () {
      final recipe = _recipe(
        ingredients: const <RecipeIngredient>[
          RecipeIngredient(
            id: 'pork',
            name: 'หมู',
            quantity: 200,
            unit: 'กรัม',
            aliases: <String>['สันคอหมู'],
          ),
        ],
      );
      final pantry = <pantry_model.Ingredient>[
        _pantry(
          id: 'pork-lot',
          name: 'สันคอหมู',
          quantity: 1,
          unit: 'กิโลกรัม',
        ),
      ];
      final servingPlan = const RecipeServingCalculator().calculate(
        recipe: recipe,
        pantry: pantry,
        servings: 2,
      );
      const planner = PantryDeductionPlanner();
      final plan = planner.build(servingPlan: servingPlan, pantry: pantry);
      final line = plan.lines.single;
      final transaction = planner.createTransaction(
        plan: plan,
        selectedLineKeys: <String>{line.key},
        quantitiesByLineKey: <String, double>{line.key: 150},
      );

      expect(transaction.changes.single.beforeQuantity, 1);
      expect(transaction.changes.single.afterQuantity, closeTo(0.85, 0.000001));
      expect(transaction.changes.single.consumedQuantity, closeTo(0.15, 0.000001));
    });

    test('does not auto deduct seasonings and leaves optional items unchecked', () {
      final recipe = _recipe(
        ingredients: const <RecipeIngredient>[
          RecipeIngredient(
            id: 'egg',
            name: 'ไข่ไก่',
            quantity: 2,
            unit: 'ฟอง',
          ),
          RecipeIngredient(
            id: 'spring_onion',
            name: 'ต้นหอม',
            quantity: 1,
            unit: 'ต้น',
            required: false,
          ),
          RecipeIngredient(
            id: 'fish_sauce',
            name: 'น้ำปลา',
            quantity: 1,
            unit: 'ช้อนโต๊ะ',
          ),
        ],
      );
      final pantry = <pantry_model.Ingredient>[
        _pantry(id: 'egg', name: 'ไข่ไก่', quantity: 10, unit: 'ฟอง'),
        _pantry(id: 'onion', name: 'ต้นหอม', quantity: 3, unit: 'ต้น'),
        _pantry(
          id: 'fish-sauce',
          name: 'น้ำปลา',
          quantity: 10,
          unit: 'ช้อนโต๊ะ',
        ),
      ];
      final servingPlan = const RecipeServingCalculator().calculate(
        recipe: recipe,
        pantry: pantry,
        servings: 2,
      );
      final plan = const PantryDeductionPlanner().build(
        servingPlan: servingPlan,
        pantry: pantry,
      );

      expect(plan.lines.map((line) => line.key), containsAll(<String>['egg', 'spring_onion']));
      expect(plan.lines.map((line) => line.key), isNot(contains('fish_sauce')));
      expect(plan.skippedStapleCount, 1);
      expect(
        plan.lines.firstWhere((line) => line.key == 'egg').defaultSelected,
        isTrue,
      );
      expect(
        plan.lines.firstWhere((line) => line.key == 'spring_onion').defaultSelected,
        isFalse,
      );
    });

    test('partial Pantry stock is capped at the recorded available amount', () {
      final recipe = _recipe(
        ingredients: const <RecipeIngredient>[
          RecipeIngredient(
            id: 'fish',
            name: 'ปลา',
            quantity: 300,
            unit: 'กรัม',
            aliases: <String>['ปลากะพง'],
          ),
        ],
      );
      final pantry = <pantry_model.Ingredient>[
        _pantry(
          id: 'fish-lot',
          name: 'ปลากะพง',
          quantity: 120,
          unit: 'กรัม',
        ),
      ];
      final servingPlan = const RecipeServingCalculator().calculate(
        recipe: recipe,
        pantry: pantry,
        servings: 2,
      );
      const planner = PantryDeductionPlanner();
      final plan = planner.build(servingPlan: servingPlan, pantry: pantry);
      final line = plan.lines.single;
      final transaction = planner.createTransaction(
        plan: plan,
        selectedLineKeys: <String>{line.key},
        quantitiesByLineKey: <String, double>{line.key: 999},
      );

      expect(line.isPartial, isTrue);
      expect(line.deductibleQuantity, 120);
      expect(transaction.changes.single.afterQuantity, 0);
    });
  });
}

Recipe _recipe({required List<RecipeIngredient> ingredients}) {
  return Recipe(
    id: 'test_recipe',
    name: 'เมนูทดสอบ',
    category: 'อาหารไทย',
    servings: 2,
    ingredients: ingredients,
    steps: const <String>['เตรียมของ', 'ปรุงให้สุก'],
  );
}

pantry_model.Ingredient _pantry({
  required String id,
  required String name,
  required double quantity,
  required String unit,
  DateTime? expiryDate,
  DateTime? createdAt,
}) {
  final time = createdAt ?? DateTime(2026, 7, 24, 12);
  return pantry_model.Ingredient(
    id: id,
    name: name,
    category: 'วัตถุดิบ',
    emoji: '🍽️',
    quantity: quantity,
    unit: unit,
    expiryDate: expiryDate,
    createdAt: time,
    updatedAt: time,
  );
}