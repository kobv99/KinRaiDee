import '../../../../core/models/ingredient.dart';
import '../../../../core/time/app_clock.dart';
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
  const CookingHistoryAdjustmentPlanner({this.clock = systemAppClock});

  final AppClock clock;

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

      final desiredConsumed =
          consumedQuantityByIngredientId[change.ingredientId] ??
          change.consumedQuantity;
      if (desiredConsumed < 0 ||
          desiredConsumed > change.beforeQuantity + 0.000001) {
        throw CookingHistoryAdjustmentException(
          '${change.ingredientName} ต้องอยู่ระหว่าง 0 ถึง ${_formatNumber(change.beforeQuantity)} ${change.unit}',
        );
      }

      final consumptionDelta = desiredConsumed - change.consumedQuantity;
      if (consumptionDelta > pantryIngredient.quantity + 0.000001) {
        throw CookingHistoryAdjustmentException(
          '${change.ingredientName} ใน Pantry ไม่พอสำหรับหักเพิ่ม ${_formatNumber(consumptionDelta)} ${change.unit}',
        );
      }

      final desiredHistoryAfter = (change.beforeQuantity - desiredConsumed)
          .clamp(0, double.infinity)
          .toDouble();
      updatedChanges.add(change.copyWith(afterQuantity: desiredHistoryAfter));

      if (_nearlyEqual(consumptionDelta, 0)) {
        continue;
      }

      final pantryAfter = (pantryIngredient.quantity - consumptionDelta)
          .clamp(0, double.infinity)
          .toDouble();
      transactionChanges.add(
        PantryQuantityChange(
          ingredientId: change.ingredientId,
          ingredientName: change.ingredientName,
          unit: change.unit,
          beforeQuantity: pantryIngredient.quantity,
          afterQuantity: pantryAfter,
          canonicalIngredientId: pantryIngredient.canonicalIngredientId,
          canonicalUnitId: pantryIngredient.canonicalUnitId,
        ),
      );
    }

    final now = adjustedAt ?? clock.now();
    final allReturned = updatedChanges.every(
      (change) => _nearlyEqual(change.afterQuantity, change.beforeQuantity),
    );
    final status = transactionChanges.isEmpty
        ? entry.status
        : allReturned
        ? CookingHistoryStatus.cancelled
        : CookingHistoryStatus.adjusted;
    final resolvedChanges = allReturned && transactionChanges.isNotEmpty
        ? entry.changes
              .map(
                (change) => change.copyWith(
                  originalAfterQuantity: change.afterQuantity,
                  afterQuantity: change.beforeQuantity,
                ),
              )
              .toList(growable: false)
        : updatedChanges;

    return CookingHistoryAdjustmentPlan(
      transaction: PantryQuantityTransaction(
        recipeId: entry.recipeId,
        recipeName: entry.recipeName,
        servings: entry.servings,
        changes: List<PantryQuantityChange>.unmodifiable(transactionChanges),
        createdAt: now,
      ),
      updatedEntry: entry.copyWith(
        changes: List<CookingHistoryChange>.unmodifiable(resolvedChanges),
        status: status,
        updatedAt: transactionChanges.isEmpty ? entry.updatedAt : now,
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
