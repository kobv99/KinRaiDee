import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';

/// Structural and content proofs for "Animal & Seafood Taxonomy MVP v1",
/// run against the real loaded registry (not synthetic fixtures) so a
/// schema-correct-but-content-incomplete state can't pass.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CanonicalIngredientRegistry registry;

  setUpAll(() async {
    registry = await IngredientCatalog().loadRegistry();
  });

  const rootFamilyIds = <String>{
    'pork_family',
    'chicken_family',
    'beef_family',
    'fish_family',
    'shrimp_family',
    'crab_family',
    'squid_family',
    'shellfish_family',
    'other_seafood_family',
  };

  test('exactly 9 root family cards exist', () {
    final roots = registry.ingredients.where(
      (ingredient) =>
          ingredient.nodeType == CanonicalIngredientNodeType.family &&
          ingredient.parentId == null,
    );
    expect(roots.map((ingredient) => ingredient.id).toSet(), rootFamilyIds);
  });

  test('construction already proves no duplicate ids and no parent cycles '
      '(the registry constructor throws otherwise)', () {
    expect(registry.ingredients, isNotEmpty);
  });

  test('no orphaned parentId across the real registry', () {
    for (final ingredient in registry.ingredients) {
      final parentId = ingredient.parentId;
      if (parentId == null) {
        continue;
      }
      expect(
        registry.byId(parentId),
        isNotNull,
        reason: '${ingredient.id} references missing parent $parentId',
      );
    }
  });

  test('every root family has at least one selectable descendant', () {
    for (final familyId in rootFamilyIds) {
      final hasSelectableDescendant = registry.ingredients.any(
        (ingredient) =>
            ingredient.canSelectAsMainIngredient &&
            registry.ancestorIdsFor(ingredient.id).contains(familyId),
      );
      expect(
        hasSelectableDescendant,
        isTrue,
        reason: '$familyId has no selectable descendant',
      );
    }
  });

  test('no family has more than one direct generic child', () {
    final byParent = <String, List<CanonicalIngredient>>{};
    for (final ingredient in registry.ingredients) {
      final parentId = ingredient.parentId;
      if (parentId == null) {
        continue;
      }
      byParent
          .putIfAbsent(parentId, () => <CanonicalIngredient>[])
          .add(ingredient);
    }
    for (final entry in byParent.entries) {
      final generics = entry.value.where(
        (ingredient) =>
            ingredient.taxonomyType == IngredientTaxonomyType.generic,
      );
      expect(
        generics.length,
        lessThanOrEqualTo(1),
        reason:
            '${entry.key} has ${generics.length} direct generic children: '
            '${generics.map((i) => i.id).toList()}',
      );
    }
  });

  test('family/category nodes have taxonomyType null', () {
    for (final ingredient in registry.ingredients) {
      if (ingredient.nodeType != CanonicalIngredientNodeType.ingredient) {
        expect(
          ingredient.taxonomyType,
          isNull,
          reason:
              '${ingredient.id} is nodeType ${ingredient.nodeType} but '
              'carries taxonomyType ${ingredient.taxonomyType}',
        );
      }
    }
  });

  test('every selectable MVP node has an explicitly authored taxonomyType', () {
    for (final id in _mvpSelectableIds) {
      final ingredient = registry.byId(id);
      expect(ingredient, isNotNull, reason: '$id missing from registry');
      expect(
        ingredient!.taxonomyType,
        isNotNull,
        reason: '$id has no explicit taxonomyType',
      );
    }
  });

  test('root-first ancestor chain for a nested fish species', () {
    expect(registry.ancestorChainFor('mackerel'), <String>[
      'fish_family',
      'sea_fish_family',
    ]);
  });

  test('fish nested hierarchy matches the approved structure', () {
    expect(registry.byId('freshwater_fish_family')?.parentId, 'fish_family');
    expect(registry.byId('sea_fish_family')?.parentId, 'fish_family');
    expect(registry.byId('fish')?.parentId, 'fish_family');
    expect(registry.byId('fish_fillet')?.parentId, 'fish_family');
    for (final id in <String>['tilapia', 'catfish', 'snakehead']) {
      expect(registry.byId(id)?.parentId, 'freshwater_fish_family');
    }
    for (final id in <String>['sea_bass', 'mackerel', 'salmon']) {
      expect(registry.byId(id)?.parentId, 'sea_fish_family');
    }
  });

  test('chicken_thigh and chicken_drumstick are distinct selectable ids', () {
    final thigh = registry.byId('chicken_thigh');
    final drumstick = registry.byId('chicken_drumstick');
    expect(thigh, isNotNull);
    expect(drumstick, isNotNull);
    expect(thigh!.id, isNot(drumstick!.id));
    expect(thigh.displayName(), 'สะโพกไก่');
    expect(drumstick.displayName(), 'น่องไก่');
    expect(thigh.canSelectAsMainIngredient, isTrue);
    expect(drumstick.canSelectAsMainIngredient, isTrue);
  });

  test('the fish generic correction is in effect', () {
    final fish = registry.byId('fish');
    expect(fish, isNotNull);
    expect(fish!.nodeType, CanonicalIngredientNodeType.ingredient);
    expect(fish.taxonomyType, IngredientTaxonomyType.generic);
    expect(fish.parentId, 'fish_family');
    expect(fish.selectableAsMainIngredient, isTrue);
    expect(fish.canSelectAsMainIngredient, isTrue);
  });

  test('every Animal & Seafood Taxonomy MVP v1 node exists', () {
    for (final id in <String>{..._mvpSelectableIds, ..._mvpFamilyIds}) {
      expect(registry.byId(id), isNotNull, reason: '$id missing from registry');
    }
  });
}

const _mvpFamilyIds = <String>{
  'pork_family',
  'chicken_family',
  'beef_family',
  'fish_family',
  'freshwater_fish_family',
  'sea_fish_family',
  'shrimp_family',
  'crab_family',
  'squid_family',
  'shellfish_family',
};

const _mvpSelectableIds = <String>{
  'pork', 'minced_pork', 'pork_belly', 'pork_neck', 'pork_tenderloin',
  'pork_ribs', 'moo_yor', 'pork_liver', //
  'chicken', 'chicken_breast', 'chicken_thigh', 'chicken_drumstick',
  'chicken_wing', 'minced_chicken', 'chicken_liver', 'chicken_gizzard', //
  'beef', 'minced_beef', 'beef_shank', //
  'fish', 'fish_fillet', 'tilapia', 'catfish', 'snakehead', 'sea_bass',
  'mackerel', 'salmon', //
  'shrimp', //
  'crab', 'imitation_crab', //
  'squid', //
  'shellfish',
};
