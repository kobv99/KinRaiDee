import 'package:flutter/material.dart';
import '../../../../core/design_system/design_tokens/app_colors.dart';
import '../../../../core/design_system/feature_components/recommendation_metric.dart';

/// "ภาพรวมวันนี้" row — total recipes, ready-to-cook, quick recipes, and
/// ingredients expiring soon. Every metric is honestly derived from real
/// data (see home_page.dart) — no invented categories.
class DailySummaryMetrics extends StatelessWidget {
  const DailySummaryMetrics({
    super.key,
    required this.totalRecipes,
    required this.readyToCookCount,
    required this.quickRecipeCount,
    required this.expiringSoonCount,
    required this.onOpenRecipes,
    required this.onOpenPantry,
  });

  final int totalRecipes;
  final int readyToCookCount;
  final int quickRecipeCount;
  final int expiringSoonCount;
  final VoidCallback onOpenRecipes;
  final VoidCallback onOpenPantry;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          RecommendationMetric(
            icon: Icons.menu_book_outlined,
            value: '$totalRecipes',
            label: 'สูตรทั้งหมด',
            onTap: onOpenRecipes,
          ),
          const SizedBox(width: 8),
          RecommendationMetric(
            icon: Icons.check_circle_outline,
            value: '$readyToCookCount',
            label: 'พร้อมครบ',
            iconColor: AppColors.success,
            onTap: onOpenRecipes,
          ),
          const SizedBox(width: 8),
          RecommendationMetric(
            icon: Icons.bolt_outlined,
            value: '$quickRecipeCount',
            label: 'เมนูด่วน',
            iconColor: AppColors.warning,
            onTap: onOpenRecipes,
          ),
          const SizedBox(width: 8),
          RecommendationMetric(
            icon: Icons.schedule_outlined,
            value: '$expiringSoonCount',
            label: 'ใกล้หมดอายุ',
            iconColor: AppColors.error,
            onTap: onOpenPantry,
          ),
        ],
      ),
    );
  }
}
