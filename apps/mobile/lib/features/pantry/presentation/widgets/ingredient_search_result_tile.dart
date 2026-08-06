import 'package:flutter/material.dart';

import '../../../../core/domain/ingredients/canonical_ingredient_search_service.dart';

/// One global-search result. The full root-first breadcrumb (including the
/// ingredient's own name as the last segment) is the primary information —
/// there is no separate title repeating the leaf name, which would just
/// duplicate the last breadcrumb segment. Tapping never toggles a Browse
/// selection; it opens the direct single-item quick-add flow.
class IngredientSearchResultTile extends StatelessWidget {
  const IngredientSearchResultTile({
    super.key,
    required this.result,
    required this.alreadyInPantry,
    required this.onTap,
  });

  final CanonicalIngredientSearchResult result;
  final bool alreadyInPantry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fullBreadcrumb = <String>[
      ...result.breadcrumb,
      result.ingredient.displayName(),
    ].join(' › ');

    return ListTile(
      key: ValueKey<String>(
        'ingredient-picker-search-result-${result.ingredient.id}',
      ),
      enabled: !alreadyInPantry,
      onTap: alreadyInPantry ? null : onTap,
      leading: Text(
        result.ingredient.emoji.isNotEmpty ? result.ingredient.emoji : '🍽️',
        style: const TextStyle(fontSize: 24),
      ),
      title: Text(fullBreadcrumb),
      trailing: alreadyInPantry
          ? Chip(
              key: ValueKey<String>(
                'ingredient-picker-already-owned-${result.ingredient.id}',
              ),
              label: const Text('มีแล้ว'),
              backgroundColor: colorScheme.surfaceContainerHighest,
            )
          : null,
    );
  }
}
