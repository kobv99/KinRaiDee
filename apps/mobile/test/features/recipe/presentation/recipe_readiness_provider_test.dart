import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/presentation/providers/recipe_provider.dart';

import '../../../support/shopping_ui_test_support.dart';

void main() {
  test('every loaded recipe receives a readiness result', () async {
    final now = DateTime.utc(2026, 7, 28, 8);
    final recipes = <Recipe>[
      _recipe('egg-recipe', 'egg', 'piece'),
      _recipe('rice-recipe', 'rice', 'kilogram'),
    ];
    final harness = await ShoppingUiHarness.create(at: now, recipes: recipes);
    addTearDown(harness.dispose);

    final readiness = await harness.container.read(
      recipeReadinessListProvider.future,
    );

    expect(readiness, hasLength(recipes.length));
    expect(readiness.map((item) => item.recipe.id).toSet(), {
      'egg-recipe',
      'rice-recipe',
    });
    expect(readiness.every((item) => item.scorePercent == 0), isTrue);
  });
}

Recipe _recipe(String id, String ingredientId, String unit) {
  return Recipe(
    id: id,
    name: id,
    category: 'test',
    servings: 1,
    heroIngredientId: ingredientId,
    ingredients: <RecipeIngredient>[
      RecipeIngredient(
        id: ingredientId,
        name: ingredientId,
        quantity: 1,
        unit: unit,
      ),
    ],
    steps: const <String>[],
  );
}
