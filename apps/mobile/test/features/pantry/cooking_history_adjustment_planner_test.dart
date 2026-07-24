import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/features/pantry/domain/models/cooking_history_entry.dart';
import 'package:mobile/features/pantry/domain/models/pantry_quantity_transaction.dart';
import 'package:mobile/features/pantry/domain/services/cooking_history_adjustment_planner.dart';

void main() {
  group('CookingHistoryAdjustmentPlanner', () {
    test('returns one egg when actual usage is lower than recorded', () {
      final entry = _entry(before: 10, after: 6);
      final pantry = <Ingredient>[_pantry(quantity: 6)];

      final plan = const CookingHistoryAdjustmentPlanner().adjust(
        entry: entry,
        pantry: pantry,
        consumedQuantityByIngredientId: const <String, double>{'egg-lot': 3},
        adjustedAt: DateTime(2026, 7, 24, 19),
      );

      expect(plan.transaction.changes.single.beforeQuantity, 6);
      expect(plan.transaction.changes.single.afterQuantity, 7);
      expect(plan.updatedEntry.changes.single.consumedQuantity, 3);
      expect(plan.updatedEntry.status, CookingHistoryStatus.adjusted);
    });

    test('deducts one more egg when actual usage is higher', () {
      final entry = _entry(before: 10, after: 6);
      final pantry = <Ingredient>[_pantry(quantity: 6)];

      final plan = const CookingHistoryAdjustmentPlanner().adjust(
        entry: entry,
        pantry: pantry,
        consumedQuantityByIngredientId: const <String, double>{'egg-lot': 5},
      );

      expect(plan.transaction.changes.single.beforeQuantity, 6);
      expect(plan.transaction.changes.single.afterQuantity, 5);
      expect(plan.updatedEntry.changes.single.consumedQuantity, 5);
    });

    test('cancelling restores the original Pantry quantity', () {
      final entry = _entry(before: 10, after: 6);
      final pantry = <Ingredient>[_pantry(quantity: 6)];

      final plan = const CookingHistoryAdjustmentPlanner().cancel(
        entry: entry,
        pantry: pantry,
      );

      expect(plan.transaction.changes.single.afterQuantity, 10);
      expect(plan.updatedEntry.changes.single.consumedQuantity, 0);
      expect(plan.updatedEntry.status, CookingHistoryStatus.cancelled);
    });

    test('blocks history edit after Pantry quantity changed separately', () {
      final entry = _entry(before: 10, after: 6);
      final pantry = <Ingredient>[_pantry(quantity: 5)];

      expect(
        () => const CookingHistoryAdjustmentPlanner().adjust(
          entry: entry,
          pantry: pantry,
          consumedQuantityByIngredientId: const <String, double>{
            'egg-lot': 3,
          },
        ),
        throwsA(isA<CookingHistoryAdjustmentException>()),
      );
    });

    test('unchanged quantity does not create another Pantry transaction', () {
      final entry = _entry(before: 10, after: 6);
      final pantry = <Ingredient>[_pantry(quantity: 6)];

      final plan = const CookingHistoryAdjustmentPlanner().adjust(
        entry: entry,
        pantry: pantry,
        consumedQuantityByIngredientId: const <String, double>{'egg-lot': 4},
      );

      expect(plan.transaction.changes, isEmpty);
      expect(plan.updatedEntry.status, CookingHistoryStatus.completed);
      expect(plan.updatedEntry.updatedAt, entry.updatedAt);
    });
  });
}

CookingHistoryEntry _entry({
  required double before,
  required double after,
}) {
  final time = DateTime(2026, 7, 24, 18, 30);
  return CookingHistoryEntry.fromTransaction(
    PantryQuantityTransaction(
      recipeId: 'egg_omelette',
      recipeName: 'ไข่เจียว',
      servings: 4,
      changes: <PantryQuantityChange>[
        PantryQuantityChange(
          ingredientId: 'egg-lot',
          ingredientName: 'ไข่ไก่',
          unit: 'ฟอง',
          beforeQuantity: before,
          afterQuantity: after,
        ),
      ],
      createdAt: time,
    ),
  );
}

Ingredient _pantry({required double quantity}) {
  final time = DateTime(2026, 7, 24, 18, 30);
  return Ingredient(
    id: 'egg-lot',
    name: 'ไข่ไก่',
    category: 'ไข่',
    emoji: '🥚',
    quantity: quantity,
    unit: 'ฟอง',
    createdAt: time,
    updatedAt: time,
  );
}
