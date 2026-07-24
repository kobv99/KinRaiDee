import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/data/datasources/local_recipe_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the complete local recipe database without duplicate ids', () async {
    final recipes = await const LocalRecipeDataSource().loadRecipes();
    final ids = recipes.map((recipe) => recipe.id).toSet();
    final shrimpRecipes = recipes
        .where((recipe) => recipe.resolvedHeroIngredientId == 'shrimp')
        .toList(growable: false);
    final beefRecipes = recipes
        .where((recipe) => recipe.resolvedHeroIngredientId == 'beef')
        .toList(growable: false);

    expect(recipes.length, greaterThanOrEqualTo(120));
    expect(ids.length, recipes.length);
    expect(shrimpRecipes, hasLength(20));
    expect(beefRecipes, hasLength(20));
  });

  test('every local recipe has quantities suitable for serving scaling', () async {
    final recipes = await const LocalRecipeDataSource().loadRecipes();

    for (final recipe in recipes) {
      expect(
        recipe.servings,
        greaterThan(0),
        reason: '${recipe.id} must define positive base servings',
      );
      expect(
        recipe.ingredients,
        isNotEmpty,
        reason: '${recipe.id} must contain ingredients',
      );

      for (final ingredient in recipe.ingredients) {
        expect(
          ingredient.quantity,
          greaterThan(0),
          reason: '${recipe.id}/${ingredient.id} must have positive quantity',
        );
        expect(
          ingredient.unit.trim(),
          isNotEmpty,
          reason: '${recipe.id}/${ingredient.id} must define a unit',
        );
      }
    }
  });
}