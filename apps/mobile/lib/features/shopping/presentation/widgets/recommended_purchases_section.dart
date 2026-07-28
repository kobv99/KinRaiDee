import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../application/shopping_recommendation_controller.dart';
import '../../domain/entities/shopping_recommendation.dart';
import '../providers/shopping_recommendation_provider.dart';

class RecommendedPurchasesSection extends ConsumerStatefulWidget {
  const RecommendedPurchasesSection({super.key});

  @override
  ConsumerState<RecommendedPurchasesSection> createState() =>
      _RecommendedPurchasesSectionState();
}

class _RecommendedPurchasesSectionState
    extends ConsumerState<RecommendedPurchasesSection> {
  bool _dismissed = false;
  String? _busyIngredientId;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return const SizedBox.shrink();
    }
    final recommendations = ref.watch(shoppingRecommendationsProvider);
    return recommendations.when(
      data: (items) {
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: Column(
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
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'เรียงจากผลต่อจำนวนเมนูและความพร้อมของสูตร',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey<String>(
                      'recommended-purchases-dismiss',
                    ),
                    tooltip: 'ซ่อนคำแนะนำครั้งนี้',
                    onPressed: () => setState(() => _dismissed = true),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ...items
                  .take(3)
                  .map(
                    (recommendation) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _RecommendationCard(
                        recommendation: recommendation,
                        isBusy:
                            _busyIngredientId ==
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
    if (_busyIngredientId != null) {
      return;
    }
    final controller = ref.read(shoppingRecommendationControllerProvider);
    if (controller == null) {
      _showMessage('ระบบคำแนะนำยังไม่พร้อม กรุณาลองใหม่อีกครั้ง');
      return;
    }
    setState(() => _busyIngredientId = recommendation.canonicalIngredientId);
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
        setState(() => _busyIngredientId = null);
      }
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
                  '${recommendation.recommendedUnitId}',
                ),
                const SizedBox(height: AppSpacing.md),
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
                    onPressed: _busyIngredientId == null
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
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommendation.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'เพิ่ม ${_quantity(recommendation.recommendedQuantity)} '
                      '${recommendation.recommendedUnitId}',
                      style: Theme.of(context).textTheme.bodySmall,
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
