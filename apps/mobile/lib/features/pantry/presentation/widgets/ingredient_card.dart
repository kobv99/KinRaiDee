import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/models/ingredient.dart';
import '../../../../core/presentation/ingredient_presentation.dart';
import '../../../../core/presentation/unit_presentation.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/services/pantry_search_engine.dart';
import 'search_highlight_text.dart';

class IngredientCard extends ConsumerWidget {
  const IngredientCard({
    required this.ingredient,
    required this.onEdit,
    required this.onDelete,
    required this.onFavoriteToggle,
    super.key,
    this.onTap,
    this.searchQuery = '',
  });

  final Ingredient ingredient;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onFavoriteToggle;
  final VoidCallback? onTap;
  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiryStatus = _ExpiryStatus.fromIngredient(ingredient);
    final searchMatch = PantrySearchEngine.matchIngredient(
      ingredient,
      searchQuery,
    );
    final matchedAlias = searchMatch.matchedThroughAlias
        ? searchMatch.matchedAlias
        : null;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _IngredientEmoji(
            emoji: IngredientPresentation.emoji(
              ingredient,
              ref.watch(canonicalIngredientRegistryProvider),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SearchHighlightText(
                        text: ingredient.name,
                        query: searchQuery,
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
                SearchHighlightText(
                  text: ingredient.category,
                  query: searchQuery,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
                if (matchedAlias != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 15,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Expanded(
                        child: Text(
                          'ตรงกับคำค้น “$matchedAlias”',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _IngredientDetail(
                      icon: Icons.inventory_2_outlined,
                      text: UnitPresentation.quantity(
                        ingredient.quantity,
                        ingredient.canonicalUnitId.isEmpty
                            ? ingredient.unit
                            : ingredient.canonicalUnitId,
                        maximumFractionDigits: 1,
                      ),
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: ingredient.isFavorite
                    ? 'นำออกจากรายการโปรด'
                    : 'เพิ่มในรายการโปรด',
                onPressed: onFavoriteToggle,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Icon(
                    ingredient.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    key: ValueKey<bool>(ingredient.isFavorite),
                    color: ingredient.isFavorite
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'แก้ไขวัตถุดิบ',
                onPressed: onEdit,
                color: AppColors.textMuted,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'ลบวัตถุดิบ',
                onPressed: onDelete,
                color: AppColors.textMuted,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
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
