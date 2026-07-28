import '../../../../core/domain/ingredients/canonical_ingredient.dart';
import '../../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../../../../core/domain/units/unit_contract.dart';
import '../../../../core/models/ingredient.dart';
import '../../../recipe/domain/entities/recipe.dart';
import '../entities/shopping_item.dart';
import '../entities/shopping_item_status.dart';
import '../entities/shopping_list.dart';
import '../entities/shopping_source.dart';
import 'shopping_draft_builder.dart';

class ShoppingRecipeRequest {
  const ShoppingRecipeRequest({required this.recipe, required this.servings});

  final Recipe recipe;
  final int servings;
}

class ShoppingGenerationResult {
  const ShoppingGenerationResult({
    required this.list,
    required this.recipeCount,
    required this.aggregatedIngredientCount,
    required this.missingIngredientCount,
  });

  final ShoppingList list;
  final int recipeCount;
  final int aggregatedIngredientCount;
  final int missingIngredientCount;
}

class ShoppingEngine {
  const ShoppingEngine({required this.registry, required this.unitEngine});

  final CanonicalIngredientRegistry registry;
  final UnitConversionEngine unitEngine;

  ShoppingGenerationResult generate({
    required String listId,
    required String name,
    required List<ShoppingRecipeRequest> recipes,
    required List<Ingredient> pantry,
    required DateTime generatedAt,
    ShoppingList? existingList,
    bool includeOptional = false,
  }) {
    final normalizedListId = listId.trim();
    if (normalizedListId.isEmpty || name.trim().isEmpty) {
      throw const ShoppingDomainException(
        'invalid_shopping_list_identity',
        'Shopping list ID and name are required.',
      );
    }
    if (existingList != null && existingList.id != normalizedListId) {
      throw const ShoppingDomainException(
        'shopping_list_identity_mismatch',
        'Existing Shopping list does not match the requested list ID.',
      );
    }

    final at = generatedAt.toUtc();
    final requirements = <String, _Requirement>{};
    for (final request in recipes) {
      _collectRecipe(request, requirements, includeOptional: includeOptional);
    }
    for (final requirement in requirements.values) {
      requirement.quantity = _round(requirement.quantity, requirement.unitId);
    }

    final pantryByCanonical = _pantryQuantities(pantry, requirements, at: at);
    final completedItems = <ShoppingItem>[];
    final activeByCanonical = <String, List<ShoppingItem>>{};
    for (final item in existingList?.items ?? const <ShoppingItem>[]) {
      final canonicalId = registry.canonicalIdFor(item.canonicalIngredientId);
      if (canonicalId == null) {
        throw ShoppingDomainException(
          'unknown_existing_shopping_ingredient',
          'Existing Shopping item ${item.id} has an unknown canonical ID.',
        );
      }
      if (item.status != ShoppingItemStatus.active) {
        completedItems.add(item);
        continue;
      }
      activeByCanonical
          .putIfAbsent(canonicalId, () => <ShoppingItem>[])
          .add(item);
    }

    final activeItems = <ShoppingItem>[];
    final canonicalIds = <String>{
      ...requirements.keys,
      ...activeByCanonical.keys,
    }.toList()..sort();
    for (final canonicalId in canonicalIds) {
      final canonical = registry.byId(canonicalId)!;
      final targetUnitId = _purchaseUnitFor(canonical);
      final existing = activeByCanonical[canonicalId] ?? const <ShoppingItem>[];
      final existingQuantity = _sumExisting(
        existing,
        targetUnitId: targetUnitId,
      );
      final requirement = requirements[canonicalId];
      final pantryQuantity = pantryByCanonical[canonicalId] ?? 0;
      final missing = requirement == null
          ? 0.0
          : _positive(requirement.quantity - pantryQuantity);
      final hasManualIntent = existing.any(
        (item) => item.source == ShoppingSource.manual,
      );
      final targetQuantity = requirement == null
          ? existingQuantity
          : hasManualIntent
          ? existingQuantity > missing
                ? existingQuantity
                : missing
          : missing;
      final rounded = _round(targetQuantity, targetUnitId);
      if (rounded <= unitEngine.precisionPolicy.zeroTolerance) {
        continue;
      }

      final sortedExisting = List<ShoppingItem>.of(existing)
        ..sort((first, second) => first.id.compareTo(second.id));
      final survivor = sortedExisting.firstOrNull;
      final source = hasManualIntent
          ? ShoppingSource.manual
          : requirement == null && survivor != null
          ? survivor.source
          : ShoppingSource.recipe;
      final references =
          source == ShoppingSource.manual
                ? _references(existing)
                : requirement != null
                ? requirement.recipeIds.toList()
                : _references(existing)
            ..sort();
      activeItems.add(
        ShoppingItemFactory(registry: registry, unitEngine: unitEngine)
            .create(
              id:
                  survivor?.id ??
                  '$normalizedListId::$canonicalId::$targetUnitId',
              canonicalIngredientId: canonicalId,
              quantity: rounded,
              unit: targetUnitId,
              source: source,
              sourceReferenceIds: references,
              createdAt: survivor?.createdAt ?? at,
            )
            .copyWith(updatedAt: at),
      );
    }

    final allItems = <ShoppingItem>[...activeItems, ...completedItems]
      ..sort(_compareItems);
    final list =
        existingList?.copyWith(items: allItems, updatedAt: at) ??
        ShoppingList(
          id: normalizedListId,
          name: name.trim(),
          items: allItems,
          createdAt: at,
          updatedAt: at,
        );
    return ShoppingGenerationResult(
      list: list,
      recipeCount: recipes.length,
      aggregatedIngredientCount: requirements.length,
      missingIngredientCount: activeItems
          .where((item) => requirements.containsKey(item.canonicalIngredientId))
          .length,
    );
  }

  void _collectRecipe(
    ShoppingRecipeRequest request,
    Map<String, _Requirement> requirements, {
    required bool includeOptional,
  }) {
    if (request.servings <= 0) {
      throw const ShoppingDomainException(
        'invalid_servings',
        'Recipe servings must be greater than zero.',
      );
    }
    final recipe = request.recipe;
    final baseServings = recipe.servings > 0 ? recipe.servings : 1;
    final scale = request.servings / baseServings;
    for (final ingredient in recipe.ingredients) {
      if (!ingredient.required && !includeOptional) {
        continue;
      }
      final resolution = registry.resolve(
        ingredient.canonicalIngredientId,
        preferredId: ingredient.canonicalIngredientId,
      );
      final canonical =
          resolution.ingredient ?? registry.resolve(ingredient.name).ingredient;
      if (canonical == null) {
        throw ShoppingDomainException(
          'unknown_recipe_ingredient',
          'Recipe ${recipe.id} references unknown ingredient '
              '${ingredient.canonicalIngredientId}.',
        );
      }
      final requiredQuantity = ingredient.quantity * scale;
      if (!requiredQuantity.isFinite || requiredQuantity < 0) {
        throw ShoppingDomainException(
          'invalid_recipe_quantity',
          'Recipe ${recipe.id} has an invalid ingredient quantity.',
        );
      }
      if (requiredQuantity <= unitEngine.precisionPolicy.zeroTolerance) {
        continue;
      }
      final targetUnitId = _purchaseUnitFor(canonical);
      final converted = unitEngine.tryConvert(
        requiredQuantity,
        fromUnit: ingredient.unit,
        toUnit: targetUnitId,
      );
      if (!converted.isSuccess) {
        throw ShoppingDomainException(
          'invalid_unit_conversion',
          'Recipe ${recipe.id} cannot convert ${ingredient.unit} to '
              '$targetUnitId for ${canonical.id}.',
        );
      }
      final current = requirements.putIfAbsent(
        canonical.id,
        () => _Requirement(unitId: targetUnitId),
      );
      current.quantity += converted.value!;
      current.recipeIds.add(recipe.id);
    }
  }

  Map<String, double> _pantryQuantities(
    List<Ingredient> pantry,
    Map<String, _Requirement> requirements, {
    required DateTime at,
  }) {
    final totals = <String, double>{};
    for (final lot in pantry) {
      if (lot.quantity <= 0 || lot.isExpiredAt(at)) {
        continue;
      }
      final rawCanonicalId = lot.canonicalIngredientId.trim();
      if (rawCanonicalId.isEmpty) {
        continue;
      }
      final canonicalId = registry.canonicalIdFor(rawCanonicalId);
      if (canonicalId == null) {
        throw ShoppingDomainException(
          'unknown_pantry_ingredient',
          'Pantry lot ${lot.id} has an unknown canonical ID.',
        );
      }
      final requirement = requirements[canonicalId];
      if (requirement == null) {
        continue;
      }
      final sourceUnit = lot.canonicalUnitId.trim().isEmpty
          ? lot.unit
          : lot.canonicalUnitId;
      final converted = unitEngine.tryConvert(
        lot.quantity,
        fromUnit: sourceUnit,
        toUnit: requirement.unitId,
      );
      if (!converted.isSuccess) {
        throw ShoppingDomainException(
          'invalid_unit_conversion',
          'Pantry lot ${lot.id} cannot convert $sourceUnit to '
              '${requirement.unitId}.',
        );
      }
      totals[canonicalId] = (totals[canonicalId] ?? 0) + converted.value!;
    }
    for (final entry in totals.entries.toList(growable: false)) {
      totals[entry.key] = _round(entry.value, requirements[entry.key]!.unitId);
    }
    return totals;
  }

  double _sumExisting(
    List<ShoppingItem> items, {
    required String targetUnitId,
  }) {
    var total = 0.0;
    for (final item in items) {
      final converted = unitEngine.tryConvert(
        item.quantity,
        fromUnit: item.unitId,
        toUnit: targetUnitId,
      );
      if (!converted.isSuccess) {
        throw ShoppingDomainException(
          'invalid_unit_conversion',
          'Shopping item ${item.id} cannot convert ${item.unitId} to '
              '$targetUnitId.',
        );
      }
      total += converted.value!;
    }
    return _round(total, targetUnitId);
  }

  String _purchaseUnitFor(CanonicalIngredient canonical) {
    final unitId = unitEngine.resolveUnitId(canonical.defaultPurchaseUnitId);
    if (unitId == null) {
      throw ShoppingDomainException(
        'unknown_purchase_unit',
        'Canonical ingredient ${canonical.id} has an unknown purchase unit.',
      );
    }
    return unitId;
  }

  double _round(double value, String unitId) {
    return unitEngine.precisionPolicy.apply(
      value,
      decimalPlaces: unitEngine.resolveUnit(unitId)?.decimalPlaces,
    );
  }
}

class _Requirement {
  _Requirement({required this.unitId});

  final String unitId;
  double quantity = 0;
  final Set<String> recipeIds = <String>{};
}

List<String> _references(List<ShoppingItem> items) {
  final values = <String>{
    for (final item in items) ...item.sourceReferenceIds,
  }.toList()..sort();
  return values;
}

double _positive(double value) => value > 0 ? value : 0;

int _compareItems(ShoppingItem first, ShoppingItem second) {
  final status = first.status.index.compareTo(second.status.index);
  if (status != 0) {
    return status;
  }
  final ingredient = first.canonicalIngredientId.compareTo(
    second.canonicalIngredientId,
  );
  return ingredient != 0 ? ingredient : first.id.compareTo(second.id);
}
