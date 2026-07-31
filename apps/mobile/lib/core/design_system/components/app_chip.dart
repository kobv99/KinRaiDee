import 'package:flutter/material.dart';
import '../design_tokens/app_colors.dart';
import '../design_tokens/app_radius.dart';
import '../design_tokens/app_spacing.dart';
import '../design_tokens/app_typography.dart';

enum AppChipTone { neutral, primary, success, warning, error }

class _ToneColors {
  const _ToneColors(this.background, this.foreground);
  final Color background;
  final Color foreground;
}

_ToneColors _colorsForTone(AppChipTone tone) {
  return switch (tone) {
    AppChipTone.neutral => const _ToneColors(AppColors.surfaceMuted, AppColors.textSecondary),
    AppChipTone.primary => const _ToneColors(AppColors.primarySoft, AppColors.primary),
    AppChipTone.success => const _ToneColors(AppColors.successSoft, AppColors.success),
    AppChipTone.warning => const _ToneColors(AppColors.warningSoft, AppColors.warning),
    AppChipTone.error => const _ToneColors(AppColors.errorSoft, AppColors.error),
  };
}

/// Small pill used for statuses ("Pantry Friendly", "พร้อมทำ", "ขาด 1 รายการ").
/// Selectable variant is used for filters (e.g. daily summary metrics).
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.tone = AppChipTone.neutral,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final AppChipTone tone;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = selected
        ? const _ToneColors(AppColors.primary, AppColors.textOnPrimary)
        : _colorsForTone(tone);

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: colors.foreground),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(label, style: AppTypography.caption.copyWith(color: colors.foreground, fontWeight: FontWeight.w600)),
        ],
      ),
    );

    if (onTap == null) return chip;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(onTap: onTap, child: chip),
    );
  }
}

/// Small numeric/status badge, e.g. a notification dot count.
class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.child, this.count});

  final Widget child;
  final int? count;

  @override
  Widget build(BuildContext context) {
    if (count == null || count == 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: AppRadius.pillRadius,
            ),
            child: Text(
              '$count',
              style: AppTypography.caption.copyWith(color: AppColors.textOnPrimary, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }
}
