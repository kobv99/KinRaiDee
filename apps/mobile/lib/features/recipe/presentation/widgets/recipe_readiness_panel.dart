import 'package:flutter/material.dart';

import '../../domain/entities/recipe_readiness.dart';

class RecipeReadinessPanel extends StatelessWidget {
  const RecipeReadinessPanel({
    super.key,
    required this.readiness,
    required this.expanded,
    required this.isAddingMissing,
    required this.onToggle,
    required this.onDismiss,
    required this.onAddMissing,
  });

  final RecipeReadiness? readiness;
  final bool expanded;
  final bool isAddingMissing;
  final VoidCallback onToggle;
  final VoidCallback onDismiss;
  final VoidCallback? onAddMissing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = readiness;

    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      color: colors.surfaceContainerLow,
      child: Container(
        key: const ValueKey<String>('recipe-readiness-panel'),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: value == null
            ? _UnavailableSummary(onDismiss: onDismiss)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReadinessHeader(
                    scorePercent: value.scorePercent,
                    expanded: expanded,
                    onToggle: onToggle,
                    onDismiss: onDismiss,
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: value.score,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _recommendationText(value),
                    key: const ValueKey<String>(
                      'recipe-readiness-recommendation',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (value.missingIngredients.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        key: const ValueKey<String>('add-missing-to-shopping'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        onPressed: isAddingMissing ? null : onAddMissing,
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (isAddingMissing)
                              const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              const Icon(Icons.add_shopping_cart_outlined),
                            Text(
                              isAddingMissing
                                  ? 'กำลังเพิ่มไป Shopping'
                                  : 'เพิ่มวัตถุดิบที่ขาด',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (expanded) ...[
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _IngredientGroup(
                                title: 'เราแนะนำให้เตรียมเพิ่ม',
                                emptyLabel: 'วัตถุดิบหลักพร้อมแล้ว',
                                items: value.missingIngredients,
                                icon: Icons.shopping_cart_outlined,
                              ),
                              if (value
                                  .missingOptionalIngredients
                                  .isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _IngredientGroup(
                                  title: 'วัตถุดิบเสริม เลือกใช้ได้',
                                  emptyLabel: '',
                                  items: value.missingOptionalIngredients,
                                  icon: Icons.eco_outlined,
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

  String _recommendationText(RecipeReadiness value) {
    if (value.missingIngredients.isNotEmpty) {
      return 'เราแนะนำให้เตรียมเพิ่ม ${value.missingIngredients.length} รายการเพื่อให้รสชาติใกล้สูตรมากขึ้น แต่คุณยังเริ่มทำอาหารได้เสมอ';
    }
    if (value.missingOptionalIngredients.isNotEmpty) {
      return 'วัตถุดิบหลักพร้อมแล้ว ส่วนวัตถุดิบเสริมเลือกใช้หรือละเว้นได้ตามต้องการ';
    }
    return 'Pantry พร้อมสำหรับสูตรนี้ คุณยังปรับวัตถุดิบได้ตามต้องการ';
  }
}

class _ReadinessHeader extends StatelessWidget {
  const _ReadinessHeader({
    required this.scorePercent,
    required this.expanded,
    required this.onToggle,
    required this.onDismiss,
  });

  final int scorePercent;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 340;
        final summary = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'คำแนะนำจาก Pantry',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'ความพร้อม $scorePercent%',
                key: const ValueKey<String>('recipe-readiness-score'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
        final dismiss = IconButton(
          key: const ValueKey<String>('recipe-readiness-dismiss'),
          visualDensity: VisualDensity.compact,
          tooltip: 'ปิดคำแนะนำสำหรับครั้งนี้',
          onPressed: onDismiss,
          icon: const Icon(Icons.close_rounded),
        );
        final toggleIcon = Icon(
          expanded
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 21,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 10),
                  summary,
                  dismiss,
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey<String>('recipe-readiness-toggle'),
                  onPressed: onToggle,
                  icon: toggleIcon,
                  label: Text(expanded ? 'ย่อรายละเอียด' : 'ดูรายละเอียด'),
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 21, color: colors.primary),
            const SizedBox(width: 10),
            summary,
            IconButton(
              key: const ValueKey<String>('recipe-readiness-toggle'),
              visualDensity: VisualDensity.compact,
              tooltip: expanded ? 'ย่อรายละเอียด' : 'ดูรายละเอียด',
              onPressed: onToggle,
              icon: toggleIcon,
            ),
            dismiss,
          ],
        );
      },
    );
  }
}

class _UnavailableSummary extends StatelessWidget {
  const _UnavailableSummary({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      key: const ValueKey<String>('recipe-readiness-unavailable'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: colors.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'ยังประเมินความพร้อมจาก Pantry ไม่ได้ คุณยังเปิดสูตรและเริ่มทำอาหารได้ตามปกติ',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
        IconButton(
          key: const ValueKey<String>('recipe-readiness-dismiss'),
          visualDensity: VisualDensity.compact,
          tooltip: 'ปิดคำแนะนำสำหรับครั้งนี้',
          onPressed: onDismiss,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
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
        const SizedBox(height: 5),
        if (items.isEmpty)
          Text(
            emptyLabel,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 16, color: colors.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _ingredientLabel(item),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
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
    if (item.isOptional) {
      return '${item.ingredient.name} · เลือกใช้ได้';
    }
    final shortage = _formatQuantity(item.shortageQuantity);
    return '${item.ingredient.name} · แนะนำเพิ่ม $shortage ${item.ingredient.unit}';
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
