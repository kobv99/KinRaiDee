import '../entities/ingredient_substitution.dart';

abstract interface class IngredientSubstitutionRepository {
  Future<List<IngredientSubstitution>> getAll();
}
