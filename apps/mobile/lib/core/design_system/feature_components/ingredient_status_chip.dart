import 'package:flutter/material.dart';
import '../design_tokens/app_colors.dart';
import '../design_tokens/app_radius.dart';
import '../design_tokens/app_spacing.dart';
import '../design_tokens/app_typography.dart';
import '../components/app_button.dart';

enum IngredientStatus { available, missing, substitution }

/// Compact tile for an ingredient in the "main ingredients" preview and
/// the wizard's ingredient-review list.
class IngredientStatusChip extends StatelessWidget {
  const IngredientStatusChip({
    super.key,
    required this.name,
    required this.status,
    this.onTapSubstitution,
  });

  final String name;
  final IngredientStatus status;
  final VoidCallback? onTapSubstitution;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      IngredientStatus.available => (Icons.check_circle, AppColors.success),
      IngredientStatus.missing => (Icons.cancel, AppColors.warning),
      IngredientStatus.substitution => (Icons.sync_alt, AppColors.primary),
    };

    return Semantics(
      label: '$name, ${_statusLabel(status)}',
      child: GestureDetector(
        onTap: status == IngredientStatus.substitution ? onTapSubstitution : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.pillRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(name, style: AppTypography.caption.copyWith(color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLabel(IngredientStatus status) => switch (status) {
        IngredientStatus.available => 'มีในครัว',
        IngredientStatus.missing => 'ขาด',
        IngredientStatus.substitution => 'มีวัตถุดิบทดแทน',
      };
}

/// Row for a single missing ingredient with a working "เพิ่มวัตถุดิบ" action.
class MissingIngredientCard extends StatelessWidget {
  const MissingIngredientCard({
    super.key,
    required this.name,
    required this.onAdd,
    this.quantityLabel,
  });

  final String name;
  final VoidCallback onAdd;
  final String? quantityLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          const Icon(Icons.remove_circle_outline, size: 18, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.body),
                if (quantityLabel != null) Text(quantityLabel!, style: AppTypography.caption),
              ],
            ),
          ),
          AppButton(label: 'เพิ่มวัตถุดิบ', variant: AppButtonVariant.text, expand: false, onPressed: onAdd),
        ],
      ),
    );
  }
}
