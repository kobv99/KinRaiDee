import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/shopping_category.dart';
import '../../domain/entities/shopping_item.dart';
import '../providers/shopping_view_provider.dart';

class ShoppingItemCard extends StatelessWidget {
  const ShoppingItemCard({
    required this.item,
    required this.pantryAvailability,
    required this.recipeNames,
    required this.isBusy,
    required this.onComplete,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final ShoppingItem item;
  final double pantryAvailability;
  final Map<String, String> recipeNames;
  final bool isBusy;
  final VoidCallback onComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(item.category);
    final sourceNames = item.sourceReferenceIds
        .map((id) => recipeNames[id] ?? id)
        .toList(growable: false);

    return AppCard(
      key: ValueKey<String>('shopping-item-${item.id}'),
      padding: const EdgeInsets.all(AppSpacing.sm),
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
                  style: AppTextStyles.titleMedium,
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
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: ValueKey<String>('shopping-complete-${item.id}'),
                  onPressed: isBusy ? null : onComplete,
                  icon: isBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.kitchen_outlined, size: 18),
                  label: const Text('เก็บเข้าตู้'),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                key: ValueKey<String>('shopping-edit-${item.id}'),
                tooltip: 'แก้ไข',
                onPressed: isBusy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                key: ValueKey<String>('shopping-delete-${item.id}'),
                tooltip: 'ลบ',
                onPressed: isBusy ? null : onDelete,
                color: AppColors.error,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
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
