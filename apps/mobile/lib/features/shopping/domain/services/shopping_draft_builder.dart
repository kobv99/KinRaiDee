import '../../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../../../../core/domain/units/unit_contract.dart';
import '../../../../core/models/ingredient.dart';
import '../../../recipe/domain/entities/recipe.dart';
import '../../../recipe/domain/services/recipe_serving_calculator.dart';
import '../entities/shopping_category.dart';
import '../entities/shopping_item.dart';
import '../entities/shopping_list.dart';
import '../entities/shopping_source.dart';

class ShoppingDomainException implements Exception {
  const ShoppingDomainException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'ShoppingDomainException($code): $message';
}

class ShoppingItemFactory {
  const ShoppingItemFactory({required this.registry, required this.unitEngine});

  final CanonicalIngredientRegistry registry;
  final UnitConversionEngine unitEngine;

  ShoppingItem create({
    required String id,
    required String canonicalIngredientId,
    required double quantity,
    required String unit,
    required ShoppingSource source,
    String? sourceReferenceId,
    List<String> sourceReferenceIds = const <String>[],
    required DateTime createdAt,
  }) {
    final canonical = registry.byId(canonicalIngredientId);
    if (canonical == null) {
      throw ShoppingDomainException(
        'unknown_canonical_ingredient',
        'Shopping item references unknown ingredient $canonicalIngredientId.',
      );
    }
    final unitId = unitEngine.resolveUnitId(unit);
    if (unitId == null) {
      throw ShoppingDomainException(
        'unknown_unit',
        'Shopping item references unknown unit $unit.',
      );
    }
    if (!quantity.isFinite || quantity <= 0) {
      throw ShoppingDomainException(
        'invalid_quantity',
        'Shopping item quantity must be finite and greater than zero.',
      );
    }
    if (id.trim().isEmpty) {
      throw const ShoppingDomainException(
        'missing_item_id',
        'Shopping item ID is required.',
      );
    }
    final sourceIds = <String>{
      ...sourceReferenceIds.map((value) => value.trim()),
      if (sourceReferenceId != null) sourceReferenceId.trim(),
    }.where((value) => value.isNotEmpty).toList()..sort();
    final sourceId = sourceIds.isEmpty ? null : sourceIds.first;
    if (source != ShoppingSource.manual &&
        (sourceId == null || sourceId.isEmpty)) {
      throw const ShoppingDomainException(
        'missing_source_reference',
        'Derived Shopping items require a source reference.',
      );
    }
    final rounded = unitEngine.precisionPolicy.apply(
      quantity,
      decimalPlaces: unitEngine.resolveUnit(unitId)?.decimalPlaces,
    );
    if (rounded <= 0) {
      throw const ShoppingDomainException(
        'quantity_below_unit_precision',
        'Shopping item quantity rounds to zero for its canonical unit.',
      );
    }
    return ShoppingItem(
      id: id.trim(),
      canonicalIngredientId: canonical.id,
      displayName: canonical.displayName(),
      quantity: rounded,
      unitId: unitId,
      category: ShoppingCategory.fromCanonicalCategory(canonical.category),
      source: source,
      sourceReferenceId: sourceId,
      sourceReferenceIds: sourceIds,
      createdAt: createdAt.toUtc(),
      updatedAt: createdAt.toUtc(),
    );
  }
}

class ShoppingDraftBuilder {
  const ShoppingDraftBuilder({
    required this.registry,
    required this.unitEngine,
  });

  final CanonicalIngredientRegistry registry;
  final UnitConversionEngine unitEngine;

  ShoppingList fromRecipe({
    required String listId,
    required String name,
    required Recipe recipe,
    required List<Ingredient> pantry,
    required int servings,
    required DateTime createdAt,
    bool includeOptional = false,
  }) {
    final plan = const RecipeServingCalculator().calculate(
      recipe: recipe,
      pantry: pantry,
      servings: servings,
      registry: registry,
    );
    final factory = ShoppingItemFactory(
      registry: registry,
      unitEngine: unitEngine,
    );
    final items = <ShoppingItem>[];
    for (final scaled in plan.ingredients) {
      if (scaled.isEnough ||
          (!includeOptional && !scaled.ingredient.required) ||
          scaled.shortageQuantity <= unitEngine.precisionPolicy.zeroTolerance) {
        continue;
      }
      final canonicalId = registry.canonicalIdFor(
        scaled.ingredient.canonicalIngredientId,
      );
      if (canonicalId == null) {
        throw ShoppingDomainException(
          'unknown_recipe_ingredient',
          'Recipe ${recipe.id} references unknown ingredient '
              '${scaled.ingredient.canonicalIngredientId}.',
        );
      }
      final unitId = unitEngine.resolveUnitId(scaled.ingredient.unit);
      if (unitId == null) {
        throw ShoppingDomainException(
          'unknown_recipe_unit',
          'Recipe ${recipe.id} references unknown unit '
              '${scaled.ingredient.unit}.',
        );
      }
      items.add(
        factory.create(
          id: '$listId::$canonicalId::$unitId',
          canonicalIngredientId: canonicalId,
          quantity: scaled.shortageQuantity,
          unit: unitId,
          source: ShoppingSource.recipe,
          sourceReferenceId: recipe.id,
          createdAt: createdAt,
        ),
      );
    }
    items.sort(
      (first, second) =>
          first.canonicalIngredientId.compareTo(second.canonicalIngredientId),
    );
    return ShoppingList(
      id: listId,
      name: name,
      items: items,
      createdAt: createdAt.toUtc(),
      updatedAt: createdAt.toUtc(),
    );
  }
}
