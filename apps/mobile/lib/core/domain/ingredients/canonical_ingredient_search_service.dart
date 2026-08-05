import 'canonical_ingredient.dart';
import 'canonical_ingredient_registry.dart';

/// A single searchable match, paired with its root-first breadcrumb for
/// display (e.g. "ไก่ › น่องไก่").
class CanonicalIngredientSearchResult {
  const CanonicalIngredientSearchResult({
    required this.ingredient,
    required this.breadcrumb,
  });

  final CanonicalIngredient ingredient;

  /// Root-first display names above [ingredient], derived from
  /// [CanonicalIngredientRegistry.ancestorChainFor]. Empty for a root-level
  /// selectable ingredient.
  final List<String> breadcrumb;
}

/// Free-text search across the canonical registry for the ingredient
/// picker. Contains no recipe or compatibility business rules — it only
/// matches against the taxonomy's own names/aliases/keywords and excludes
/// family/category navigation nodes, never returning them as a result.
class CanonicalIngredientSearchService {
  const CanonicalIngredientSearchService();

  List<CanonicalIngredientSearchResult> search(
    CanonicalIngredientRegistry registry,
    String query,
  ) {
    final needle = normalizeIngredientKey(query);
    if (needle.isEmpty) {
      return const <CanonicalIngredientSearchResult>[];
    }

    final results = <CanonicalIngredientSearchResult>[];
    for (final ingredient in registry.ingredients) {
      if (ingredient.nodeType != CanonicalIngredientNodeType.ingredient) {
        continue;
      }
      final isMatch = ingredient.searchableNames.any(
        (name) => normalizeIngredientKey(name).contains(needle),
      );
      if (!isMatch) {
        continue;
      }
      final breadcrumb = registry
          .ancestorChainFor(ingredient.id)
          .map((id) => registry.byId(id)?.displayName() ?? id)
          .toList(growable: false);
      results.add(
        CanonicalIngredientSearchResult(
          ingredient: ingredient,
          breadcrumb: breadcrumb,
        ),
      );
    }
    return results;
  }
}
