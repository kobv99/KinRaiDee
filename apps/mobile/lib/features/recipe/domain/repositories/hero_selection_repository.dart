abstract interface class HeroSelectionRepository {
  String? loadPinnedIngredientKey();

  Future<void> savePinnedIngredientKey(String key);

  Future<void> clearPinnedIngredientKey();
}
