import 'package:flutter/material.dart';

import '../../../../core/domain/ingredients/canonical_ingredient_search_service.dart';
import 'ingredient_search_result_tile.dart';

/// Pantry's main search add-suggestion panel. Reads the same
/// [CanonicalIngredientSearchResult] data as `IngredientPickerEntryPage`'s
/// search (via `ingredientSearchResultsProvider`) and renders it with the
/// exact same [IngredientSearchResultTile] — Pantry's inline search and the
/// full picker's search share one implementation, not two.
class PantryIngredientSearchPanel extends StatelessWidget {
  const PantryIngredientSearchPanel({
    required this.results,
    required this.ownedIds,
    required this.onSelected,
    super.key,
  });

  final List<CanonicalIngredientSearchResult> results;
  final Set<String> ownedIds;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey<String>('pantry-ingredient-search-panel'),
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: results.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final result = results[index];
            final id = result.ingredient.id;
            return IngredientSearchResultTile(
              result: result,
              alreadyInPantry: ownedIds.contains(id),
              onTap: () => onSelected(id),
            );
          },
        ),
      ),
    );
  }
}
