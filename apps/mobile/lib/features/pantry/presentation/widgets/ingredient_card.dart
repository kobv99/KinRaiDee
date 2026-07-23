import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/models/ingredient.dart';
import '../../../../shared/widgets/app_card.dart';

class IngredientCard extends StatelessWidget {
  const IngredientCard({
    required this.ingredient,
    required this.onDelete,
    super.key,
    this.onTap,
  });

  final Ingredient ingredient;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final expiryStatus = _ExpiryStatus.fromIngredient(ingredient);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _IngredientEmoji(emoji: ingredient.emoji),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        ingredient.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                    if (expiryStatus != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      _ExpiryBadge(status: expiryStatus),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  ingredient.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _IngredientDetail(
                      icon: Icons.inventory_2_outlined,
                      text:
                          '${_formatQuantity(ingredient.quantity)} ${ingredient.unit}',
                    ),
                    if (ingredient.expiryDate != null)
                      _IngredientDetail(
                        icon: Icons.calendar_month_outlined,
                        text: _formatDate(ingredient.expiryDate!),
                        color: expiryStatus?.foregroundColor,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            tooltip: 'ลบวัตถุดิบ',
            onPressed: onDelete,
            color: AppColors.textMuted,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  static String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }

    return quantity.toStringAsFixed(1);
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _IngredientEmoji extends StatelessWidget {
  const _IngredientEmoji({required this.emoji});

  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppRadius.card,
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 30)),
    );
  }
}

class _IngredientDetail extends StatelessWidget {
  const _IngredientDetail({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: effectiveColor),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          text,
          style: AppTextStyles.bodySmall.copyWith(color: effectiveColor),
        ),
      ],
    );
  }
}

class _ExpiryBadge extends StatelessWidget {
  const _ExpiryBadge({required this.status});

  final _ExpiryStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.bodySmall.copyWith(
          color: status.foregroundColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum _ExpiryLevel { expired, urgent, soon }

class _ExpiryStatus {
  const _ExpiryStatus({
    required this.level,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final _ExpiryLevel level;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  static _ExpiryStatus? fromIngredient(Ingredient ingredient) {
    final days = ingredient.daysUntilExpiry;

    if (days == null) {
      return null;
    }

    if (ingredient.isExpired || days < 0) {
      return const _ExpiryStatus(
        level: _ExpiryLevel.expired,
        label: 'หมดอายุแล้ว',
        foregroundColor: AppColors.error,
        backgroundColor: Color(0xFFFFE8E8),
      );
    }

    if (days <= 2) {
      return _ExpiryStatus(
        level: _ExpiryLevel.urgent,
        label: days == 0 ? 'หมดอายุวันนี้' : 'เหลือ $days วัน',
        foregroundColor: AppColors.error,
        backgroundColor: const Color(0xFFFFE8E8),
      );
    }

    if (days <= 7) {
      return _ExpiryStatus(
        level: _ExpiryLevel.soon,
        label: 'เหลือ $days วัน',
        foregroundColor: AppColors.warning,
        backgroundColor: const Color(0xFFFFF1DA),
      );
    }

    return null;
  }
}
