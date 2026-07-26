import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_category.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_item.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_list.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_source.dart';
import 'package:mobile/features/shopping/domain/services/shopping_draft_builder.dart';
import 'package:mobile/features/shopping/domain/services/shopping_engine.dart';

void main() {
  final now = DateTime.utc(2026, 7, 27, 9);
  final registry = _registry();
  final units = UnitConversionEngine.standard();
  final engine = ShoppingEngine(registry: registry, unitEngine: units);

  test(
    'aggregates multiple Recipes and units before subtracting Pantry once',
    () {
      final result = engine.generate(
        listId: 'weekly',
        name: 'Weekly',
        recipes: <ShoppingRecipeRequest>[
          ShoppingRecipeRequest(
            recipe: _recipe(
              id: 'grill',
              ingredientId: 'Chicken Breast',
              quantity: 500,
              unit: 'gram',
            ),
            servings: 2,
          ),
          ShoppingRecipeRequest(
            recipe: _recipe(
              id: 'curry',
              ingredientId: 'อกไก่',
              quantity: 1,
              unit: 'kilogram',
            ),
            servings: 2,
          ),
        ],
        pantry: <Ingredient>[
          _pantry(
            id: 'chicken-lot',
            canonicalId: 'chicken',
            quantity: 0.4,
            unit: 'kilogram',
            now: now,
          ),
        ],
        generatedAt: now,
      );

      expect(result.recipeCount, 2);
      expect(result.aggregatedIngredientCount, 1);
      expect(result.list.items, hasLength(1));
      final item = result.list.items.single;
      expect(item.canonicalIngredientId, 'chicken');
      expect(item.unitId, 'kilogram');
      expect(item.quantity, 1.1);
      expect(item.sourceReferenceIds, <String>['curry', 'grill']);
    },
  );

  test('ignores ingredients fully covered by Pantry', () {
    final result = engine.generate(
      listId: 'covered',
      name: 'Covered',
      recipes: <ShoppingRecipeRequest>[
        ShoppingRecipeRequest(
          recipe: _recipe(
            id: 'omelette',
            ingredientId: 'egg',
            quantity: 4,
            unit: 'piece',
          ),
          servings: 2,
        ),
      ],
      pantry: <Ingredient>[
        _pantry(
          id: 'egg-lot',
          canonicalId: 'egg',
          quantity: 6,
          unit: 'piece',
          now: now,
        ),
      ],
      generatedAt: now,
    );

    expect(result.list.items, isEmpty);
    expect(result.missingIngredientCount, 0);
  });

  test('merges duplicate existing active entries by canonical identity', () {
    final existing = ShoppingList(
      id: 'weekly',
      name: 'Weekly',
      items: <ShoppingItem>[
        _shoppingItem(id: 'a', quantity: 500, unit: 'gram', now: now),
        _shoppingItem(id: 'b', quantity: 0.5, unit: 'kilogram', now: now),
      ],
      createdAt: now,
      updatedAt: now,
    );

    final result = engine.generate(
      listId: 'weekly',
      name: 'Weekly',
      recipes: <ShoppingRecipeRequest>[
        ShoppingRecipeRequest(
          recipe: _recipe(
            id: 'family-meal',
            ingredientId: 'chicken',
            quantity: 2,
            unit: 'kilogram',
          ),
          servings: 2,
        ),
      ],
      pantry: <Ingredient>[
        _pantry(
          id: 'pantry-chicken',
          canonicalId: 'chicken',
          quantity: 0.25,
          unit: 'kilogram',
          now: now,
        ),
      ],
      existingList: existing,
      generatedAt: now.add(const Duration(minutes: 1)),
    );

    expect(result.list.items, hasLength(1));
    expect(result.list.items.single.id, 'a');
    expect(result.list.items.single.unitId, 'kilogram');
    expect(result.list.items.single.quantity, 1.75);
  });

  test('preserves larger manual Shopping intent during regeneration', () {
    final manual = ShoppingItemFactory(registry: registry, unitEngine: units)
        .create(
          id: 'manual-chicken',
          canonicalIngredientId: 'chicken',
          quantity: 3,
          unit: 'kilogram',
          source: ShoppingSource.manual,
          createdAt: now,
        );
    final existing = ShoppingList(
      id: 'weekly',
      name: 'Weekly',
      items: <ShoppingItem>[manual],
      createdAt: now,
      updatedAt: now,
    );

    final result = engine.generate(
      listId: 'weekly',
      name: 'Weekly',
      recipes: <ShoppingRecipeRequest>[
        ShoppingRecipeRequest(
          recipe: _recipe(
            id: 'small-meal',
            ingredientId: 'chicken',
            quantity: 1,
            unit: 'kilogram',
          ),
          servings: 2,
        ),
      ],
      pantry: const <Ingredient>[],
      existingList: existing,
      generatedAt: now,
    );

    expect(result.list.items.single.quantity, 3);
    expect(result.list.items.single.source, ShoppingSource.manual);
  });

  test('rejects unknown canonical mappings and incompatible units', () {
    expect(
      () => engine.generate(
        listId: 'invalid',
        name: 'Invalid',
        recipes: <ShoppingRecipeRequest>[
          ShoppingRecipeRequest(
            recipe: _recipe(
              id: 'unknown',
              ingredientId: 'mystery',
              quantity: 1,
              unit: 'kilogram',
            ),
            servings: 2,
          ),
        ],
        pantry: const <Ingredient>[],
        generatedAt: now,
      ),
      throwsA(
        isA<ShoppingDomainException>().having(
          (error) => error.code,
          'code',
          'unknown_recipe_ingredient',
        ),
      ),
    );

    expect(
      () => engine.generate(
        listId: 'invalid-unit',
        name: 'Invalid unit',
        recipes: <ShoppingRecipeRequest>[
          ShoppingRecipeRequest(
            recipe: _recipe(
              id: 'bad-unit',
              ingredientId: 'egg',
              quantity: 1,
              unit: 'kilogram',
            ),
            servings: 2,
          ),
        ],
        pantry: const <Ingredient>[],
        generatedAt: now,
      ),
      throwsA(
        isA<ShoppingDomainException>().having(
          (error) => error.code,
          'code',
          'invalid_unit_conversion',
        ),
      ),
    );
  });
}

Recipe _recipe({
  required String id,
  required String ingredientId,
  required double quantity,
  required String unit,
}) {
  return Recipe(
    id: id,
    name: id,
    category: 'test',
    servings: 2,
    ingredients: <RecipeIngredient>[
      RecipeIngredient(
        id: ingredientId,
        name: ingredientId,
        quantity: quantity,
        unit: unit,
      ),
    ],
    steps: const <String>[],
  );
}

Ingredient _pantry({
  required String id,
  required String canonicalId,
  required double quantity,
  required String unit,
  required DateTime now,
}) {
  return Ingredient(
    id: id,
    name: canonicalId,
    category: 'protein',
    emoji: '',
    quantity: quantity,
    unit: unit,
    createdAt: now,
    updatedAt: now,
    canonicalIngredientId: canonicalId,
    canonicalUnitId: unit,
    canonicalMappingStatus: CanonicalMappingStatus.mapped,
  );
}

ShoppingItem _shoppingItem({
  required String id,
  required double quantity,
  required String unit,
  required DateTime now,
}) {
  return ShoppingItem(
    id: id,
    canonicalIngredientId: 'chicken',
    displayName: 'Chicken',
    quantity: quantity,
    unitId: unit,
    category: ShoppingCategory.protein,
    source: ShoppingSource.recipe,
    sourceReferenceId: 'old',
    createdAt: now,
    updatedAt: now,
  );
}

CanonicalIngredientRegistry _registry() {
  return CanonicalIngredientRegistry(
    ingredients: <CanonicalIngredient>[
      CanonicalIngredient(
        id: 'chicken',
        canonicalName: 'Chicken',
        localizedNames: const <String, String>{'th': 'อกไก่'},
        aliases: const <String>['Chicken Breast'],
        searchKeywords: const <String>[],
        category: 'protein',
        defaultStorageType: IngredientStorageType.refrigerated,
        defaultPurchaseUnitId: 'kilogram',
        defaultInventoryUnitId: 'gram',
      ),
      CanonicalIngredient(
        id: 'egg',
        canonicalName: 'Egg',
        localizedNames: const <String, String>{'th': 'ไข่'},
        aliases: const <String>[],
        searchKeywords: const <String>[],
        category: 'protein',
        defaultStorageType: IngredientStorageType.refrigerated,
        defaultPurchaseUnitId: 'piece',
        defaultInventoryUnitId: 'piece',
      ),
    ],
  );
}
