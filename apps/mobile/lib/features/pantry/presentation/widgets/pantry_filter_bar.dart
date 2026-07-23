import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../providers/pantry_filter_provider.dart';

class PantryFilterBar extends StatelessWidget {
  const PantryFilterBar({
    required this.categories,
    required this.filter,
    required this.onCategoryChanged,
    required this.onExpiringChanged,
    required this.onSortChanged,
    required this.onClearFilters,
    super.key,
  });

  final List<String> categories;
  final PantryFilterState filter;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onExpiringChanged;
  final ValueChanged<PantrySortOption> onSortChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('ทั้งหมด'),
                  selected: filter.selectedCategory == null,
                  onSelected: (_) => onCategoryChanged(null),
                ),
                const SizedBox(width: AppSpacing.xs),
                for (final category in categories) ...[
                  ChoiceChip(
                    label: Text(category),
                    selected: filter.selectedCategory == category,
                    onSelected: (_) => onCategoryChanged(category),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                FilterChip(
                  avatar: const Icon(Icons.schedule_rounded, size: 18),
                  label: const Text('ใกล้หมดอายุ'),
                  selected: filter.onlyExpiringSoon,
                  onSelected: (_) => onExpiringChanged(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        PopupMenuButton<PantrySortOption>(
          tooltip: 'เรียงลำดับ',
          initialValue: filter.sortOption,
          onSelected: onSortChanged,
          itemBuilder: (context) {
            return PantrySortOption.values.map((option) {
              return PopupMenuItem<PantrySortOption>(
                value: option,
                child: Row(
                  children: [
                    if (option == filter.sortOption)
                      const Icon(Icons.check_rounded, size: 19)
                    else
                      const SizedBox(width: 19),
                    const SizedBox(width: AppSpacing.xs),
                    Text(option.label),
                  ],
                ),
              );
            }).toList(growable: false);
          },
          icon: const Icon(Icons.sort_rounded),
        ),
        if (filter.hasActiveFilters)
          IconButton(
            tooltip: 'ล้างตัวกรอง',
            onPressed: onClearFilters,
            icon: const Icon(Icons.filter_alt_off_outlined),
          ),
      ],
    );
  }
}
