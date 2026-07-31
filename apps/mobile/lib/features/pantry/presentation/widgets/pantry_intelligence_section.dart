import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/presentation/unit_presentation.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../shopping/application/shopping_recommendation_controller.dart';
import '../../../shopping/domain/entities/shopping_recommendation.dart';
import '../../../shopping/presentation/providers/recommendation_ui_provider.dart';
import '../../../shopping/presentation/providers/shopping_recommendation_provider.dart';
import '../../domain/entities/pantry_insight.dart';
import '../providers/pantry_insight_provider.dart';

class PantryIntelligenceSection extends ConsumerStatefulWidget {
  const PantryIntelligenceSection({super.key});

  @override
  ConsumerState<PantryIntelligenceSection> createState() =>
      _PantryIntelligenceSectionState();
}

class _PantryIntelligenceSectionState
    extends ConsumerState<PantryIntelligenceSection> {
  // Collapsed by default: Pantry Insights/Recommended Purchases are not
  // part of the primary "view, add, edit, delete ingredients" task, so
  // they must not push Search/Filters/the ingredient list further down
  // the page by default.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final insight = ref.watch(pantryInsightProvider);
    final recommendations = ref.watch(shoppingRecommendationsProvider);
    final dismissed = ref.watch(
      recommendationUiProvider.select((state) => state.dismissed),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InsightsSummaryToggle(
          insight: insight,
          expanded: _expanded,
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded) ...[
          const SizedBox(height: AppSpacing.sm),
          _PantryInsightsCard(insight: insight),
          if (!dismissed) ...[
            const SizedBox(height: AppSpacing.md),
            recommendations.when(
              data: (items) {
                if (items.isEmpty) {
                  return const SizedBox.shrink();
                }
                return _RecommendationPreview(
                  recommendations: items,
                  onDismiss: () {
                    ref.read(recommendationUiProvider.notifier).dismiss();
                  },
                  onSelect: _showDetails,
                  onViewAll: () => _showAll(items),
                );
              },
              loading: () => const LinearProgressIndicator(
                key: ValueKey<String>('pantry-recommendations-loading'),
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
                      onPressed: () =>
                          ref.invalidate(shoppingRecommendationsProvider),
                      child: const Text('ลองใหม่'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _showAll(List<ShoppingRecommendation> recommendations) async {
    final selected = await showModalBottomSheet<ShoppingRecommendation>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Text(
                    'คำแนะนำทั้งหมด',
                    style: Theme.of(sheetContext).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    itemCount: recommendations.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final recommendation = recommendations[index];
                      return _RecommendationTile(
                        recommendation: recommendation,
                        onTap: () => Navigator.of(context).pop(recommendation),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      await _showDetails(selected);
    }
  }

  Future<void> _showDetails(ShoppingRecommendation recommendation) async {
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
                  '${recommendation.emoji.isEmpty ? '🛒' : recommendation.emoji} '
                  '${recommendation.displayName}',
                  style: Theme.of(sheetContext).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'แนะนำให้เพิ่ม '
                  '${UnitPresentation.cookingQuantity(recommendation.recommendedQuantity, recommendation.recommendedUnitId, unitEngine: ref.read(unitConversionEngineProvider))}',
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'เหตุผลที่แนะนำ',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(recommendation.reason),
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
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
                    key: ValueKey<String>(
                      'pantry-recommendation-add-'
                      '${recommendation.canonicalIngredientId}',
                    ),
                    onPressed:
                        ref.read(recommendationUiProvider).busyIngredientId ==
                            null
                        ? () {
                            Navigator.of(sheetContext).pop();
                            _addRecommendation(recommendation);
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

  Future<void> _addRecommendation(ShoppingRecommendation recommendation) async {
    final uiNotifier = ref.read(recommendationUiProvider.notifier);
    if (ref.read(recommendationUiProvider).busyIngredientId != null) {
      return;
    }
    final controller = ref.read(shoppingRecommendationControllerProvider);
    if (controller == null) {
      _showMessage('ระบบคำแนะนำยังไม่พร้อม กรุณาลองใหม่อีกครั้ง');
      return;
    }

    uiNotifier.setBusyIngredient(recommendation.canonicalIngredientId);
    try {
      final result = await controller.addToShopping(recommendation);
      if (!mounted) {
        return;
      }

      switch (result.outcome) {
        case ShoppingRecommendationAddOutcome.added:
        case ShoppingRecommendationAddOutcome.updated:
          _showMessage('เพิ่ม ${recommendation.displayName} ใน Shopping แล้ว');
          ref.invalidate(shoppingRecommendationsProvider);
          ref.invalidate(pantryInsightProvider);
          break;
        case ShoppingRecommendationAddOutcome.unchanged:
          _showMessage(
            '${recommendation.displayName} อยู่ใน Shopping เพียงพอแล้ว',
          );
          break;
        case ShoppingRecommendationAddOutcome.failed:
          _showMessage('เพิ่มรายการไม่สำเร็จ ข้อมูลเดิมยังคงปลอดภัย');
          break;
      }
    } on Object {
      if (mounted) {
        _showMessage('เพิ่มรายการไม่สำเร็จ ข้อมูลเดิมยังคงปลอดภัย');
      }
    } finally {
      if (mounted) {
        uiNotifier.setBusyIngredient(null);
      }
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        persist: false,
      ),
    );
  }
}

class _InsightsSummaryToggle extends StatelessWidget {
  const _InsightsSummaryToggle({
    required this.insight,
    required this.expanded,
    required this.onTap,
  });

  final AsyncValue<PantryInsight?> insight;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = insight.when(
      data: (value) => value == null
          ? 'ยังสรุปข้อมูลไม่ได้'
          : 'พร้อมทำ ${value.availableRecipeCount} · ขาด ${value.missingIngredientCount}',
      loading: () => 'กำลังสรุปข้อมูล…',
      error: (error, stackTrace) => 'ยังสรุปข้อมูลไม่ได้',
    );

    return InkWell(
      key: const ValueKey<String>('pantry-insights-toggle'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            const Icon(Icons.insights_outlined, size: 18),
            const SizedBox(width: AppSpacing.xs),
            const Text(
              'Pantry Insights',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Icon(expanded ? Icons.expand_less : Icons.expand_more),
          ],
        ),
      ),
    );
  }
}

class _PantryInsightsCard extends StatelessWidget {
  const _PantryInsightsCard({required this.insight});

  final AsyncValue<PantryInsight?> insight;

  @override
  Widget build(BuildContext context) {
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
                  Text(
                    'Pantry Insights',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pantry Insights',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(minHeight: 2),
          ],
        ),
        error: (error, stackTrace) => const _InsightUnavailable(),
      ),
    );
  }
}

class _RecommendationPreview extends StatelessWidget {
  const _RecommendationPreview({
    required this.recommendations,
    required this.onDismiss,
    required this.onSelect,
    required this.onViewAll,
  });

  final List<ShoppingRecommendation> recommendations;
  final VoidCallback onDismiss;
  final ValueChanged<ShoppingRecommendation> onSelect;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final preview = recommendations.take(3).toList(growable: false);
    return AppCard(
      key: const ValueKey<String>('pantry-recommendation-preview'),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_basket_outlined),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Recommended Purchases',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('pantry-recommendations-dismiss'),
                  tooltip: 'ซ่อนคำแนะนำครั้งนี้',
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          for (var index = 0; index < preview.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            _RecommendationTile(
              recommendation: preview[index],
              onTap: () => onSelect(preview[index]),
            ),
          ],
          const Divider(height: 1),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey<String>('pantry-recommendations-view-all'),
              onPressed: onViewAll,
              child: const Text('ดูทั้งหมด →'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({
    required this.recommendation,
    required this.onTap,
  });

  final ShoppingRecommendation recommendation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final evidence = recommendation.evidence;
    return ListTile(
      key: ValueKey<String>(
        'pantry-recommendation-${recommendation.canonicalIngredientId}',
      ),
      leading: Text(
        recommendation.emoji.isEmpty ? '🛒' : recommendation.emoji,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      title: Text(
        recommendation.displayName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        'พร้อมทำเพิ่ม ${evidence.recipesUnlocked} เมนู · '
        '${evidence.averageReadinessBeforePercent}% → '
        '${evidence.averageReadinessAfterPercent}%',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
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
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
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
        Expanded(child: Text('ยังสรุปข้อมูล Pantry ไม่ได้ในขณะนี้')),
      ],
    );
  }
}
