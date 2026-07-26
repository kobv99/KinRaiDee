import '../../../../core/models/ingredient.dart';

abstract interface class PantryRepository {
  List<Ingredient> getIngredients();

  Set<String> getFavoriteIngredientNames();

  Future<void> saveFavoriteIngredientNames(Set<String> names);
}
