import 'package:flutter/material.dart';

import '../../../../core/design_system/components/app_section_header.dart';
import '../../../../core/design_system/design_tokens/app_spacing.dart';
import '../../../../core/models/ingredient.dart';
import 'priority_ingredient_card.dart';

/// Compact "ควรใช้ก่อน" (use first) list — brought back after the initial
/// Design Acceptance Review removal, per direct user testing feedback
/// that Home felt too empty without any expiry-awareness. Kept
/// deliberately small (top 3, no analytics/tables/category breakdowns)
/// rather than reintroducing the full Pantry dashboard that was removed.
class ExpiringSoonSection extends StatelessWidget {
  const ExpiringSoonSection({
    super.key,
    required this.ingredients,
    required this.onOpenPantry,
  });

  final List<Ingredient> ingredients;
  final VoidCallback onOpenPantry;

  @override
  Widget build(BuildContext context) {
    if (ingredients.isEmpty) return const SizedBox.shrink();

    final topThree = ingredients.take(3).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'ควรใช้ก่อน 🔥',
          actionLabel: 'เปิด Pantry',
          onActionTap: onOpenPantry,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final ingredient in topThree)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PriorityIngredientCard(
              ingredient: ingredient,
              onTap: onOpenPantry,
            ),
          ),
      ],
    );
  }
}
