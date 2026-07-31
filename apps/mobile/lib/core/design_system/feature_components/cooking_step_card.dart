import 'package:flutter/material.dart';
import '../design_tokens/app_colors.dart';
import '../design_tokens/app_radius.dart';
import '../design_tokens/app_spacing.dart';
import '../design_tokens/app_typography.dart';

/// Full-bleed content for one Cooking Mode step: "ขั้นตอนที่ X / Total",
/// the instruction, optional supporting detail, and an optional step image.
/// Designed for the dark Cooking Mode surface.
class CookingStepCard extends StatelessWidget {
  const CookingStepCard({
    super.key,
    required this.stepIndex,
    required this.totalSteps,
    required this.instruction,
    this.supportingDetail,
    this.imageProvider,
  });

  final int stepIndex;
  final int totalSteps;
  final String instruction;
  final String? supportingDetail;
  final ImageProvider? imageProvider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ขั้นตอนที่ $stepIndex / $totalSteps',
          style: AppTypography.bodySmall.copyWith(color: AppColors.cookingTextSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        if (imageProvider != null) ...[
          ClipRRect(
            borderRadius: AppRadius.largeRadius,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image(image: imageProvider!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text(
          instruction,
          style: AppTypography.display.copyWith(color: AppColors.cookingTextPrimary, fontSize: 24),
        ),
        if (supportingDetail != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            supportingDetail!,
            style: AppTypography.body.copyWith(color: AppColors.cookingTextSecondary),
          ),
        ],
      ],
    );
  }
}

/// Bottom "ย้อนกลับ / ถัดไป" navigation bar for Cooking Mode. Large
/// touch-friendly controls per spec.
class CookingNavigationBar extends StatelessWidget {
  const CookingNavigationBar({
    super.key,
    required this.onPrevious,
    required this.onNext,
    this.nextLabel = 'ถัดไป',
    this.previousLabel = 'ย้อนกลับ',
  });

  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final String nextLabel;
  final String previousLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onPrevious != null)
          Expanded(
            child: OutlinedButton(
              onPressed: onPrevious,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.cookingTextPrimary,
                side: const BorderSide(color: AppColors.cookingTextSecondary),
                minimumSize: const Size.fromHeight(56),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillRadius),
              ),
              child: Text(previousLabel),
            ),
          ),
        if (onPrevious != null) const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              minimumSize: const Size.fromHeight(56),
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillRadius),
            ),
            child: Text(nextLabel),
          ),
        ),
      ],
    );
  }
}
