import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../application/shopping_recommendation_controller.dart';
import '../../domain/entities/shopping_recommendation.dart';
import '../providers/recommendation_ui_provider.dart';
import '../providers/shopping_recommendation_provider.dart';
import '../providers/shopping_view_provider.dart' show shoppingUnitLabel;

class RecommendedPurchasesSection extends ConsumerStatefulWidget {
  const RecommendedPurchasesSection({super.key});

  @override
  ConsumerState<RecommendedPurchasesSection> createState() =>
      _RecommendedPurchasesSectionState();
}

class _RecommendedPurchasesSectionState
    extends ConsumerState<RecommendedPurchasesSection> {
  @override
  Widget build(BuildContext context) {
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
        final preview = items.take(3).toList(growable: false);
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.shopping_basket_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Expanded(
                    child: Text(
                      'แนะนำให้ซื้อเพิ่ม',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (items.length > preview.length)
                    TextButton(
                      key: const ValueKey<String>(
                        'recommended-purchases-view-all',
                      ),
                      onPressed: () => _showAll(items),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('ดูทั้งหมด'),
                    ),
                  IconButton(
                    key: const ValueKey<String>(
                      'recommended-purchases-dismiss',
                    ),
                    tooltip: 'ซ่อนคำแนะนำครั้งนี้',
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        ref.read(recommendationUiProvider.notifier).dismiss(),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ...preview.map(
                (recommendation) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: _RecommendationCard(
                    recommendation: recommendation,
                    isBusy:
                        uiState.busyIngredientId ==
                        recommendation.canonicalIngredientId,
                    onShowDetails: () => _showDetails(recommendation),
                    onAdd: () => _addRecommendation(recommendation),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(top: AppSpacing.lg),
        child: LinearProgressIndicator(
          key: ValueKey<String>('recommended-purchases-loading'),
          minHeight: 2,
        ),
      ),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: AppCard(
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

  Future<void> _showAll(List<ShoppingRecommendation> recommendations) async {
    final uiState = ref.read(recommendationUiProvider);
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, AppSpacing.sm),
                  child: Text(
                    'คำแนะนำทั้งหมด',
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      AppSpacing.lg,
                    ),
                    itemCount: recommendations.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final recommendation = recommendations[index];
                      return _RecommendationCard(
                        recommendation: recommendation,
                        isBusy:
                            uiState.busyIngredientId ==
                            recommendation.canonicalIngredientId,
                        onShowDetails: () {
                          Navigator.of(sheetContext).pop(recommendation);
                        },
                        onAdd: () => _addRecommendation(recommendation),
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
      builder: (context) {
        final evidence = recommendation.evidence;
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${recommendation.emoji.isEmpty ? '🛒' : recommendation.emoji} ${recommendation.displayName}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'แนะนำให้เพิ่ม ${_quantity(recommendation.recommendedQuantity)} '
                  '${shoppingUnitLabel(recommendation.recommendedUnitId)}',
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  recommendation.reason,
                  key: const ValueKey<String>('recommendation-reason'),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                    onPressed:
                        ref.read(recommendationUiProvider).busyIngredientId ==
                            null
                        ? () {
                            Navigator.of(context).pop();
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
    // Compact horizontal row, not a full card block: this list is
    // secondary to the actual Shopping list below it, so each row should
    // read at a glance rather than compete with it for attention. Full
    // reasoning/impact numbers still live in the detail sheet (onTap).
    return InkWell(
      key: ValueKey<String>(
        'recommended-purchase-${recommendation.canonicalIngredientId}',
      ),
      onTap: onShowDetails,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Text(
              recommendation.emoji.isEmpty ? '🛒' : recommendation.emoji,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommendation.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'เพิ่ม ${_quantity(recommendation.recommendedQuantity)} '
                    '${shoppingUnitLabel(recommendation.recommendedUnitId)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              key: ValueKey<String>(
                'recommended-purchase-add-${recommendation.canonicalIngredientId}',
              ),
              tooltip: 'เพิ่มใน Shopping',
              visualDensity: VisualDensity.compact,
              onPressed: isBusy ? null : onAdd,
              icon: isBusy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_shopping_cart_outlined),
            ),
          ],
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

String _quantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
