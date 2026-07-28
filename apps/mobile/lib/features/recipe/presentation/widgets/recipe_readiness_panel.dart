import 'package:flutter/material.dart';

import '../../domain/entities/recipe_readiness.dart';

class RecipeReadinessPanel extends StatelessWidget {
  const RecipeReadinessPanel({
    super.key,
    required this.readiness,
    required this.expanded,
    required this.isAddingMissing,
    required this.onToggle,
    required this.onAddMissing,
  });

  final RecipeReadiness? readiness;
  final bool expanded;
  final bool isAddingMissing;
  final VoidCallback onToggle;
  final VoidCallback? onAddMissing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = readiness;
    final detailsHeight = (MediaQuery.sizeOf(context).height * 0.34)
        .clamp(180.0, 340.0)
        .toDouble();
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      color: colors.primaryContainer,
      child: Container(
        key: const ValueKey<String>('recipe-readiness-panel'),
        padding: const EdgeInsets.all(14),
        child: value == null
            ? const Row(
                children: [
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('กำลังคำนวณความพร้อมจาก Pantry'),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ความพร้อม ${value.scorePercent}%',
                              key: const ValueKey<String>(
                                'recipe-readiness-score',
                              ),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colors.onPrimaryContainer,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: value.score,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: expanded ? 'ย่อรายละเอียด' : 'ดูรายละเอียด',
                        onPressed: onToggle,
                        icon: Icon(
                          expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _CountChip(
                        icon: Icons.check_circle_outline,
                        label: 'มีแล้ว ${value.availableIngredients.length}',
                      ),
                      _CountChip(
                        icon: Icons.shopping_cart_outlined,
                        label: 'ขาด ${value.missingIngredients.length}',
                      ),
                      _CountChip(
                        icon: Icons.eco_outlined,
                        label: 'ไม่บังคับ ${value.optionalIngredients.length}',
                      ),
                    ],
                  ),
                  if (expanded) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: detailsHeight,
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _IngredientGroup(
                                title: 'มีใน Pantry แล้ว',
                                emptyLabel: 'ยังไม่มีวัตถุดิบที่ครบตามปริมาณ',
                                items: value.availableIngredients,
                                icon: Icons.check_circle_outline,
                              ),
                              const SizedBox(height: 10),
                              _IngredientGroup(
                                title: 'วัตถุดิบที่ขาด',
                                emptyLabel: 'วัตถุดิบหลักครบแล้ว',
                                items: value.missingIngredients,
                                icon: Icons.shopping_cart_outlined,
                              ),
                              const SizedBox(height: 10),
                              _IngredientGroup(
                                title: 'วัตถุดิบไม่บังคับ',
                                emptyLabel: 'สูตรนี้ไม่มีวัตถุดิบไม่บังคับ',
                                items: value.optionalIngredients,
                                icon: Icons.eco_outlined,
                              ),
                              if (value.missingIngredients.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  key: const ValueKey<String>(
                                    'add-missing-to-shopping',
                                  ),
                                  onPressed: isAddingMissing
                                      ? null
                                      : onAddMissing,
                                  icon: isAddingMissing
                                      ? const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.add_shopping_cart_outlined,
                                        ),
                                  label: Text(
                                    isAddingMissing
                                        ? 'กำลังเพิ่มไป Shopping'
                                        : 'เพิ่มวัตถุดิบที่ขาดไป Shopping',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _IngredientGroup extends StatelessWidget {
  const _IngredientGroup({
    required this.title,
    required this.emptyLabel,
    required this.items,
    required this.icon,
  });

  final String title;
  final String emptyLabel;
  final List<RecipeIngredientReadiness> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        if (items.isEmpty)
          Text(
            emptyLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onPrimaryContainer.withValues(alpha: 0.72),
            ),
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 16, color: colors.onPrimaryContainer),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _ingredientLabel(item),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _ingredientLabel(RecipeIngredientReadiness item) {
    if (item.isAvailable) {
      return item.ingredient.name;
    }
    if (item.isOptional) {
      return '${item.ingredient.name} · ไม่บังคับ';
    }
    final shortage = _formatQuantity(item.shortageQuantity);
    return '${item.ingredient.name} · ขาด $shortage ${item.ingredient.unit}';
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
