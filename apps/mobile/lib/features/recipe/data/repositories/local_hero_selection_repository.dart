import '../../../../core/services/storage_service.dart';
import '../../domain/repositories/hero_selection_repository.dart';

class LocalHeroSelectionRepository implements HeroSelectionRepository {
  const LocalHeroSelectionRepository();

  @override
  String? loadPinnedIngredientKey() {
    return StorageService.loadPinnedHeroIngredientKey();
  }

  @override
  Future<void> savePinnedIngredientKey(String key) {
    return StorageService.savePinnedHeroIngredientKey(key);
  }

  @override
  Future<void> clearPinnedIngredientKey() {
    return StorageService.clearPinnedHeroIngredientKey();
  }
}
