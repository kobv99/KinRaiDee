import '../../../../core/models/ingredient.dart';

abstract interface class PantryRepository {
  List<Ingredient> getIngredients();

  Future<void> saveIngredients(List<Ingredient> ingredients);

  Set<String> getFavoriteIngredientNames();

  Future<void> saveFavoriteIngredientNames(Set<String> names);

  Future<void> clearIngredients();
}
