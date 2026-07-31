import '../../../../core/services/storage_service.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../datasources/local_recipe_datasource.dart';

class LocalRecipeRepository implements RecipeRepository {
  const LocalRecipeRepository(this._dataSource);

  final LocalRecipeDataSource _dataSource;

  @override
  Future<List<Recipe>> getRecipes() {
    return _dataSource.loadRecipes();
  }

  @override
  Set<String> getFavoriteRecipeIds() {
    return StorageService.loadFavoriteRecipeIds();
  }

  @override
  Future<void> saveFavoriteRecipeIds(Set<String> ids) {
    return StorageService.saveFavoriteRecipeIds(ids);
  }
}
