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

    expect(recipes.length, greaterThanOrEqualTo(100));
    expect(ids.length, recipes.length);
    expect(shrimpRecipes, hasLength(20));
  });
}
