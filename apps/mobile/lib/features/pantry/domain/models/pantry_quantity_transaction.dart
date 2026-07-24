class PantryQuantityChange {
  const PantryQuantityChange({
    required this.ingredientId,
    required this.ingredientName,
    required this.unit,
    required this.beforeQuantity,
    required this.afterQuantity,
  });

  final String ingredientId;
  final String ingredientName;
  final String unit;
  final double beforeQuantity;
  final double afterQuantity;

  double get consumedQuantity {
    final consumed = beforeQuantity - afterQuantity;
    return consumed > 0 ? consumed : 0;
  }
}

class PantryQuantityTransaction {
  const PantryQuantityTransaction({
    required this.recipeId,
    required this.recipeName,
    required this.servings,
    required this.changes,
    required this.createdAt,
  });

  final String recipeId;
  final String recipeName;
  final int servings;
  final List<PantryQuantityChange> changes;
  final DateTime createdAt;

  bool get hasChanges => changes.isNotEmpty;
  int get changedIngredientCount => changes.length;
}