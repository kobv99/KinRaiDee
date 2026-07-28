import '../domain/ingredients/canonical_ingredient.dart';
import '../domain/ingredients/canonical_ingredient_registry.dart';
import '../models/ingredient.dart';

class IngredientPresentation {
  IngredientPresentation._();

  static CanonicalIngredient? canonical(
    Ingredient ingredient,
    CanonicalIngredientRegistry? registry,
  ) {
    if (registry == null) {
      return null;
    }

    final stableId = ingredient.canonicalIngredientId.trim();
    if (stableId.isNotEmpty) {
      final canonical = registry.byId(stableId);
      if (canonical != null) {
        return canonical;
      }
    }

    return registry.resolve(ingredient.name).ingredient;
  }

  static String emoji(
    Ingredient ingredient,
    CanonicalIngredientRegistry? registry,
  ) {
    final canonicalEmoji = canonical(ingredient, registry)?.emoji.trim() ?? '';
    if (canonicalEmoji.isNotEmpty) {
      return canonicalEmoji;
    }

    final stored = ingredient.emoji.trim();
    return stored.isEmpty ? '🍽️' : stored;
  }

  static String category(
    Ingredient ingredient,
    CanonicalIngredientRegistry? registry,
  ) {
    final canonicalCategory = canonical(ingredient, registry)?.category.trim();
    final storedCategory = ingredient.category.trim();
    return localizedCategory(
      canonicalCategory == null || canonicalCategory.isEmpty
          ? storedCategory
          : canonicalCategory,
    );
  }

  static String localizedCategory(String category) {
    final normalized = category.trim().toLowerCase();
    return switch (normalized) {
      'seasoning' => 'เครื่องปรุง',
      'protein' => 'โปรตีน',
      'seafood' => 'อาหารทะเล',
      'vegetable' => 'ผัก',
      'fruit' => 'ผลไม้',
      'dairy' => 'ผลิตภัณฑ์นม',
      'grain' => 'ธัญพืช',
      'staple' => 'วัตถุดิบหลัก',
      _ => category.trim().isEmpty ? 'อื่น ๆ' : category.trim(),
    };
  }
}
