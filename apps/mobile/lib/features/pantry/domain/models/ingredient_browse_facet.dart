import '../../../../core/domain/ingredients/canonical_ingredient.dart';
import '../../../../core/domain/ingredients/canonical_ingredient_registry.dart';

/// A browse-only classification over existing canonical ingredients — not
/// a taxonomy node, not a new identity. `CanonicalIngredient`/the registry
/// remain the single source of truth for what an ingredient *is*; a facet
/// only decides which existing ids are convenient to browse together
/// (e.g. "อาหารแปรรูป" spans protein- and seafood-category ids that keep
/// their real taxonomy parent, such as moo_yor staying a pork_family
/// descendant while also being listed here).
class IngredientBrowseFacet {
  const IngredientBrowseFacet({
    required this.id,
    required this.displayName,
    required this.emoji,
  });

  final String id;
  final String displayName;
  final String emoji;
}

/// Oils and fats: no existing categorical field separates these from other
/// liquid seasonings (fish sauce, soy sauce, coconut milk are also
/// `category == 'seasoning'`), so this is the one facet that needs an
/// explicit, curated id set. Every id is a real cooking oil or fat already
/// in the merged registry (thai_ingredients.json plus the pantry catalog's
/// canonical-coverage definitions in pantry_catalog_canonical_definitions.dart)
/// — never a sauce, even a liquid one.
const Set<String> _oilAndFatIds = <String>{
  'cooking_oil',
  'rice_bran_oil',
  'olive_oil',
  'sesame_oil',
  'butter',
  'margarine',
};

/// Transformed/processed items — matches the approved product-direction
/// list exactly. Each id keeps its own real canonical taxonomy parent
/// (e.g. moo_yor stays under pork_family); this set only decides browse
/// membership, nothing about identity or ancestry.
const Set<String> _processedFoodIds = <String>{
  'moo_yor',
  'sausage',
  'ham',
  'bacon',
  'meatball',
  'imitation_crab',
  'canned_fish',
  'canned_tuna',
};

/// Ready-to-eat: audited conservatively against the real merged registry
/// rather than inferred from "processed" status. instant_noodle
/// (บะหมี่กึ่งสำเร็จรูป, category `staple`) is unambiguous — its own Thai
/// name literally says "สำเร็จรูป" (ready-made). canned_fish/canned_tuna
/// qualify because canned goods are inherently minimal-prep and can be
/// eaten cold. Everything else in the registry (raw cuts, seasonings, dry
/// staples that require real cooking) does not genuinely qualify — this is
/// intentionally a short, hand-audited list rather than every `staple`- or
/// `processed_food`-facet id.
const Set<String> _readyToEatIds = <String>{
  'instant_noodle',
  'canned_fish',
  'canned_tuna',
};

const List<IngredientBrowseFacet> ingredientBrowseFacets =
    <IngredientBrowseFacet>[
      IngredientBrowseFacet(
        id: 'dry_goods',
        displayName: 'อาหารแห้ง',
        emoji: '🌾',
      ),
      IngredientBrowseFacet(
        id: 'processed_food',
        displayName: 'อาหารแปรรูป',
        emoji: '🥫',
      ),
      IngredientBrowseFacet(
        id: 'ready_to_eat',
        displayName: 'อาหารสำเร็จรูป',
        emoji: '🍱',
      ),
      IngredientBrowseFacet(id: 'vegetables', displayName: 'ผัก', emoji: '🥬'),
      IngredientBrowseFacet(id: 'oils', displayName: 'น้ำมัน', emoji: '🫗'),
      IngredientBrowseFacet(
        id: 'seasonings',
        displayName: 'เครื่องปรุง',
        emoji: '🧂',
      ),
    ];

/// Selectable canonical members of [facetId]. Derived from
/// [CanonicalIngredient.category] wherever that field alone expresses the
/// boundary (dry_goods, vegetables, and seasonings-minus-oils); falls back
/// to a small curated id set only where it can't (oils, processed_food,
/// ready_to_eat). Every branch filters the registry's own list — it never
/// constructs a new [CanonicalIngredient], so no id can ever be duplicated
/// by appearing in a facet.
List<CanonicalIngredient> ingredientBrowseFacetMembers(
  CanonicalIngredientRegistry registry,
  String facetId,
) {
  bool isSelectable(CanonicalIngredient ingredient) =>
      ingredient.nodeType == CanonicalIngredientNodeType.ingredient;

  switch (facetId) {
    case 'dry_goods':
      return registry.ingredients
          .where((i) => isSelectable(i) && i.category == 'staple')
          .toList(growable: false);
    case 'processed_food':
      return registry.ingredients
          .where((i) => isSelectable(i) && _processedFoodIds.contains(i.id))
          .toList(growable: false);
    case 'ready_to_eat':
      return registry.ingredients
          .where((i) => isSelectable(i) && _readyToEatIds.contains(i.id))
          .toList(growable: false);
    case 'vegetables':
      return registry.ingredients
          .where((i) => isSelectable(i) && i.category == 'vegetable')
          .toList(growable: false);
    case 'oils':
      return registry.ingredients
          .where((i) => isSelectable(i) && _oilAndFatIds.contains(i.id))
          .toList(growable: false);
    case 'seasonings':
      return registry.ingredients
          .where(
            (i) =>
                isSelectable(i) &&
                i.category == 'seasoning' &&
                !_oilAndFatIds.contains(i.id),
          )
          .toList(growable: false);
    default:
      return const <CanonicalIngredient>[];
  }
}
