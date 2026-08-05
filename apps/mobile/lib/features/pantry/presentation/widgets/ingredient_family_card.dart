import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';

/// A pure navigation card for a browsable root category — either a real
/// taxonomy family or a browse facet. Tapping it never adds anything to
/// the pantry — it only opens that category's children. Visual output
/// (size, spacing, typography, icon placement) is unchanged from the
/// approved design; only the data source feeding it was generalized so
/// facet categories can render through the exact same component.
class IngredientFamilyCard extends StatelessWidget {
  const IngredientFamilyCard({
    super.key,
    required this.id,
    required this.displayName,
    required this.emoji,
    required this.onTap,
  });

  final String id;
  final String displayName;
  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey<String>('ingredient-picker-family-card-$id'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                emoji.isNotEmpty ? emoji : '🍽️',
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: colorScheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
