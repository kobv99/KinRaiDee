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
///
/// [missingInShoppingCount] (a subset of [missingCount]) distinguishes
/// ingredients that are missing but already planned for purchase from
/// ones that are missing and not planned at all — three states are
/// shown to the user: available in Pantry, missing and not planned, and
/// missing but already in Shopping. When every missing ingredient is
/// already in Shopping, only [onGoToShopping] is offered; otherwise both
/// actions appear side by side.
class PantryReadinessCard extends StatelessWidget {
  const PantryReadinessCard({
    super.key,
    required this.readyPercent,
    required this.haveCount,
    required this.totalCount,
    required this.missingCount,
    this.onAddMissingIngredients,
    this.isAddingMissing = false,
    this.missingInShoppingCount = 0,
    this.onGoToShopping,
  });

  final int readyPercent;
  final int haveCount;
  final int totalCount;
  final int missingCount;
  final VoidCallback? onAddMissingIngredients;
  final bool isAddingMissing;
  final int missingInShoppingCount;
  final VoidCallback? onGoToShopping;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ความพร้อมจาก Pantry',
                  style: AppTypography.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$readyPercent%',
                style: AppTypography.title.copyWith(color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppProgress(value: readyPercent / 100),
          const SizedBox(height: AppSpacing.sm),
          Text(
            readyPercent >= 100
                ? 'พร้อมทำ'
                : 'พร้อมทำ · ใช้วัตถุดิบ $haveCount จาก $totalCount รายการ',
            style: AppTypography.bodySmall,
          ),
          if (missingCount > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Builder(
              builder: (context) {
                final missingNotPlanned =
                    (missingCount - missingInShoppingCount).clamp(
                      0,
                      missingCount,
                    );
                final allMissingInShopping =
                    missingNotPlanned == 0 && missingInShoppingCount > 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allMissingInShopping
                          ? '✓ เพิ่มเข้า Shopping แล้ว'
                          : 'ขาด $missingCount รายการ',
                      style: AppTypography.bodySmall.copyWith(
                        color: allMissingInShopping
                            ? AppColors.success
                            : AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!allMissingInShopping && missingInShoppingCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          '✓ เพิ่มเข้า Shopping แล้ว $missingInShoppingCount รายการ',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        if (onGoToShopping != null &&
                            missingInShoppingCount > 0) ...[
                          Expanded(
                            child: AppButton(
                              key: const ValueKey<String>(
                                'go-to-shopping-action',
                              ),
                              label: allMissingInShopping
                                  ? 'ดูใน Shopping'
                                  : 'ไปที่ Shopping',
                              variant: AppButtonVariant.secondary,
                              onPressed: onGoToShopping,
                            ),
                          ),
                          if (!allMissingInShopping)
                            const SizedBox(width: AppSpacing.sm),
                        ],
                        if (!allMissingInShopping)
                          Expanded(
                            child: AppButton(
                              key: const ValueKey<String>(
                                'add-missing-to-shopping',
                              ),
                              label: 'เพิ่มวัตถุดิบ',
                              variant: AppButtonVariant.secondary,
                              loading: isAddingMissing,
                              onPressed: isAddingMissing
                                  ? null
                                  : onAddMissingIngredients,
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
