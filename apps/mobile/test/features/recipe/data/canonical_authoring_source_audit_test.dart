import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';
import 'package:mobile/features/recipe/data/pantry_catalog_canonical_definitions.dart';

/// Guards the single-authoritative-source rule: an animal/seafood canonical
/// id must never be defined in both `thai_ingredients.json` and the code
/// fallback seeds. Uses the public [fallbackDefinitionIds] accessor rather
/// than inspecting the private `_seeds` list directly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('JSON-authored ids and code fallback-seed ids are disjoint', () async {
    final jsonIngredients = await IngredientCatalog().load();
    final jsonIds = jsonIngredients.map((ingredient) => ingredient.id).toSet();
    final fallbackIds = fallbackDefinitionIds().toSet();

    final overlap = jsonIds.intersection(fallbackIds);

    expect(
      overlap,
      isEmpty,
      reason:
          'These ids are authored in both assets/ingredients/thai_ingredients.json '
          'and the code fallback seeds: $overlap. Animal/seafood definitions must '
          'have exactly one authoritative source.',
    );
  });

  test('no animal/seafood MVP node remains authored only in the code fallback '
      'seeds', () async {
    const mvpIds = <String>{
      'pork_family', 'pork', 'minced_pork', 'pork_belly', 'pork_neck',
      'pork_tenderloin', 'pork_ribs', 'moo_yor', 'pork_liver', //
      'chicken_family', 'chicken', 'chicken_breast', 'chicken_thigh',
      'chicken_drumstick', 'chicken_wing', 'minced_chicken', 'chicken_liver',
      'chicken_gizzard', //
      'beef_family', 'beef', 'minced_beef', 'beef_shank', //
      'fish_family', 'fish', 'fish_fillet', 'freshwater_fish_family',
      'tilapia', 'catfish', 'snakehead', 'sea_fish_family', 'sea_bass',
      'mackerel', 'salmon', //
      'shrimp_family', 'shrimp', //
      'crab_family', 'crab', 'imitation_crab', //
      'squid_family', 'squid', //
      'shellfish_family', 'shellfish',
    };

    final jsonIngredients = await IngredientCatalog().load();
    final jsonIds = jsonIngredients.map((ingredient) => ingredient.id).toSet();
    final fallbackIds = fallbackDefinitionIds().toSet();

    final missingFromJson = mvpIds.difference(jsonIds);
    expect(
      missingFromJson,
      isEmpty,
      reason: 'MVP taxonomy ids missing from the JSON asset: $missingFromJson',
    );

    final stillOnlyInCode = mvpIds
        .intersection(fallbackIds)
        .difference(jsonIds);
    expect(
      stillOnlyInCode,
      isEmpty,
      reason:
          'MVP taxonomy ids still authored only in code seeds: $stillOnlyInCode',
    );
  });
}
