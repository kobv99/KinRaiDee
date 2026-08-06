import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/features/pantry/domain/models/ingredient_browse_facet.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';

/// Proves the 6 browse facets are a data-driven classification over the
/// real canonical registry — never a hardcoded widget list, and never a
/// source of duplicate canonical identities. Audited against the actual
/// merged registry (thai_ingredients.json plus the pantry catalog's
/// canonical-coverage definitions), not a synthetic fixture.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CanonicalIngredientRegistry registry;

  setUpAll(() async {
    registry = await IngredientCatalog().loadRegistry();
  });

  test('exposes exactly the 6 approved facets, in the approved order', () {
    expect(ingredientBrowseFacets.map((f) => f.id).toList(), <String>[
      'dry_goods',
      'processed_food',
      'ready_to_eat',
      'vegetables',
      'oils',
      'seasonings',
    ]);
    expect(ingredientBrowseFacets.map((f) => f.displayName).toList(), <String>[
      'อาหารแห้ง',
      'อาหารแปรรูป',
      'อาหารสำเร็จรูป',
      'ผัก',
      'น้ำมัน',
      'เครื่องปรุง',
    ]);
  });

  test('every facet is non-empty against the real registry — no facet is '
      'shown empty without an approved empty-state design being needed', () {
    for (final facet in ingredientBrowseFacets) {
      final members = ingredientBrowseFacetMembers(registry, facet.id);
      expect(
        members,
        isNotEmpty,
        reason: 'facet ${facet.id} has no real members',
      );
    }
  });

  test('an unknown facet id yields no members (not a crash, not the full '
      'registry)', () {
    expect(ingredientBrowseFacetMembers(registry, 'not_a_real_facet'), isEmpty);
  });

  test('dry_goods and vegetables are derived purely from category, '
      'matching the real merged registry (JSON taxonomy content plus the '
      'pantry catalog canonical-coverage definitions) exactly', () {
    final dryGoods = ingredientBrowseFacetMembers(registry, 'dry_goods');
    expect(dryGoods, hasLength(15));
    expect(dryGoods.every((i) => i.category == 'staple'), isTrue);
    expect(
      dryGoods.map((i) => i.id),
      containsAll(<String>['rice', 'instant_noodle']),
    );

    final vegetables = ingredientBrowseFacetMembers(registry, 'vegetables');
    expect(vegetables, hasLength(19));
    expect(vegetables.every((i) => i.category == 'vegetable'), isTrue);
  });

  test('processed_food matches the approved product-direction list exactly, '
      'and every member keeps its own real taxonomy ancestry', () {
    final processedFood = ingredientBrowseFacetMembers(
      registry,
      'processed_food',
    );
    expect(processedFood.map((i) => i.id).toSet(), <String>{
      'moo_yor',
      'sausage',
      'ham',
      'bacon',
      'meatball',
      'imitation_crab',
      'canned_fish',
      'canned_tuna',
    });

    // moo_yor must never be re-parented away from pork_family merely to
    // appear in this facet — the facet is an overlay, not a taxonomy edit.
    expect(registry.ancestorChainFor('moo_yor'), contains('pork_family'));
  });

  test('oils matches every real oil/fat id in the merged registry', () {
    final oils = ingredientBrowseFacetMembers(registry, 'oils');
    expect(oils.map((i) => i.id).toSet(), <String>{
      'cooking_oil',
      'rice_bran_oil',
      'olive_oil',
      'sesame_oil',
      'butter',
      'margarine',
    });
    expect(oils.every((i) => i.category == 'seasoning'), isTrue);
  });

  test('ready_to_eat includes instant_noodle plus the two canned goods — '
      'a short, hand-audited list, not every staple/processed_food id', () {
    final readyToEat = ingredientBrowseFacetMembers(registry, 'ready_to_eat');
    expect(readyToEat.map((i) => i.id).toSet(), <String>{
      'instant_noodle',
      'canned_fish',
      'canned_tuna',
    });
  });

  test('seasonings excludes all 6 oil/fat ids and every remaining member is '
      'category==seasoning', () {
    final seasonings = ingredientBrowseFacetMembers(registry, 'seasonings');
    expect(seasonings, hasLength(20));
    expect(seasonings.every((i) => i.category == 'seasoning'), isTrue);
    expect(
      seasonings.map((i) => i.id),
      isNot(
        anyElement(
          anyOf(
            'cooking_oil',
            'rice_bran_oil',
            'olive_oil',
            'sesame_oil',
            'butter',
            'margarine',
          ),
        ),
      ),
    );
  });

  test('canned_fish and canned_tuna appear in two facets by id only — the '
      'registry still holds exactly one canonical identity for each, '
      'never a duplicate', () {
    for (final id in <String>['canned_fish', 'canned_tuna']) {
      expect(
        registry.ingredients.where((i) => i.id == id),
        hasLength(1),
        reason: '$id must resolve to exactly one canonical identity',
      );
      expect(
        ingredientBrowseFacetMembers(
          registry,
          'processed_food',
        ).map((i) => i.id),
        contains(id),
      );
      expect(
        ingredientBrowseFacetMembers(registry, 'ready_to_eat').map((i) => i.id),
        contains(id),
      );
    }
  });

  test('no facet ever contains family/category nodes, only selectable '
      'ingredients', () {
    for (final facet in ingredientBrowseFacets) {
      for (final member in ingredientBrowseFacetMembers(registry, facet.id)) {
        expect(member.nodeType.name, 'ingredient');
      }
    }
  });
}
