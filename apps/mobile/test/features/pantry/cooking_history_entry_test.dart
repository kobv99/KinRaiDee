import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pantry/domain/models/cooking_history_entry.dart';
import 'package:mobile/features/pantry/domain/models/pantry_quantity_transaction.dart';

void main() {
  test('cooking history entry survives JSON round trip', () {
    final createdAt = DateTime(2026, 7, 24, 18, 30);
    final original =
        CookingHistoryEntry.fromTransaction(
          PantryQuantityTransaction(
            recipeId: 'egg_omelette',
            recipeName: 'ไข่เจียว',
            servings: 4,
            changes: const <PantryQuantityChange>[
              PantryQuantityChange(
                ingredientId: 'egg-lot',
                ingredientName: 'ไข่ไก่',
                unit: 'ฟอง',
                beforeQuantity: 10,
                afterQuantity: 6,
              ),
            ],
            createdAt: createdAt,
          ),
        ).copyWith(
          changes: const <CookingHistoryChange>[
            CookingHistoryChange(
              ingredientId: 'egg-lot',
              ingredientName: 'ไข่ไก่',
              unit: 'ฟอง',
              beforeQuantity: 10,
              originalAfterQuantity: 6,
              afterQuantity: 7,
            ),
          ],
          status: CookingHistoryStatus.adjusted,
          updatedAt: createdAt.add(const Duration(minutes: 15)),
        );

    final restored = CookingHistoryEntry.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.recipeName, 'ไข่เจียว');
    expect(restored.servings, 4);
    expect(restored.status, CookingHistoryStatus.adjusted);
    expect(restored.changes.single.originalConsumedQuantity, 4);
    expect(restored.changes.single.consumedQuantity, 3);
    expect(restored.updatedAt, original.updatedAt.toUtc());
  });
}
