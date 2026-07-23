import '../entities/recipe.dart';

abstract interface class RecipeRepository {
  Future<List<Recipe>> getRecipes();
}
