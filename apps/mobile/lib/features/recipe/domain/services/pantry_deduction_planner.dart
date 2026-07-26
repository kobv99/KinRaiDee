import '../../../../core/models/ingredient.dart' as pantry_model;
import '../../../../core/time/app_clock.dart';
import '../../../pantry/domain/models/pantry_quantity_transaction.dart';
import '../entities/recipe_ingredient.dart';
import 'ingredient_name_matcher.dart';
import 'recipe_serving_calculator.dart';

class PantryDeductionAllocation {
  const PantryDeductionAllocation({
    required this.pantryIngredientId,
    required this.pantryIngredientName,
    required this.pantryUnit,
    required this.pantryQuantityBefore,
    required this.recipeUnitQuantity,
    required this.pantryUnitQuantity,
  });

  final String pantryIngredientId;
  final String pantryIngredientName;
  final String pantryUnit;
  final double pantryQuantityBefore;
  final double recipeUnitQuantity;
  final double pantryUnitQuantity;
}

class PantryDeductionLine {
  const PantryDeductionLine({
    required this.ingredient,
    required this.targetQuantity,
    required this.deductibleQuantity,
    required this.allocations,
    required this.defaultSelected,
  });

  final RecipeIngredient ingredient;
  final double targetQuantity;
  final double deductibleQuantity;
  final List<PantryDeductionAllocation> allocations;
  final bool defaultSelected;

  String get key => ingredient.id;
  String get unit => ingredient.unit;
  bool get isPartial => deductibleQuantity + 0.000001 < targetQuantity;
}

class PantryDeductionPlan {
  const PantryDeductionPlan({
    required this.servingPlan,
    required this.lines,
    required this.skippedStapleCount,
    required this.skippedUnavailableCount,
  });

  final RecipeServingPlan servingPlan;
  final List<PantryDeductionLine> lines;
  final int skippedStapleCount;
  final int skippedUnavailableCount;

  bool get canDeduct => lines.isNotEmpty;
}

class PantryDeductionPlanner {
  const PantryDeductionPlanner({this.clock = systemAppClock});

  final AppClock clock;

  static const Set<String> _stapleIngredientIds = <String>{
    'fish_sauce',
    'soy_sauce',
    'dark_soy_sauce',
    'oyster_sauce',
    'seasoning_sauce',
    'cooking_oil',
    'sugar',
    'salt',
    'pepper',
    'chili_paste',
    'red_curry_paste',
    'sour_curry_paste',
    'tamarind_sauce',
  };

  PantryDeductionPlan build({
    required RecipeServingPlan servingPlan,
    required List<pantry_model.Ingredient> pantry,
  }) {
    final availablePantry = pantry
        .where((item) => item.quantity > 0 && !item.isExpiredAt(clock.now()))
        .toList(growable: false);
    final lines = <PantryDeductionLine>[];
    var skippedStapleCount = 0;
    var skippedUnavailableCount = 0;

    for (final scaled in servingPlan.ingredients) {
      final ingredient = scaled.ingredient;
      if (_stapleIngredientIds.contains(ingredient.id)) {
        skippedStapleCount++;
        continue;
      }

      final matching =
          availablePantry
              .where(
                (item) =>
                    recipeIngredientMatchesPantryName(ingredient, item.name),
              )
              .toList(growable: false)
            ..sort(_comparePantryLots);

      final allocations = <PantryDeductionAllocation>[];
      var remainingRecipeQuantity = scaled.requiredQuantity;

      for (final pantryItem in matching) {
        if (remainingRecipeQuantity <= 0.000001) {
          break;
        }

        final availableInRecipeUnit = RecipeUnitConverter.convert(
          pantryItem.quantity,
          fromUnit: pantryItem.unit,
          toUnit: ingredient.unit,
        );
        if (availableInRecipeUnit == null || availableInRecipeUnit <= 0) {
          continue;
        }

        final recipeQuantityToUse =
            availableInRecipeUnit < remainingRecipeQuantity
            ? availableInRecipeUnit
            : remainingRecipeQuantity;
        final pantryQuantityToUse = RecipeUnitConverter.convert(
          recipeQuantityToUse,
          fromUnit: ingredient.unit,
          toUnit: pantryItem.unit,
        );
        if (pantryQuantityToUse == null || pantryQuantityToUse <= 0) {
          continue;
        }

        allocations.add(
          PantryDeductionAllocation(
            pantryIngredientId: pantryItem.id,
            pantryIngredientName: pantryItem.name,
            pantryUnit: pantryItem.unit,
            pantryQuantityBefore: pantryItem.quantity,
            recipeUnitQuantity: recipeQuantityToUse,
            pantryUnitQuantity: pantryQuantityToUse,
          ),
        );
        remainingRecipeQuantity -= recipeQuantityToUse;
      }

      final deductibleQuantity = allocations.fold<double>(
        0,
        (total, allocation) => total + allocation.recipeUnitQuantity,
      );
      if (deductibleQuantity <= 0.000001) {
        skippedUnavailableCount++;
        continue;
      }

      lines.add(
        PantryDeductionLine(
          ingredient: ingredient,
          targetQuantity: scaled.requiredQuantity,
          deductibleQuantity: deductibleQuantity,
          allocations: List<PantryDeductionAllocation>.unmodifiable(
            allocations,
          ),
          defaultSelected: ingredient.required,
        ),
      );
    }

    return PantryDeductionPlan(
      servingPlan: servingPlan,
      lines: List<PantryDeductionLine>.unmodifiable(lines),
      skippedStapleCount: skippedStapleCount,
      skippedUnavailableCount: skippedUnavailableCount,
    );
  }

  PantryQuantityTransaction createTransaction({
    required PantryDeductionPlan plan,
    required Set<String> selectedLineKeys,
    required Map<String, double> quantitiesByLineKey,
    DateTime? createdAt,
  }) {
    final beforeByPantryId = <String, double>{};
    final afterByPantryId = <String, double>{};
    final nameByPantryId = <String, String>{};
    final unitByPantryId = <String, String>{};

    for (final line in plan.lines) {
      for (final allocation in line.allocations) {
        beforeByPantryId.putIfAbsent(
          allocation.pantryIngredientId,
          () => allocation.pantryQuantityBefore,
        );
        afterByPantryId.putIfAbsent(
          allocation.pantryIngredientId,
          () => allocation.pantryQuantityBefore,
        );
        nameByPantryId[allocation.pantryIngredientId] =
            allocation.pantryIngredientName;
        unitByPantryId[allocation.pantryIngredientId] = allocation.pantryUnit;
      }
    }

    for (final line in plan.lines) {
      if (!selectedLineKeys.contains(line.key)) {
        continue;
      }

      final requested =
          quantitiesByLineKey[line.key] ?? line.deductibleQuantity;
      var remainingRecipeQuantity = requested
          .clamp(0, line.deductibleQuantity)
          .toDouble();

      for (final allocation in line.allocations) {
        if (remainingRecipeQuantity <= 0.000001) {
          break;
        }

        final recipeQuantityToUse =
            allocation.recipeUnitQuantity < remainingRecipeQuantity
            ? allocation.recipeUnitQuantity
            : remainingRecipeQuantity;
        final plannedPantryQuantity = allocation.recipeUnitQuantity <= 0
            ? 0
            : allocation.pantryUnitQuantity *
                  recipeQuantityToUse /
                  allocation.recipeUnitQuantity;
        final pantryId = allocation.pantryIngredientId;
        final currentPantryQuantity = afterByPantryId[pantryId] ?? 0;
        final actualPantryQuantity =
            plannedPantryQuantity < currentPantryQuantity
            ? plannedPantryQuantity
            : currentPantryQuantity;

        afterByPantryId[pantryId] =
            (currentPantryQuantity - actualPantryQuantity)
                .clamp(0, double.infinity)
                .toDouble();
        remainingRecipeQuantity -= recipeQuantityToUse;
      }
    }

    final changes = <PantryQuantityChange>[];
    for (final entry in beforeByPantryId.entries) {
      final after = afterByPantryId[entry.key] ?? entry.value;
      if ((entry.value - after).abs() <= 0.000001) {
        continue;
      }

      changes.add(
        PantryQuantityChange(
          ingredientId: entry.key,
          ingredientName: nameByPantryId[entry.key] ?? entry.key,
          unit: unitByPantryId[entry.key] ?? '',
          beforeQuantity: entry.value,
          afterQuantity: after,
        ),
      );
    }

    return PantryQuantityTransaction(
      recipeId: plan.servingPlan.recipe.id,
      recipeName: plan.servingPlan.recipe.name,
      servings: plan.servingPlan.servings,
      changes: List<PantryQuantityChange>.unmodifiable(changes),
      createdAt: createdAt ?? clock.now(),
    );
  }

  static int _comparePantryLots(
    pantry_model.Ingredient first,
    pantry_model.Ingredient second,
  ) {
    final firstExpiry = first.expiryDate;
    final secondExpiry = second.expiryDate;

    if (firstExpiry != null && secondExpiry != null) {
      final expiryComparison = firstExpiry.compareTo(secondExpiry);
      if (expiryComparison != 0) {
        return expiryComparison;
      }
    } else if (firstExpiry != null) {
      return -1;
    } else if (secondExpiry != null) {
      return 1;
    }

    final createdComparison = first.createdAt.compareTo(second.createdAt);
    if (createdComparison != 0) {
      return createdComparison;
    }

    return first.name.compareTo(second.name);
  }
}
