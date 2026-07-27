/// Provides deterministic fallback artwork for bundled canonical ingredients.
///
/// Master-data records may override this with an explicit `emoji`. Keeping the
/// fallback in the domain layer lets every feature resolve artwork from the
/// canonical identity instead of presentation-specific name checks.
class IngredientArtworkPolicy {
  const IngredientArtworkPolicy();

  static const Map<String, String> _byId = <String, String>{
    'pork': '🐷',
    'minced_pork': '🐷',
    'pork_belly': '🐷',
    'pork_neck': '🐷',
    'chicken': '🐔',
    'chicken_breast': '🐔',
    'beef': '🥩',
    'egg': '🥚',
    'duck_egg': '🥚',
    'salted_egg': '🥚',
    'tofu': '◻️',
    'shrimp': '🦐',
    'squid': '🦑',
    'shellfish': '🦪',
    'fish': '🐟',
    'mackerel': '🐟',
    'catfish': '🐟',
    'tilapia': '🐟',
    'sea_bass': '🐟',
    'broccoli': '🥦',
    'carrot': '🥕',
    'corn': '🌽',
    'mushroom': '🍄',
    'tomato': '🍅',
    'cucumber': '🥒',
    'onion': '🧅',
    'potato': '🥔',
    'garlic': '🧄',
    'chili': '🌶️',
    'ginger': '🫚',
    'lime': '🍋',
    'rice': '🍚',
    'glass_noodle': '🍜',
    'cooking_oil': '🫗',
    'coconut_milk': '🥥',
  };

  String forDefinition({
    required String canonicalId,
    required String category,
  }) {
    return _byId[canonicalId] ??
        switch (category) {
          'protein' => '🥩',
          'seafood' => '🐟',
          'vegetable' => '🥬',
          'herb' => '🌿',
          'staple' => '🍚',
          'seasoning' => '🧂',
          _ => '🍽️',
        };
  }
}
