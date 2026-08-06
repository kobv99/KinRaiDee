import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';

/// Every alias that used to live on a `pantry_catalog_canonical_definitions.dart`
/// code seed must still resolve to the same canonical id now that the seed
/// entry has been removed and the id is authored directly in
/// `assets/ingredients/thai_ingredients.json` instead. This is a pure
/// id-continuity check — it intentionally does not care whether the
/// underlying Thai meaning changed (see chicken_thigh), only that the
/// alias -> id mapping itself was not silently dropped during the move.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every migrated seed alias resolves to the same canonical id', () async {
    final registry = await IngredientCatalog().loadRegistry();

    const expectedResolutions = <String, String>{
      // duck
      'duck': 'duck',
      'เนื้อเป็ด': 'duck',
      'เป็ดสด': 'duck',
      // chicken_thigh / chicken_wing (ids unchanged by the migration)
      'chicken thigh': 'chicken_thigh',
      'chicken thighs': 'chicken_thigh',
      'chicken wing': 'chicken_wing',
      'chicken wings': 'chicken_wing',
      // salmon
      'salmon': 'salmon',
      'แซลมอน': 'salmon',
      // crab
      'crab': 'crab',
      // เนื้อปู was an alias of crab at the time this id-continuity check
      // was written; the Full Animal & Seafood Taxonomy manifest later
      // named it as its own of the 114 specific approved entries, so it
      // now has its own id, crab_meat (see the semantic migration rule
      // that moves any pre-existing crab/เนื้อปู record along with it).
      'เนื้อปู': 'crab_meat',
      // meatball / sausage / ham / bacon
      'meatball': 'meatball',
      'meatballs': 'meatball',
      'sausage': 'sausage',
      'sausages': 'sausage',
      'ham': 'ham',
      'bacon': 'bacon',
      // moo_yor
      'moo yor': 'moo_yor',
      'vietnamese pork sausage': 'moo_yor',
      // imitation_crab
      'imitation crab': 'imitation_crab',
      'crab stick': 'imitation_crab',
      'crab sticks': 'imitation_crab',
      // canned_fish / canned_tuna
      'canned fish': 'canned_fish',
      'canned tuna': 'canned_tuna',
      'tuna can': 'canned_tuna',
    };

    final failures = <String>[];
    expectedResolutions.forEach((alias, expectedId) {
      final resolvedId = registry.resolve(alias).ingredient?.id;
      if (resolvedId != expectedId) {
        failures.add('"$alias" resolved to $resolvedId, expected $expectedId');
      }
    });

    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
