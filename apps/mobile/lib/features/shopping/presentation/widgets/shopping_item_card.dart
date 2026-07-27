import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/shopping_category.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/entities/shopping_item_status.dart';
import '../providers/shopping_view_provider.dart';

class ShoppingItemCard extends StatelessWidget {
  const ShoppingItemCard({
    required this.item,
    required this.pantryAvailability,
    required this.recipeNames,
    required this.isBusy,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
    super.key,
  });

  final ShoppingItem item;
  final double pantryAvailability;
  final Map<String, String> recipeNames;
  final bool isBusy;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final isActive = item.status == ShoppingItemStatus.active;
    final isArchived = item.status == ShoppingItemStatus.archived;
    final color = _categoryColor(item.category);
    final sourceNames = item.sourceReferenceIds
        .map((id) => recipeNames[id] ?? id)
        .toList(growable: false);

    return AppCard(
      key: ValueKey<String>('shopping-item-${item.id}'),
      backgroundColor: isActive
          ? AppColors.surface
          : AppColors.surfaceVariant.withValues(alpha: 0.72),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Checkbox(
              key: ValueKey<String>('shopping-check-${item.id}'),
              value: !isActive,
              onChanged: isBusy || isArchived ? null : (_) => onToggle(),
              activeColor: AppColors.success,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleMedium.copyWith(
                          decoration: isActive
                              ? null
                              : TextDecoration.lineThrough,
                          color: isActive
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${formatShoppingQuantity(item.quantity)} '
                      '${shoppingUnitLabel(item.unitId)}',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.shopping,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _Pill(
                      icon: _categoryIcon(item.category),
                      label: shoppingCategoryLabel(item.category),
                      foreground: color,
                      background: color.withValues(alpha: 0.1),
                    ),
                    _Pill(
                      icon: _statusIcon(item.status),
                      label: _statusLabel(item.status),
                      foreground: isActive ? AppColors.info : AppColors.success,
                      background:
                          (isActive ? AppColors.info : AppColors.success)
                              .withValues(alpha: 0.1),
                    ),
                    _Pill(
                      icon: Icons.kitchen_outlined,
                      label:
                          'ใน Pantry ${formatShoppingQuantity(pantryAvailability)} '
                          '${shoppingUnitLabel(item.unitId)}',
                      foreground: AppColors.textSecondary,
                      background: AppColors.surfaceVariant,
                    ),
                  ],
                ),
                if (sourceNames.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'จากเมนู ${sourceNames.join(', ')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    if (isActive) ...[
                      TextButton.icon(
                        key: ValueKey<String>('shopping-edit-${item.id}'),
                        onPressed: isBusy ? null : onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('แก้ไข'),
                      ),
                      TextButton.icon(
                        key: ValueKey<String>('shopping-delete-${item.id}'),
                        onPressed: isBusy ? null : onDelete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('ลบ'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                      ),
                    ] else if (isArchived)
                      TextButton.icon(
                        key: ValueKey<String>('shopping-restore-${item.id}'),
                        onPressed: isBusy ? null : onRestore,
                        icon: const Icon(Icons.restore, size: 18),
                        label: const Text('กู้คืน'),
                      )
                    else
                      Text(
                        'แตะเครื่องหมายเพื่อย้ายกลับไปรายการที่ต้องซื้อ',
                        style: AppTextStyles.bodySmall,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

IconData _categoryIcon(ShoppingCategory category) {
  return switch (category) {
    ShoppingCategory.produce => Icons.eco_outlined,
    ShoppingCategory.protein => Icons.egg_alt_outlined,
    ShoppingCategory.seafood => Icons.set_meal_outlined,
    ShoppingCategory.dairyAndEggs => Icons.local_drink_outlined,
    ShoppingCategory.grains => Icons.grain,
    ShoppingCategory.seasonings => Icons.spa_outlined,
    ShoppingCategory.beverages => Icons.local_cafe_outlined,
    ShoppingCategory.frozen => Icons.ac_unit,
    ShoppingCategory.household => Icons.home_outlined,
    ShoppingCategory.other => Icons.shopping_basket_outlined,
  };
}

Color _categoryColor(ShoppingCategory category) {
  return switch (category) {
    ShoppingCategory.produce => AppColors.success,
    ShoppingCategory.protein => AppColors.primaryDark,
    ShoppingCategory.seafood => AppColors.info,
    ShoppingCategory.dairyAndEggs => const Color(0xFF8E6BBE),
    ShoppingCategory.grains => const Color(0xFFA36A2A),
    ShoppingCategory.seasonings => const Color(0xFF8A6A27),
    ShoppingCategory.beverages => const Color(0xFF397FA3),
    ShoppingCategory.frozen => const Color(0xFF5F83B8),
    ShoppingCategory.household => AppColors.textSecondary,
    ShoppingCategory.other => AppColors.textMuted,
  };
}

String _statusLabel(ShoppingItemStatus status) {
  return switch (status) {
    ShoppingItemStatus.active => 'ต้องซื้อ',
    ShoppingItemStatus.purchased => 'ซื้อแล้ว',
    ShoppingItemStatus.archived => 'เก็บแล้ว',
  };
}

IconData _statusIcon(ShoppingItemStatus status) {
  return switch (status) {
    ShoppingItemStatus.active => Icons.radio_button_unchecked,
    ShoppingItemStatus.purchased => Icons.check_circle_outline,
    ShoppingItemStatus.archived => Icons.inventory_2_outlined,
  };
}
