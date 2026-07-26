import '../../../../core/models/ingredient.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/repositories/pantry_repository.dart';

class HivePantryRepository implements PantryRepository {
  const HivePantryRepository();

  @override
  List<Ingredient> getIngredients() {
    return StorageService.loadIngredients();
  }

  @override
  Set<String> getFavoriteIngredientNames() {
    return StorageService.loadFavoriteIngredientNames();
  }

  @override
  Future<void> saveFavoriteIngredientNames(Set<String> names) {
    return StorageService.saveFavoriteIngredientNames(names);
  }
}
