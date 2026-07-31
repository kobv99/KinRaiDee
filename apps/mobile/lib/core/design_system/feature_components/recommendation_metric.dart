import 'package:flutter/material.dart';
import '../design_tokens/app_colors.dart';
import '../design_tokens/app_radius.dart';
import '../design_tokens/app_spacing.dart';
import '../design_tokens/app_typography.dart';

/// One tappable metric in the Home screen daily summary
/// (สูตรทั้งหมด / พร้อมครบ / Pantry Friendly / เมนูด่วน / ใกล้หมดอายุ).
///
/// This is a navigation control, not decoration — [onTap] must filter the
/// recipe list. [selected] drives the active visual state.
class RecommendationMetric extends StatelessWidget {
  const RecommendationMetric({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.iconColor = AppColors.primary,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final background = selected ? AppColors.primarySoft : Colors.transparent;
    final borderColor = selected ? AppColors.primary : Colors.transparent;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mediumRadius,
        child: Container(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: background,
            borderRadius: AppRadius.mediumRadius,
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: selected ? AppColors.primary : iconColor),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(value, style: AppTypography.title),
              Text(label, style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
