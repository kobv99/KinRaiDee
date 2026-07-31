import 'package:flutter/material.dart';

import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/design_tokens/app_colors.dart';
import '../../../../core/design_system/design_tokens/app_radius.dart';
import '../../../../core/design_system/design_tokens/app_spacing.dart';
import '../../../../core/design_system/design_tokens/app_typography.dart';
import 'home_recipe_filter.dart';

class _MetricSpec {
  const _MetricSpec({
    required this.filter,
    required this.icon,
    required this.value,
    required this.label,
  });
  final HomeRecipeFilter? filter; // null = not selectable (expiring soon)
  final IconData icon;
  final int value;
  final String label;
}

/// One polished card holding all daily summary metrics with equal visual
/// weight, per the design acceptance review — replaces the old row of
/// floating unconnected icons.
///
/// "Pantry Friendly" counts recipes with a match score of 70%+ that are
/// not already fully ready (a subset between "just browsing" and "ready
/// to cook now") — a real threshold applied to the existing match score,
/// not a fabricated number.
class DailySummaryCard extends StatelessWidget {
  const DailySummaryCard({
    super.key,
    required this.totalRecipes,
    required this.readyToCookCount,
    required this.pantryFriendlyCount,
    required this.quickRecipeCount,
    required this.expiringSoonCount,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.onOpenPantry,
  });

  final int totalRecipes;
  final int readyToCookCount;
  final int pantryFriendlyCount;
  final int quickRecipeCount;
  final int expiringSoonCount;
  final HomeRecipeFilter selectedFilter;
  final ValueChanged<HomeRecipeFilter> onFilterSelected;
  final VoidCallback onOpenPantry;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricSpec(
        filter: HomeRecipeFilter.all,
        icon: Icons.menu_book_outlined,
        value: totalRecipes,
        label: 'สูตรทั้งหมด',
      ),
      _MetricSpec(
        filter: HomeRecipeFilter.readyToCook,
        icon: Icons.check_circle_outline,
        value: readyToCookCount,
        label: 'พร้อมครบ',
      ),
      _MetricSpec(
        filter: HomeRecipeFilter.pantryFriendly,
        icon: Icons.eco_outlined,
        value: pantryFriendlyCount,
        label: 'Pantry Friendly',
      ),
      _MetricSpec(
        filter: HomeRecipeFilter.quick,
        icon: Icons.bolt_outlined,
        value: quickRecipeCount,
        label: 'เมนูด่วน',
      ),
      _MetricSpec(
        filter: null,
        icon: Icons.schedule_outlined,
        value: expiringSoonCount,
        label: 'ใกล้หมดอายุ',
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      child: Row(
        children: metrics
            .map(
              (m) => Expanded(
                child: _MetricTile(
                  spec: m,
                  selected: m.filter != null && m.filter == selectedFilter,
                  onTap: m.filter != null
                      ? () => onFilterSelected(m.filter!)
                      : onOpenPantry,
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.spec, required this.selected, required this.onTap});
  final _MetricSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${spec.label} ${spec.value}',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mediumRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  spec.icon,
                  size: 16,
                  color: selected ? AppColors.textOnPrimary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text('${spec.value}', style: AppTypography.title),
              Text(
                spec.label,
                style: AppTypography.caption,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
