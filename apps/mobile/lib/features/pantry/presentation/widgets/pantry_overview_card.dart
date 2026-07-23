import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_card.dart';

class PantryOverviewCard extends StatelessWidget {
  const PantryOverviewCard({
    required this.totalCount,
    required this.expiringCount,
    required this.favoriteCount,
    super.key,
  });

  final int totalCount;
  final int expiringCount;
  final int favoriteCount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.primaryLight,
      borderColor: AppColors.primary.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.dashboard_customize_outlined,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('ภาพรวมคลัง', style: AppTextStyles.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _OverviewMetric(
                  icon: Icons.inventory_2_outlined,
                  value: totalCount,
                  label: 'ทั้งหมด',
                  color: AppColors.primaryDark,
                ),
              ),
              const _MetricDivider(),
              Expanded(
                child: _OverviewMetric(
                  icon: Icons.schedule_rounded,
                  value: expiringCount,
                  label: 'ใกล้หมดอายุ',
                  color: AppColors.warning,
                ),
              ),
              const _MetricDivider(),
              Expanded(
                child: _OverviewMetric(
                  icon: Icons.star_rounded,
                  value: favoriteCount,
                  label: 'รายการโปรด',
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value รายการ',
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '$value',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      color: AppColors.primary.withValues(alpha: 0.15),
    );
  }
}
