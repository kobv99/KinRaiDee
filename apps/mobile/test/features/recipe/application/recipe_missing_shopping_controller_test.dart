import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/presentation/providers/recipe_shopping_provider.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_category.dart';

import '../../../support/shopping_ui_test_support.dart';

void main() {
  test('adds every missing ingredient in one canonical duplicate-safe action', () async {
    final now = DateTime.utc(2026, 7, 28, 8);
    final existingEgg = testShoppingItem(
      id: 'egg-existing',
      canonicalId: 'egg',
      name: 'Egg',
      quantity: 1,
      unit: 'piece',
      category: ShoppingCategory.protein,
      recipeIds: const <String>['older-recipe'],
      now: now,
    );
    final harness = await ShoppingUiHarness.create(
      at: now,
      pantry: [
        testPantryLot(
          id: 'egg-lot',
          canonicalId: 'egg',
          name: 'Egg',
          quantity: 2,
          unit: 'piece',
          now: now,
        ),
      ],
      list: testShoppingList(now: now, items: [existingEgg]),
    );
    addTearDown(harness.dispose);

    final controller = harness.container.read(
      recipeMissingShoppingControllerProvider,
    );
    final result = await controller!.addMissingIngredients(
      recipe: _recipe,
      servings: 2,
    );

    expect(result.isSuccess, isTrue);
    expect(result.changedItemCount, 2);
    final items = (await harness.lists()).single.items;
    expect(items, hasLength(2));
    expect(
      items.where((item) => item.canonicalIngredientId == 'egg'),
      hasLength(1),
    );
    expect(
      items
          .where((item) => item.canonicalIngredientId == 'egg')
          .single
          .quantity,
      4,
    );
    expect(
      items.where((item) => item.canonicalIngredientId == 'rice'),
      hasLength(1),
    );
  });

  test('second add is a no-op and does not duplicate Shopping items', () async {
    final now = DateTime.utc(2026, 7, 28, 8);
    final harness = await ShoppingUiHarness.create(at: now);
    addTearDown(harness.dispose);
    final controller = harness.container.read(
      recipeMissingShoppingControllerProvider,
    )!;

    final first = await controller.addMissingIngredients(
      recipe: _recipe,
      servings: 2,
    );
    final second = await controller.addMissingIngredients(
      recipe: _recipe,
      servings: 2,
    );

    expect(first.isSuccess, isTrue);
    expect(second.isSuccess, isTrue);
    expect(second.changedItemCount, 0);
    final items = (await harness.lists()).single.items;
    expect(items, hasLength(2));
    expect(
      items.map((item) => item.canonicalIngredientId).toSet(),
      <String>{'egg', 'rice'},
    );
  });

  test('fully ready recipe does not create an empty Shopping list', () async {
    final now = DateTime.utc(2026, 7, 28, 8);
    final harness = await ShoppingUiHarness.create(
      at: now,
      pantry: [
        testPantryLot(
          id: 'egg-lot',
          canonicalId: 'egg',
          name: 'Egg',
          quantity: 6,
          unit: 'piece',
          now: now,
        ),
        testPantryLot(
          id: 'rice-lot',
          canonicalId: 'rice',
          name: 'Rice',
          quantity: 1,
          unit: 'kilogram',
          now: now,
        ),
      ],
    );
    addTearDown(harness.dispose);

    final result = await harness.container
        .read(recipeMissingShoppingControllerProvider)!
        .addMissingIngredients(recipe: _recipe, servings: 2);

    expect(result.isSuccess, isTrue);
    expect(result.changedItemCount, 0);
    expect(await harness.lists(), isEmpty);
  });
}

const Recipe _recipe = Recipe(
  id: 'fried-rice',
  name: 'Fried Rice',
  category: 'test',
  servings: 2,
  heroIngredientId: 'rice',
  ingredients: <RecipeIngredient>[
    RecipeIngredient(
      id: 'egg',
      name: 'Egg',
      quantity: 6,
      unit: 'piece',
    ),
    RecipeIngredient(
      id: 'rice',
      name: 'Rice',
      quantity: 1,
      unit: 'kilogram',
    ),
  ],
  steps: <String>[],
);
