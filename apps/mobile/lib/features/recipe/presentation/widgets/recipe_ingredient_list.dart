import 'package:flutter/material.dart';

import '../../../../core/design_system/design_tokens/app_colors.dart';
import '../../../../core/design_system/design_tokens/app_spacing.dart';
import '../../../../core/design_system/design_tokens/app_typography.dart';
import '../../../../core/presentation/unit_presentation.dart';
import '../../domain/services/recipe_serving_calculator.dart';

/// Read-only ingredient list for Recipe Detail. This replaces the old
/// embedded legacy page, which duplicated the serving-selector and
/// "start cooking" button already present in the new header above it and
/// in the cooking wizard — showing both was confusing (reported directly
/// by user testing). Adjusting servings and starting to cook now only
/// happens in one place: the cooking wizard.
class RecipeIngredientList extends StatelessWidget {
  const RecipeIngredientList({super.key, required this.servingPlan});

  final RecipeServingPlan servingPlan;

  @override
  Widget build(BuildContext context) {
    if (servingPlan.ingredients.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'วัตถุดิบทั้งหมด (สำหรับ ${servingPlan.servings} คน)',
            style: AppTypography.label,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final item in servingPlan.ingredients)
            _IngredientRow(item: item),
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.item});
  final ScaledRecipeIngredient item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            item.isEnough ? Icons.check_circle : Icons.remove_circle_outline,
            size: 18,
            color: item.isEnough ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(item.ingredient.name, style: AppTypography.body),
          ),
          Text(
            UnitPresentation.cookingQuantity(
              item.requiredQuantity,
              item.ingredient.unit,
            ),
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}
