import '../entities/recipe.dart';

abstract interface class RecipeRepository {
  Future<List<Recipe>> getRecipes();

  Set<String> getFavoriteRecipeIds();

  Future<void> saveFavoriteRecipeIds(Set<String> ids);
}
