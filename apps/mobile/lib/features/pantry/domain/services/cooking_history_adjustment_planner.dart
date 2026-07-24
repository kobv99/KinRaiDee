import '../../../../core/models/ingredient.dart';
import '../models/cooking_history_entry.dart';
import '../models/pantry_quantity_transaction.dart';

class CookingHistoryAdjustmentPlan {
  const CookingHistoryAdjustmentPlan({
    required this.transaction,
    required this.updatedEntry,
  });

  final PantryQuantityTransaction transaction;
  final CookingHistoryEntry updatedEntry;
}

class CookingHistoryAdjustmentException implements Exception {
  const CookingHistoryAdjustmentException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CookingHistoryAdjustmentPlanner {
  const CookingHistoryAdjustmentPlanner();

  CookingHistoryAdjustmentPlan adjust({
    required CookingHistoryEntry entry,
    required List<Ingredient> pantry,
    required Map<String, double> consumedQuantityByIngredientId,
    DateTime? adjustedAt,
  }) {
    if (entry.isCancelled) {
      throw const CookingHistoryAdjustmentException(
        'รายการนี้ถูกยกเลิกแล้วและไม่สามารถแก้ไขซ้ำได้',
      );
    }

    final pantryById = <String, Ingredient>{
      for (final ingredient in pantry) ingredient.id: ingredient,
    };
    final transactionChanges = <PantryQuantityChange>[];
    final updatedChanges = <CookingHistoryChange>[];

    for (final change in entry.changes) {
      final pantryIngredient = pantryById[change.ingredientId];
      if (pantryIngredient == null) {
        throw CookingHistoryAdjustmentException(
          'ไม่พบ ${change.ingredientName} ใน Pantry จึงแก้ประวัติไม่ได้',
        );
      }
      if (pantryIngredient.unit.trim() != change.unit.trim()) {
        throw CookingHistoryAdjustmentException(
          'หน่วยของ ${change.ingredientName} ถูกเปลี่ยนหลังทำอาหาร กรุณาแก้ใน Pantry โดยตรง',
        );
      }
      if (!_nearlyEqual(pantryIngredient.quantity, change.afterQuantity)) {
        throw CookingHistoryAdjustmentException(
          'ปริมาณ ${change.ingredientName} ถูกแก้ไขหลังทำอาหาร กรุณาตรวจ Pantry ก่อนแก้ประวัติ',
        );
      }

      final desiredConsumed =
          consumedQuantityByIngredientId[change.ingredientId] ??
          change.consumedQuantity;
      if (desiredConsumed < 0 ||
          desiredConsumed > change.beforeQuantity + 0.000001) {
        throw CookingHistoryAdjustmentException(
          '${change.ingredientName} ต้องอยู่ระหว่าง 0 ถึง ${_formatNumber(change.beforeQuantity)} ${change.unit}',
        );
      }

      final desiredAfter = (change.beforeQuantity - desiredConsumed)
          .clamp(0, double.infinity)
          .toDouble();
      updatedChanges.add(change.copyWith(afterQuantity: desiredAfter));

      if (_nearlyEqual(change.afterQuantity, desiredAfter)) {
        continue;
      }

      transactionChanges.add(
        PantryQuantityChange(
          ingredientId: change.ingredientId,
          ingredientName: change.ingredientName,
          unit: change.unit,
          beforeQuantity: change.afterQuantity,
          afterQuantity: desiredAfter,
        ),
      );
    }

    final now = adjustedAt ?? DateTime.now();
    final status = updatedChanges.every(
      (change) => _nearlyEqual(change.afterQuantity, change.beforeQuantity),
    )
        ? CookingHistoryStatus.cancelled
        : CookingHistoryStatus.adjusted;

    return CookingHistoryAdjustmentPlan(
      transaction: PantryQuantityTransaction(
        recipeId: entry.recipeId,
        recipeName: entry.recipeName,
        servings: entry.servings,
        changes: List<PantryQuantityChange>.unmodifiable(transactionChanges),
        createdAt: now,
      ),
      updatedEntry: entry.copyWith(
        changes: List<CookingHistoryChange>.unmodifiable(updatedChanges),
        status: status,
        updatedAt: now,
      ),
    );
  }

  CookingHistoryAdjustmentPlan cancel({
    required CookingHistoryEntry entry,
    required List<Ingredient> pantry,
    DateTime? adjustedAt,
  }) {
    return adjust(
      entry: entry,
      pantry: pantry,
      consumedQuantityByIngredientId: <String, double>{
        for (final change in entry.changes) change.ingredientId: 0,
      },
      adjustedAt: adjustedAt,
    );
  }

  static bool _nearlyEqual(double first, double second) {
    return (first - second).abs() <= 0.000001;
  }
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  if ((value * 10).roundToDouble() == value * 10) {
    return value.toStringAsFixed(1);
  }
  return value.toStringAsFixed(2);
}
