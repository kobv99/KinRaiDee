import 'package:flutter/material.dart';

import '../../domain/entities/recipe_recommendation.dart';

class RecipeRecommendationExplanationPanel extends StatelessWidget {
  const RecipeRecommendationExplanationPanel({
    super.key,
    required this.recommendation,
  });

  final RecipeRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = (MediaQuery.sizeOf(context).height * 0.48)
        .clamp(220.0, 420.0)
        .toDouble();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        child: Card(
          child: ExpansionTile(
            leading: const Icon(Icons.lightbulb_outline),
            title: const Text(
              'ทำไมถึงแนะนำเมนูนี้?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'คะแนน ${recommendation.scorePercent} • '
              'ตรงกับ Pantry ${recommendation.recipeMatchPercent}%',
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              LinearProgressIndicator(
                value: recommendation.pantryCompletionPercent / 100,
              ),
              const SizedBox(height: 8),
              _Metric(
                label: 'วัตถุดิบที่มี',
                value:
                    '${recommendation.availableIngredientCount} / '
                    '${recommendation.totalIngredientCount} '
                    '(${recommendation.pantryCompletionPercent}%)',
              ),
              _Metric(
                label: 'ใช้ของใน Pantry',
                value:
                    '${recommendation.usedPantryIngredientCount} / '
                    '${recommendation.pantryIngredientCount} '
                    '(${recommendation.pantryUtilizationPercent}%)',
              ),
              _Metric(
                label: 'ต้องซื้อเพิ่ม',
                value: '${recommendation.shoppingPreview.length} รายการ',
              ),
              const Divider(height: 24),
              ...recommendation.reasons.map(
                (reason) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline, size: 20),
                  title: Text(reason),
                ),
              ),
              if (recommendation.shoppingPreview.isNotEmpty) ...[
                const Divider(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ตัวอย่างรายการที่ต้องซื้อ',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...recommendation.shoppingPreview.map(
                  (ingredient) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text('• ${ingredient.name}'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
