import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../application/shopping_recommendation_controller.dart';
import '../../domain/entities/shopping_recommendation.dart';
import '../providers/recommendation_ui_provider.dart';
import '../providers/shopping_recommendation_provider.dart';

/// Reusable "Recommended Purchases" surface backed by [recommendationUiProvider]
/// so it can be embedded on both Pantry and Shopping without any screen
/// owning its own copy of dismiss/busy state.
class RecommendedPurchasesSection extends ConsumerWidget {
  const RecommendedPurchasesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(recommendationUiProvider);
    if (uiState.dismissed) {
      return const SizedBox.shrink();
    }
    final recommendations = ref.watch(shoppingRecommendationsProvider);
    return recommendations.when(
      data: (items) {
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'วัตถุดิบที่ซื้อแล้วคุ้ม',
                        style: AppTextStyles.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'เรียงจากผลต่อจำนวนเมนูและความพร้อมของสูตร',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>(
                    'recommended-purchases-dismiss',
                  ),
                  tooltip: 'ซ่อนคำแนะนำครั้งนี้',
                  onPressed: () =>
                      ref.read(recommendationUiProvider.notifier).dismiss(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...items.take(3).map(
              (recommendation) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _RecommendationCard(
                  recommendation: recommendation,
                  isBusy:
                      uiState.busyIngredientId ==
                      recommendation.canonicalIngredientId,
                  onShowDetails: () =>
                      _showDetails(context, ref, recommendation),
                  onAdd: () => _addRecommendation(context, ref, recommendation),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(
        key: ValueKey<String>('recommended-purchases-loading'),
        minHeight: 2,
      ),
      error: (error, stackTrace) => AppCard(
        child: Row(
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text('ยังโหลดคำแนะนำการซื้อไม่ได้ในขณะนี้'),
            ),
            TextButton(
              onPressed: () => ref.invalidate(shoppingRecommendationsProvider),
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addRecommendation(
    BuildContext context,
    WidgetRef ref,
    ShoppingRecommendation recommendation,
  ) async {
    final uiNotifier = ref.read(recommendationUiProvider.notifier);
    if (ref.read(recommendationUiProvider).busyIngredientId != null) {
      return;
    }
    final controller = ref.read(shoppingRecommendationControllerProvider);
    if (controller == null) {
      _showMessage(context, 'ระบบคำแนะนำยังไม่พร้อม กรุณาลองใหม่อีกครั้ง');
      return;
    }
    uiNotifier.setBusyIngredient(recommendation.canonicalIngredientId);
    try {
      final result = await controller.addToShopping(recommendation);
      if (!context.mounted) {
        return;
      }
      switch (result.outcome) {
        case ShoppingRecommendationAddOutcome.added:
        case ShoppingRecommendationAddOutcome.updated:
          _showMessage(
            context,
            'เพิ่ม ${recommendation.displayName} ใน Shopping แล้ว',
          );
          ref.invalidate(shoppingRecommendationsProvider);
          break;
        case ShoppingRecommendationAddOutcome.unchanged:
          _showMessage(
            context,
            '${recommendation.displayName} อยู่ใน Shopping เพียงพอแล้ว',
          );
          break;
        case ShoppingRecommendationAddOutcome.failed:
          _showMessage(context, 'เพิ่มรายการไม่สำเร็จ ข้อมูลเดิมยังคงปลอดภัย');
          break;
      }
    } on Object {
      if (context.mounted) {
        _showMessage(context, 'เพิ่มรายการไม่สำเร็จ ข้อมูลเดิมยังคงปลอดภัย');
      }
    } finally {
      uiNotifier.setBusyIngredient(null);
    }
  }

  Future<void> _showDetails(
    BuildContext context,
    WidgetRef ref,
    ShoppingRecommendation recommendation,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final evidence = recommendation.evidence;
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${recommendation.emoji.isEmpty ? '🛒' : recommendation.emoji} ${recommendation.displayName}',
                  style: AppTextStyles.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'แนะนำให้เพิ่ม ${_quantity(recommendation.recommendedQuantity)} '
                  '${recommendation.recommendedUnitId}',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  recommendation.reason,
                  key: const ValueKey<String>('recommendation-reason'),
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                _MetricRow(
                  label: 'Impact Score',
                  value: recommendation.score.toStringAsFixed(1),
                ),
                _MetricRow(
                  label: 'เมนูที่พร้อมเพิ่มขึ้น',
                  value: '${evidence.recipesUnlocked} เมนู',
                ),
                _MetricRow(
                  label: 'ความพร้อมเฉลี่ย',
                  value:
                      '${evidence.averageReadinessBeforePercent}% → '
                      '${evidence.averageReadinessAfterPercent}%',
                ),
                _MetricRow(
                  label: 'เมนูที่ได้รับประโยชน์',
                  value: '${evidence.impactedRecipeCount} เมนู',
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'เมนูที่ได้ประโยชน์มากที่สุด',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                ...recommendation.topRecipes.map(
                  (impact) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(impact.recipeName),
                    subtitle: Text(
                      '${impact.readinessBeforePercent}% → '
                      '${impact.readinessAfterPercent}%',
                    ),
                    trailing: impact.becomesUnlocked
                        ? const Chip(label: Text('พร้อมทำ'))
                        : Text('+${impact.readinessIncreasePercent}%'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        ref.read(recommendationUiProvider).busyIngredientId ==
                            null
                        ? () {
                            Navigator.of(sheetContext).pop();
                            _addRecommendation(context, ref, recommendation);
                          }
                        : null,
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                    label: const Text('เพิ่มใน Shopping'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessage(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.isBusy,
    required this.onShowDetails,
    required this.onAdd,
  });

  final ShoppingRecommendation recommendation;
  final bool isBusy;
  final VoidCallback onShowDetails;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final evidence = recommendation.evidence;
    return AppCard(
      key: ValueKey<String>(
        'recommended-purchase-${recommendation.canonicalIngredientId}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                recommendation.emoji.isEmpty ? '🛒' : recommendation.emoji,
                style: AppTextStyles.headlineMedium,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommendation.displayName,
                      style: AppTextStyles.titleMedium,
                    ),
                    Text(
                      'เพิ่ม ${_quantity(recommendation.recommendedQuantity)} '
                      '${recommendation.recommendedUnitId}',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'ดูเหตุผล',
                onPressed: onShowDetails,
                icon: const Icon(Icons.info_outline),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'ทำให้พร้อมเพิ่ม ${evidence.recipesUnlocked} เมนู · '
            'ความพร้อมเฉลี่ย ${evidence.averageReadinessBeforePercent}% → '
            '${evidence.averageReadinessAfterPercent}%',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: ValueKey<String>(
                'recommended-purchase-add-${recommendation.canonicalIngredientId}',
              ),
              onPressed: isBusy ? null : onAdd,
              icon: isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_shopping_cart_outlined),
              label: const Text('เพิ่มใน Shopping'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
          Text(value, style: AppTextStyles.labelLarge),
        ],
      ),
    );
  }
}

String _quantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
