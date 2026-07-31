import 'package:flutter/material.dart';

import '../../../../core/design_system/design_tokens/app_colors.dart';
import '../../../../core/design_system/design_tokens/app_spacing.dart';
import '../../../../core/design_system/design_tokens/app_typography.dart';
import '../../domain/entities/recipe_readiness.dart';

/// Read-only ingredient list for Recipe Detail. This replaces the old
/// embedded legacy page, which duplicated the serving-selector and
/// "start cooking" button already present in the new header above it and
/// in the cooking wizard — showing both was confusing (reported directly
/// by user testing). Adjusting servings and starting to cook now only
/// happens in one place: the cooking wizard.
class RecipeIngredientList extends StatelessWidget {
  const RecipeIngredientList({super.key, required this.readiness});

  final RecipeReadiness? readiness;

  @override
  Widget build(BuildContext context) {
    final value = readiness;
    if (value == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'วัตถุดิบทั้งหมด (สำหรับ ${value.servings} คน)',
            style: AppTypography.label,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final item in value.ingredients) _IngredientRow(item: item),
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.item});
  final RecipeIngredientReadiness item;

  @override
  Widget build(BuildContext context) {
    final quantityLabel = _formatQuantity(item.requiredQuantity);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            item.isAvailable ? Icons.check_circle : Icons.remove_circle_outline,
            size: 18,
            color: item.isAvailable ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(item.ingredient.name, style: AppTypography.body),
          ),
          Text(
            '$quantityLabel ${item.ingredient.unit}',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }
}
