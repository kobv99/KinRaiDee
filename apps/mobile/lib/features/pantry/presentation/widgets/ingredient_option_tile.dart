import 'package:flutter/material.dart';

import '../../../../core/domain/ingredients/canonical_ingredient.dart';

/// A selectable leaf ingredient — used both on a family screen and in
/// search results. Already-in-pantry items are disabled and marked
/// "มีแล้ว" rather than allowing a silent duplicate add; selection is
/// purely a toggle, never an immediate pantry write.
class IngredientOptionTile extends StatelessWidget {
  const IngredientOptionTile({
    super.key,
    required this.ingredient,
    required this.selected,
    required this.alreadyInPantry,
    required this.onTap,
    this.breadcrumb = const <String>[],
  });

  final CanonicalIngredient ingredient;
  final bool selected;
  final bool alreadyInPantry;
  final VoidCallback onTap;

  /// Root-first ancestor display names, shown as subtitle context when
  /// present (search results always pass one; a family screen's direct
  /// children typically don't need it since the AppBar already shows it).
  final List<String> breadcrumb;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      key: ValueKey<String>('ingredient-picker-option-${ingredient.id}'),
      enabled: !alreadyInPantry,
      onTap: alreadyInPantry ? null : onTap,
      leading: Text(
        ingredient.emoji.isNotEmpty ? ingredient.emoji : '🍽️',
        style: const TextStyle(fontSize: 24),
      ),
      title: Text(ingredient.displayName()),
      subtitle: breadcrumb.isEmpty ? null : Text(breadcrumb.join(' › ')),
      trailing: alreadyInPantry
          ? Chip(
              key: ValueKey<String>(
                'ingredient-picker-already-owned-${ingredient.id}',
              ),
              label: const Text('มีแล้ว'),
              backgroundColor: colorScheme.surfaceContainerHighest,
            )
          : Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? colorScheme.primary : colorScheme.outline,
            ),
    );
  }
}
