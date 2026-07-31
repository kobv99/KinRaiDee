import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_card.dart';
import '../providers/pantry_insight_provider.dart';

/// Reusable Pantry Insights summary card, backed entirely by
/// [pantryInsightProvider] so any screen (Pantry, Shopping) can embed it
/// without owning any local state of its own.
class PantryInsightsCard extends ConsumerWidget {
  const PantryInsightsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = ref.watch(pantryInsightProvider);

    return AppCard(
      key: const ValueKey<String>('pantry-insights'),
      child: insight.when(
        data: (value) {
          if (value == null) {
            return const _InsightUnavailable();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights_outlined),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Pantry Insights', style: AppTextStyles.titleMedium),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _InsightMetric(
                    label: 'วัตถุดิบ',
                    value: value.ingredientCount,
                  ),
                  _InsightMetric(
                    label: 'พร้อมทำ',
                    value: value.availableRecipeCount,
                  ),
                  _InsightMetric(
                    label: 'ใกล้พร้อม',
                    value: value.almostReadyRecipeCount,
                  ),
                  _InsightMetric(
                    label: 'ยังขาด',
                    value: value.missingIngredientCount,
                  ),
                ],
              ),
              if (value.hasRecommendations) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  value.topRecommendationName == null
                      ? 'มีคำแนะนำการซื้อ ${value.recommendationCount} รายการ'
                      : 'ซื้อ ${value.topRecommendationName} เพิ่ม '
                            'จะช่วยให้พร้อมทำเพิ่ม '
                            '${value.topRecommendationRecipesUnlocked} เมนู',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ],
          );
        },
        loading: () => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pantry Insights', style: AppTextStyles.titleMedium),
            SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(minHeight: 2),
          ],
        ),
        error: (error, stackTrace) => const _InsightUnavailable(),
      ),
    );
  }
}

class _InsightMetric extends StatelessWidget {
  const _InsightMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 104),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.card,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: AppTextStyles.titleLarge),
              Text(label, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightUnavailable extends StatelessWidget {
  const _InsightUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.info_outline),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'ยังสรุปข้อมูล Pantry ไม่ได้ในขณะนี้',
            style: AppTextStyles.bodyMedium,
          ),
        ),
      ],
    );
  }
}
