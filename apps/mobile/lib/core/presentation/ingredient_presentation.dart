import '../domain/ingredients/canonical_ingredient_registry.dart';
import '../models/ingredient.dart';

class IngredientPresentation {
  IngredientPresentation._();

  static String emoji(
    Ingredient ingredient,
    CanonicalIngredientRegistry? registry,
  ) {
    final stored = ingredient.emoji.trim();
    if (stored.isNotEmpty) {
      return stored;
    }
    final canonicalId = registry?.canonicalIdFor(
      ingredient.canonicalIngredientId,
    );
    final canonical = canonicalId == null ? null : registry?.byId(canonicalId);
    final canonicalEmoji = canonical?.emoji.trim() ?? '';
    return canonicalEmoji.isEmpty ? '🍽️' : canonicalEmoji;
  }
}
