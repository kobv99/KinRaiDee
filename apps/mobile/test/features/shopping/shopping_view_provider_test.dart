import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_category.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_item.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_item_status.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_source.dart';
import 'package:mobile/features/shopping/presentation/providers/shopping_view_provider.dart';

void main() {
  final now = DateTime.utc(2026, 7, 26, 10);
  final registry = _registry();
  final units = UnitConversionEngine.standard();
  final projector = ShoppingViewProjector(
    registry: registry,
    unitEngine: units,
  );
  final egg = _item(
    id: 'egg-item',
    canonicalId: 'egg',
    name: 'Egg',
    quantity: 6,
    unit: 'piece',
    category: ShoppingCategory.protein,
    references: const <String>['omelette'],
    now: now,
  );
  final rice = _item(
    id: 'rice-item',
    canonicalId: 'rice',
    name: 'Rice',
    quantity: 1,
    unit: 'kilogram',
    category: ShoppingCategory.grains,
    references: const <String>['fried-rice'],
    status: ShoppingItemStatus.purchased,
    now: now,
  );

  test('search matches canonical, alias, localized, and keyword names', () {
    for (final query in <String>[
      'egg',
      'chicken egg',
      'ไข่ไก่',
      'breakfast protein',
    ]) {
      final result = projector.project(<ShoppingItem>[
        egg,
        rice,
      ], ShoppingViewState(query: query));
      expect(result.active, <ShoppingItem>[egg], reason: query);
      expect(result.completed, isEmpty, reason: query);
    }
  });

  test('filters completion, category, and Recipe source together', () {
    final result = projector.project(
      <ShoppingItem>[egg, rice],
      const ShoppingViewState(
        completion: ShoppingCompletionFilter.completed,
        category: ShoppingCategory.grains,
        recipeId: 'fried-rice',
      ),
    );

    expect(result.active, isEmpty);
    expect(result.completed, <ShoppingItem>[rice]);
  });

  test('sort options are deterministic', () {
    final items = <ShoppingItem>[rice, egg];
    expect(
      projector
          .project(
            items,
            const ShoppingViewState(sort: ShoppingSortOption.alphabetical),
          )
          .active,
      <ShoppingItem>[egg],
    );
    final byRecipe = projector.project(
      items,
      const ShoppingViewState(sort: ShoppingSortOption.recipeSource),
      recipeNames: const <String, String>{
        'omelette': 'A Omelette',
        'fried-rice': 'B Fried rice',
      },
    );
    expect(byRecipe.active.single, egg);
    expect(byRecipe.completed.single, rice);
  });

  test('Pantry availability converts units and ignores expired lots', () {
    final pantry = <Ingredient>[
      _lot(
        id: 'rice-g',
        canonicalId: 'rice',
        quantity: 250,
        unit: 'gram',
        now: now,
      ),
      _lot(
        id: 'rice-kg',
        canonicalId: 'rice',
        quantity: 0.5,
        unit: 'kilogram',
        now: now,
      ),
      _lot(
        id: 'expired',
        canonicalId: 'rice',
        quantity: 10,
        unit: 'kilogram',
        now: now,
        expiryDate: now.subtract(const Duration(days: 1)),
      ),
    ];

    expect(
      projector.pantryAvailability(rice, pantry, at: now),
      closeTo(0.75, 0.000001),
    );
    expect(formatShoppingQuantity(2.500), '2.5');
    expect(shoppingUnitLabel('kilogram'), 'กิโลกรัม');
    expect(shoppingUnitLabel('liter'), 'ลิตร');
    expect(shoppingUnitLabel('egg'), 'ฟอง');
    expect(shoppingCategoryLabel(ShoppingCategory.grains), 'ข้าวและธัญพืช');
  });

  test('view notifier updates and clears every filter', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(shoppingViewProvider.notifier);

    notifier
      ..setQuery('egg')
      ..setCompletion(ShoppingCompletionFilter.active)
      ..setSort(ShoppingSortOption.alphabetical)
      ..setCategory(ShoppingCategory.protein)
      ..setRecipe('omelette');
    expect(container.read(shoppingViewProvider).hasFilters, isTrue);

    notifier
      ..setCategory(null)
      ..setRecipe(null)
      ..clear();
    expect(container.read(shoppingViewProvider).hasFilters, isFalse);
    expect(
      container.read(shoppingViewProvider).sort,
      ShoppingSortOption.category,
    );
  });
}

ShoppingItem _item({
  required String id,
  required String canonicalId,
  required String name,
  required double quantity,
  required String unit,
  required ShoppingCategory category,
  required List<String> references,
  required DateTime now,
  ShoppingItemStatus status = ShoppingItemStatus.active,
}) {
  return ShoppingItem(
    id: id,
    canonicalIngredientId: canonicalId,
    displayName: name,
    quantity: quantity,
    unitId: unit,
    category: category,
    source: ShoppingSource.recipe,
    sourceReferenceIds: references,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

Ingredient _lot({
  required String id,
  required String canonicalId,
  required double quantity,
  required String unit,
  required DateTime now,
  DateTime? expiryDate,
}) {
  return Ingredient(
    id: id,
    name: canonicalId,
    category: 'test',
    emoji: 'T',
    quantity: quantity,
    unit: unit,
    expiryDate: expiryDate,
    createdAt: now,
    updatedAt: now,
    canonicalIngredientId: canonicalId,
    canonicalUnitId: unit,
    canonicalMappingStatus: CanonicalMappingStatus.mapped,
  );
}

CanonicalIngredientRegistry _registry() {
  return CanonicalIngredientRegistry(
    ingredients: <CanonicalIngredient>[
      CanonicalIngredient(
        id: 'egg',
        canonicalName: 'Egg',
        localizedNames: const <String, String>{'th': 'ไข่ไก่'},
        aliases: const <String>['chicken egg'],
        searchKeywords: const <String>['breakfast protein'],
        category: 'protein',
        defaultStorageType: IngredientStorageType.refrigerated,
        defaultPurchaseUnitId: 'piece',
        defaultInventoryUnitId: 'piece',
      ),
      CanonicalIngredient(
        id: 'rice',
        canonicalName: 'Rice',
        localizedNames: const <String, String>{'th': 'ข้าว'},
        aliases: const <String>[],
        searchKeywords: const <String>['grain'],
        category: 'grain',
        defaultStorageType: IngredientStorageType.pantry,
        defaultPurchaseUnitId: 'kilogram',
        defaultInventoryUnitId: 'gram',
      ),
    ],
  );
}
