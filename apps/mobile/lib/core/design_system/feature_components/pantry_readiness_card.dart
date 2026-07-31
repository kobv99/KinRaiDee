import 'package:flutter/material.dart';
import '../components/app_button.dart';
import '../components/app_card.dart';
import '../components/app_progress.dart';
import '../design_tokens/app_colors.dart';
import '../design_tokens/app_spacing.dart';
import '../design_tokens/app_typography.dart';

/// "ความพร้อมจาก Pantry" card shown on Recipe Detail and the wizard's
/// ingredient-review step. [onAddMissingIngredients] MUST be wired to a
/// working action (add to Pantry, or send to Shopping) — per spec, this
/// button must never be an inactive placeholder.
class PantryReadinessCard extends StatelessWidget {
  const PantryReadinessCard({
    super.key,
    required this.readyPercent,
    required this.haveCount,
    required this.totalCount,
    required this.missingCount,
    this.onAddMissingIngredients,
  });

  final int readyPercent;
  final int haveCount;
  final int totalCount;
  final int missingCount;
  final VoidCallback? onAddMissingIngredients;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ความพร้อมจาก Pantry', style: AppTypography.label),
              Text(
                '$readyPercent%',
                style: AppTypography.headline.copyWith(color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppProgress(value: readyPercent / 100),
          const SizedBox(height: AppSpacing.sm),
          Text(
            readyPercent >= 100 ? 'พร้อมทำ' : 'พร้อมทำ · ใช้วัตถุดิบ $haveCount จาก $totalCount รายการ',
            style: AppTypography.bodySmall,
          ),
          if (missingCount > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ขาด $missingCount รายการ',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600),
                  ),
                ),
                AppButton(
                  label: 'เพิ่มวัตถุดิบ',
                  variant: AppButtonVariant.secondary,
                  expand: false,
                  onPressed: onAddMissingIngredients,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
