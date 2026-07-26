import '../../../../core/models/ingredient.dart' as pantry_model;
import '../entities/recipe.dart';
import '../entities/recipe_ingredient.dart';
import 'ingredient_name_matcher.dart';

enum PantryQuantityStatus { enough, insufficient, missing, incompatibleUnit }

class ScaledRecipeIngredient {
  const ScaledRecipeIngredient({
    required this.ingredient,
    required this.requiredQuantity,
    required this.status,
    this.pantryQuantityInRecipeUnit,
    this.pantryDisplayQuantity,
    this.pantryDisplayUnit,
  });

  final RecipeIngredient ingredient;
  final double requiredQuantity;
  final PantryQuantityStatus status;
  final double? pantryQuantityInRecipeUnit;
  final double? pantryDisplayQuantity;
  final String? pantryDisplayUnit;

  double get shortageQuantity {
    final pantryQuantity = pantryQuantityInRecipeUnit ?? 0;
    final shortage = requiredQuantity - pantryQuantity;
    return shortage > 0 ? shortage : 0;
  }

  bool get isEnough => status == PantryQuantityStatus.enough;
}

class RecipeServingPlan {
  const RecipeServingPlan({
    required this.recipe,
    required this.servings,
    required this.scaleFactor,
    required this.ingredients,
  });

  final Recipe recipe;
  final int servings;
  final double scaleFactor;
  final List<ScaledRecipeIngredient> ingredients;

  int get enoughCount => ingredients
      .where((item) => item.status == PantryQuantityStatus.enough)
      .length;

  int get missingRequiredCount => ingredients
      .where(
        (item) =>
            item.ingredient.required &&
            item.status != PantryQuantityStatus.enough,
      )
      .length;

  bool get hasEnoughRequiredIngredients => missingRequiredCount == 0;
}

class RecipeServingCalculator {
  const RecipeServingCalculator();

  RecipeServingPlan calculate({
    required Recipe recipe,
    required List<pantry_model.Ingredient> pantry,
    required int servings,
  }) {
    if (servings <= 0) {
      throw ArgumentError.value(servings, 'servings', 'must be greater than 0');
    }

    final baseServings = recipe.servings > 0 ? recipe.servings : 1;
    final scaleFactor = servings / baseServings;
    final availablePantry = pantry
        .where((item) => item.quantity > 0 && !item.isExpired)
        .toList(growable: false);

    final scaledIngredients = recipe.ingredients
        .map(
          (ingredient) => _scaleIngredient(
            ingredient: ingredient,
            scaleFactor: scaleFactor,
            pantry: availablePantry,
          ),
        )
        .toList(growable: false);

    return RecipeServingPlan(
      recipe: recipe,
      servings: servings,
      scaleFactor: scaleFactor,
      ingredients: List<ScaledRecipeIngredient>.unmodifiable(scaledIngredients),
    );
  }

  ScaledRecipeIngredient _scaleIngredient({
    required RecipeIngredient ingredient,
    required double scaleFactor,
    required List<pantry_model.Ingredient> pantry,
  }) {
    final requiredQuantity = ingredient.quantity * scaleFactor;
    final matchingPantry = pantry
        .where(
          (item) => recipeIngredientMatchesPantryName(ingredient, item.name),
        )
        .toList(growable: false);

    if (matchingPantry.isEmpty) {
      return ScaledRecipeIngredient(
        ingredient: ingredient,
        requiredQuantity: requiredQuantity,
        status: PantryQuantityStatus.missing,
      );
    }

    var compatibleQuantity = 0.0;
    var hasCompatibleQuantity = false;
    for (final pantryItem in matchingPantry) {
      final converted = RecipeUnitConverter.convert(
        pantryItem.quantity,
        fromUnit: pantryItem.unit,
        toUnit: ingredient.unit,
      );
      if (converted == null) {
        continue;
      }

      compatibleQuantity += converted;
      hasCompatibleQuantity = true;
    }

    if (!hasCompatibleQuantity) {
      final pantryItem = matchingPantry.first;
      return ScaledRecipeIngredient(
        ingredient: ingredient,
        requiredQuantity: requiredQuantity,
        status: PantryQuantityStatus.incompatibleUnit,
        pantryDisplayQuantity: pantryItem.quantity,
        pantryDisplayUnit: pantryItem.unit,
      );
    }

    final status = compatibleQuantity + 0.000001 >= requiredQuantity
        ? PantryQuantityStatus.enough
        : PantryQuantityStatus.insufficient;

    return ScaledRecipeIngredient(
      ingredient: ingredient,
      requiredQuantity: requiredQuantity,
      status: status,
      pantryQuantityInRecipeUnit: compatibleQuantity,
      pantryDisplayQuantity: compatibleQuantity,
      pantryDisplayUnit: ingredient.unit,
    );
  }
}

class RecipeUnitConverter {
  RecipeUnitConverter._();

  static double? convert(
    double quantity, {
    required String fromUnit,
    required String toUnit,
  }) {
    final from = _unitDefinition(fromUnit);
    final to = _unitDefinition(toUnit);

    if (from.normalized == to.normalized) {
      return quantity;
    }
    if (from.dimension == null || from.dimension != to.dimension) {
      return null;
    }

    return quantity * from.factorToBase / to.factorToBase;
  }

  static _UnitDefinition _unitDefinition(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('.', '')
        .replaceAll(RegExp(r'\s+'), '');

    return switch (normalized) {
      'กรัม' ||
      'g' ||
      'gram' ||
      'grams' => const _UnitDefinition('กรัม', 'mass', 1),
      'กิโลกรัม' ||
      'kg' ||
      'kilogram' ||
      'kilograms' => const _UnitDefinition('กิโลกรัม', 'mass', 1000),
      'มิลลิลิตร' ||
      'ml' ||
      'milliliter' ||
      'milliliters' => const _UnitDefinition('มิลลิลิตร', 'volume', 1),
      'ลิตร' ||
      'l' ||
      'liter' ||
      'liters' => const _UnitDefinition('ลิตร', 'volume', 1000),
      'ช้อนชา' ||
      'tsp' ||
      'teaspoon' ||
      'teaspoons' => const _UnitDefinition('ช้อนชา', 'spoon', 1),
      'ช้อนโต๊ะ' ||
      'tbsp' ||
      'tablespoon' ||
      'tablespoons' => const _UnitDefinition('ช้อนโต๊ะ', 'spoon', 3),
      _ => _UnitDefinition(normalized, null, 1),
    };
  }
}

class _UnitDefinition {
  const _UnitDefinition(this.normalized, this.dimension, this.factorToBase);

  final String normalized;
  final String? dimension;
  final double factorToBase;
}
