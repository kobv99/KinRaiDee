import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/providers/pantry_provider.dart';
import 'package:mobile/features/recipe/application/recipe_missing_shopping_controller.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/presentation/providers/recipe_shopping_provider.dart';
import 'package:mobile/features/shopping/application/shopping_providers.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_category.dart';

import '../../../support/shopping_ui_test_support.dart';

void main() {
  test(
    'adds every missing ingredient in one canonical duplicate-safe action',
    () async {
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
          testPantryLot(
            id: 'rice-lot',
            canonicalId: 'rice',
            name: 'Rice',
            quantity: 0.2,
            unit: 'kilogram',
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
    },
  );

  test('second add is a no-op and does not duplicate Shopping items', () async {
    final now = DateTime.utc(2026, 7, 28, 8);
    final harness = await ShoppingUiHarness.create(
      at: now,
      pantry: [
        testPantryLot(
          id: 'rice-lot',
          canonicalId: 'rice',
          name: 'Rice',
          quantity: 0.2,
          unit: 'kilogram',
          now: now,
        ),
      ],
    );
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
    expect(items.map((item) => item.canonicalIngredientId).toSet(), <String>{
      'egg',
      'rice',
    });
  });

  test(
    'explicit user choice can generate Shopping outside recommendations',
    () async {
      final now = DateTime.utc(2026, 7, 28, 8);
      final harness = await ShoppingUiHarness.create(
        at: now,
        pantry: [
          testPantryLot(
            id: 'egg-lot',
            canonicalId: 'egg',
            name: 'Egg',
            quantity: 1,
            unit: 'piece',
            now: now,
          ),
        ],
      );
      addTearDown(harness.dispose);

      final result = await harness.container
          .read(recipeMissingShoppingControllerProvider)!
          .addMissingIngredients(recipe: _recipe, servings: 2);

      expect(result.outcome, RecipeMissingShoppingOutcome.committed);
      expect(result.changedItemCount, 2);
      expect(
        (await harness.lists()).single.items
            .map((item) => item.canonicalIngredientId)
            .toSet(),
        <String>{'egg', 'rice'},
      );
    },
  );

  test('incompatible Pantry units do not block Shopping generation', () async {
    final now = DateTime.utc(2026, 7, 28, 8);
    final harness = await ShoppingUiHarness.create(
      at: now,
      pantry: [
        testPantryLot(
          id: 'rice-wrong-unit',
          canonicalId: 'rice',
          name: 'Rice',
          quantity: 1,
          unit: 'piece',
          now: now,
        ),
      ],
    );
    addTearDown(harness.dispose);

    final result = await harness.container
        .read(recipeMissingShoppingControllerProvider)!
        .addMissingIngredients(recipe: _recipe, servings: 2);

    expect(result.outcome, RecipeMissingShoppingOutcome.committed);
    expect(
      (await harness.lists()).single.items
          .map((item) => item.canonicalIngredientId)
          .toSet(),
      <String>{'egg', 'rice'},
    );
  });

  test(
    'canonical child Pantry satisfies a parent Recipe requirement',
    () async {
      final now = DateTime.utc(2026, 7, 28, 8);
      final harness = await ShoppingUiHarness.create(
        at: now,
        pantry: [
          testPantryLot(
            id: 'minced-pork-lot',
            canonicalId: 'minced_pork',
            name: 'หมูสับ',
            quantity: 200,
            unit: 'gram',
            now: now,
          ),
        ],
      );
      addTearDown(harness.dispose);

      final result = await harness.container
          .read(recipeMissingShoppingControllerProvider)!
          .addMissingIngredients(recipe: _porkRecipe, servings: 2);

      expect(result.outcome, RecipeMissingShoppingOutcome.noMissingIngredients);
      expect(await harness.lists(), isEmpty);
    },
  );

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

  test('failed durable write leaves Shopping unchanged', () async {
    final now = DateTime.utc(2026, 7, 28, 8);
    final harness = await ShoppingUiHarness.create(
      at: now,
      pantry: [
        testPantryLot(
          id: 'rice-lot',
          canonicalId: 'rice',
          name: 'Rice',
          quantity: 0.2,
          unit: 'kilogram',
          now: now,
        ),
      ],
    );
    addTearDown(harness.dispose);
    harness.store.failEnvelopeWrites = true;

    final result = await harness.container
        .read(recipeMissingShoppingControllerProvider)!
        .addMissingIngredients(recipe: _recipe, servings: 2);

    expect(result.outcome, RecipeMissingShoppingOutcome.failed);
    expect(result.changedItemCount, 0);
    expect(await harness.lists(), isEmpty);
    expect(harness.container.read(pantryProvider), hasLength(1));
  });

  test(
    'purchased Recipe shortage merges the existing canonical Pantry record',
    () async {
      final now = DateTime.utc(2026, 7, 28, 8);
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
      );
      addTearDown(harness.dispose);

      final added = await harness.container
          .read(recipeMissingShoppingControllerProvider)!
          .addMissingIngredients(recipe: _eggRecipe, servings: 2);
      expect(added.isSuccess, isTrue);
      final list = (await harness.lists()).single;
      final item = list.items.single;
      expect(item.quantity, 4);

      final completed = await harness.container
          .read(shoppingCompletionControllerProvider)
          .complete(
            listId: list.id,
            expectedListRevision: list.revision,
            itemId: item.id,
            createdAt: now.add(const Duration(minutes: 1)),
          );

      expect(completed.isSuccess, isTrue);
      final pantry = harness.container.read(pantryProvider);
      expect(pantry, hasLength(1));
      expect(pantry.single.id, 'egg-lot');
      expect(pantry.single.canonicalIngredientId, 'egg');
      expect(pantry.single.quantity, 6);
      expect((await harness.lists()).single.items, isEmpty);
    },
  );
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
      role: RecipeIngredientRole.secondary,
      weight: 25,
    ),
    RecipeIngredient(
      id: 'rice',
      name: 'Rice',
      quantity: 1,
      unit: 'kilogram',
      role: RecipeIngredientRole.primary,
      weight: 75,
    ),
  ],
  steps: <String>[],
);

const Recipe _porkRecipe = Recipe(
  id: 'garlic-pork',
  name: 'Garlic Pork',
  category: 'test',
  servings: 2,
  heroIngredientId: 'pork',
  ingredients: <RecipeIngredient>[
    RecipeIngredient(
      id: 'pork',
      name: 'Pork',
      quantity: 200,
      unit: 'gram',
      role: RecipeIngredientRole.primary,
      weight: 100,
    ),
  ],
  steps: <String>[],
);

const Recipe _eggRecipe = Recipe(
  id: 'omelette',
  name: 'Omelette',
  category: 'test',
  servings: 2,
  heroIngredientId: 'egg',
  ingredients: <RecipeIngredient>[
    RecipeIngredient(
      id: 'egg',
      name: 'Egg',
      quantity: 6,
      unit: 'piece',
      role: RecipeIngredientRole.primary,
      weight: 100,
    ),
  ],
  steps: <String>[],
);
