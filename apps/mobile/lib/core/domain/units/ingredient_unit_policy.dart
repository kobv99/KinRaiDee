import '../ingredients/canonical_ingredient.dart';

class IngredientUnitRecommendation {
  IngredientUnitRecommendation({
    required this.preferredUnitId,
    required List<String> recommendedUnitIds,
    required this.family,
  }) : recommendedUnitIds = List<String>.unmodifiable(recommendedUnitIds);

  final String preferredUnitId;
  final List<String> recommendedUnitIds;
  final IngredientUnitFamily family;
}

/// Defines practical unit choices without leaking ingredient-name checks into
/// presentation code.
class IngredientUnitPolicy {
  const IngredientUnitPolicy();

  static const Set<String> _fishIds = <String>{
    'fish',
    'mackerel',
    'catfish',
    'tilapia',
    'sea_bass',
  };
  static const Set<String> _eggIds = <String>{'egg', 'duck_egg', 'salted_egg'};
  static const Set<String> _liquidIds = <String>{
    'cooking_oil',
    'fish_sauce',
    'soy_sauce',
    'dark_soy_sauce',
    'oyster_sauce',
    'seasoning_sauce',
    'coconut_milk',
    'tamarind_sauce',
  };
  static const Set<String> _dryIds = <String>{
    'sugar',
    'salt',
    'pepper',
    'breadcrumbs',
    'cashew',
    'flour',
    'glass_noodle',
  };
  static const Set<String> _cannedIds = <String>{
    'canned_fish',
    'canned_tuna',
    'canned_food',
  };

  IngredientUnitRecommendation forDefinition({
    required String canonicalId,
    required String category,
    required String defaultInventoryUnitId,
    required String defaultPurchaseUnitId,
    String? parentId,
  }) {
    if (_fishIds.contains(canonicalId) || parentId == 'fish') {
      return _recommend(
        preferred: 'whole',
        units: const <String>['whole', 'piece', 'gram', 'kilogram'],
        family: IngredientUnitFamily.fish,
      );
    }
    if (_eggIds.contains(canonicalId)) {
      return _recommend(
        preferred: 'egg',
        units: const <String>['egg', 'pack'],
        family: IngredientUnitFamily.egg,
      );
    }
    if (canonicalId == 'tofu') {
      return _recommend(
        preferred: 'block',
        units: const <String>['block', 'pack', 'piece'],
        family: IngredientUnitFamily.tofu,
      );
    }
    if (canonicalId == 'garlic') {
      return _recommend(
        preferred: 'clove',
        units: const <String>['clove', 'bulb', 'gram', 'kilogram'],
        family: IngredientUnitFamily.garlic,
      );
    }
    if (_cannedIds.contains(canonicalId)) {
      return _recommend(
        preferred: 'can',
        units: const <String>['can', 'gram'],
        family: IngredientUnitFamily.canned,
      );
    }
    if (_liquidIds.contains(canonicalId)) {
      return _recommend(
        preferred: canonicalId == 'cooking_oil'
            ? 'bottle'
            : _preferredIfAllowed(defaultPurchaseUnitId, const <String>[
                'bottle',
                'milliliter',
                'liter',
              ], fallback: 'bottle'),
        units: const <String>['bottle', 'milliliter', 'liter'],
        family: IngredientUnitFamily.liquid,
      );
    }
    if (_dryIds.contains(canonicalId) || category == 'staple') {
      return _recommend(
        preferred: _preferredIfAllowed(defaultPurchaseUnitId, const <String>[
          'bag',
          'gram',
          'kilogram',
        ], fallback: 'bag'),
        units: const <String>['bag', 'gram', 'kilogram'],
        family: IngredientUnitFamily.dryIngredient,
      );
    }
    if (category == 'protein' || category == 'seafood') {
      return _recommend(
        preferred: _preferredIfAllowed(defaultPurchaseUnitId, const <String>[
          'piece',
          'gram',
          'kilogram',
        ], fallback: 'kilogram'),
        units: const <String>['piece', 'gram', 'kilogram'],
        family: IngredientUnitFamily.meat,
      );
    }
    if (category == 'vegetable' || category == 'herb') {
      return _recommend(
        preferred: _preferredIfAllowed(defaultInventoryUnitId, const <String>[
          'bunch',
          'stalk',
          'bag',
          'gram',
          'kilogram',
        ], fallback: 'gram'),
        units: const <String>['bunch', 'stalk', 'bag', 'gram', 'kilogram'],
        family: IngredientUnitFamily.vegetable,
      );
    }
    if (category == 'seasoning') {
      return _recommend(
        preferred: _preferredIfAllowed(defaultPurchaseUnitId, const <String>[
          'bottle',
          'milliliter',
          'liter',
        ], fallback: 'bottle'),
        units: const <String>['bottle', 'milliliter', 'liter'],
        family: IngredientUnitFamily.liquid,
      );
    }
    return fallback;
  }

  IngredientUnitRecommendation get fallback {
    return _recommend(
      preferred: 'piece',
      units: const <String>['piece', 'gram', 'kilogram'],
      family: IngredientUnitFamily.generic,
    );
  }

  IngredientUnitRecommendation _recommend({
    required String preferred,
    required List<String> units,
    required IngredientUnitFamily family,
  }) {
    return IngredientUnitRecommendation(
      preferredUnitId: preferred,
      recommendedUnitIds: units,
      family: family,
    );
  }

  String _preferredIfAllowed(
    String candidate,
    List<String> allowed, {
    required String fallback,
  }) {
    return allowed.contains(candidate) ? candidate : fallback;
  }
}
