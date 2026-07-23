import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/models/ingredient.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../domain/models/food_category.dart';
import '../providers/pantry_filter_provider.dart';
import '../widgets/add_ingredient_dialog.dart';
import '../widgets/ingredient_card.dart';

class PantryPage extends ConsumerStatefulWidget {
  const PantryPage({super.key});

  @override
  ConsumerState<PantryPage> createState() => _PantryPageState();
}

class _PantryPageState extends ConsumerState<PantryPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addIngredient([String? initialSearchQuery]) async {
    final ingredient = await showDialog<Ingredient>(
      context: context,
      builder: (context) {
        return AddIngredientDialog(initialSearchQuery: initialSearchQuery);
      },
    );

    if (ingredient == null || !mounted) {
      return;
    }

    await ref.read(pantryProvider.notifier).addIngredient(ingredient);
    _clearFilters();
  }

  Future<void> _editIngredient(Ingredient originalIngredient) async {
    final updatedIngredient = await showDialog<Ingredient>(
      context: context,
      builder: (context) {
        return AddIngredientDialog(ingredient: originalIngredient);
      },
    );

    if (updatedIngredient == null || !mounted) {
      return;
    }

    await ref.read(pantryProvider.notifier).updateIngredient(updatedIngredient);
  }

  void _clearFilters() {
    _searchController.clear();
    ref.read(pantryFilterProvider.notifier).clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final allIngredients = ref.watch(pantryProvider);
    final visibleIngredients = ref.watch(filteredPantryProvider);
    final filter = ref.watch(pantryFilterProvider);
    final categories = ref.watch(pantryCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('คลังวัตถุดิบ')),
      body: SafeArea(
        child: _PantryContent(
          allIngredients: allIngredients,
          visibleIngredients: visibleIngredients,
          filter: filter,
          categories: categories,
          searchController: _searchController,
          onAddIngredient: () => _addIngredient(),
          onAddIngredientFromSearch: _addIngredient,
          onEdit: _editIngredient,
          onSearchChanged: (value) {
            ref.read(pantryFilterProvider.notifier).setSearchQuery(value);
          },
          onCategoryChanged: (category) {
            ref.read(pantryFilterProvider.notifier).setCategory(category);
          },
          onExpiringChanged: () {
            ref.read(pantryFilterProvider.notifier).toggleExpiringSoon();
          },
          onSortChanged: (option) {
            ref.read(pantryFilterProvider.notifier).setSortOption(option);
          },
          onClearFilters: _clearFilters,
          onDelete: (ingredient) async {
            await ref
                .read(pantryProvider.notifier)
                .removeIngredient(ingredient.id);
          },
        ),
      ),
      floatingActionButton: allIngredients.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _addIngredient(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('เพิ่มวัตถุดิบ'),
            )
          : null,
    );
  }
}

class _PantryContent extends StatelessWidget {
  const _PantryContent({
    required this.allIngredients,
    required this.visibleIngredients,
    required this.filter,
    required this.categories,
    required this.searchController,
    required this.onAddIngredient,
    required this.onAddIngredientFromSearch,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onExpiringChanged,
    required this.onSortChanged,
    required this.onClearFilters,
    required this.onDelete,
    required this.onEdit,
  });

  final List<Ingredient> allIngredients;
  final List<Ingredient> visibleIngredients;
  final PantryFilterState filter;
  final List<String> categories;
  final TextEditingController searchController;
  final VoidCallback onAddIngredient;
  final ValueChanged<String?> onAddIngredientFromSearch;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onExpiringChanged;
  final ValueChanged<PantrySortOption> onSortChanged;
  final VoidCallback onClearFilters;
  final ValueChanged<Ingredient> onDelete;
  final ValueChanged<Ingredient> onEdit;

  List<FoodCatalogItem> get _catalogSuggestions {
    final query = filter.searchQuery.trim();
    if (query.isEmpty) {
      return const <FoodCatalogItem>[];
    }

    return allFoodCatalogItems
        .where((entry) {
          return entry.item.matches(query) ||
              entry.category.toLowerCase().contains(query.toLowerCase());
        })
        .take(8)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final expiringCount = allIngredients.where((ingredient) {
      final days = ingredient.daysUntilExpiry;
      return days != null && days <= 7;
    }).length;
    final searchQuery = filter.searchQuery.trim();
    final suggestions = _catalogSuggestions;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900
            ? AppSpacing.xl
            : AppSpacing.screenHorizontal;
        final contentWidth = constraints.maxWidth >= 1100
            ? 1000.0
            : double.infinity;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: contentWidth,
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AppSpacing.md,
                    horizontalPadding,
                    AppSpacing.sm,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'วัตถุดิบของคุณ',
                      subtitle: _buildSubtitle(
                        totalCount: allIngredients.length,
                        expiringCount: expiringCount,
                      ),
                      icon: Icons.kitchen_outlined,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AppSpacing.sm,
                    horizontalPadding,
                    AppSpacing.sm,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _PantrySearchField(
                          controller: searchController,
                          onChanged: onSearchChanged,
                          onClear: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                        ),
                        if (searchQuery.isNotEmpty && suggestions.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          _CatalogSuggestionPanel(
                            suggestions: suggestions,
                            onSelected: (entry) {
                              FocusScope.of(context).unfocus();
                              onAddIngredientFromSearch(entry.item.name);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  sliver: SliverToBoxAdapter(
                    child: _PantryFilterBar(
                      categories: categories,
                      filter: filter,
                      onCategoryChanged: onCategoryChanged,
                      onExpiringChanged: onExpiringChanged,
                      onSortChanged: onSortChanged,
                      onClearFilters: onClearFilters,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AppSpacing.sm,
                    horizontalPadding,
                    AppSpacing.sm,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      _buildResultLabel(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                if (allIngredients.isEmpty && searchQuery.isNotEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.add_circle_outline_rounded,
                      title: 'ยังไม่มี "$searchQuery" ในคลัง',
                      description: suggestions.isEmpty
                          ? 'ไม่พบคำนี้ในรายการวัตถุดิบ ลองใช้คำค้นหาอื่น'
                          : 'เลือกรายการแนะนำด้านบนเพื่อเพิ่มวัตถุดิบเข้าคลัง',
                      actionLabel: 'เปิดหน้ารวมวัตถุดิบ',
                      onActionPressed: () {
                        onAddIngredientFromSearch(searchQuery);
                      },
                    ),
                  )
                else if (allIngredients.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.kitchen_outlined,
                      title: 'ยังไม่มีวัตถุดิบ',
                      description:
                          'พิมพ์ชื่อวัตถุดิบด้านบน หรือกดปุ่มเพิ่มวัตถุดิบเพื่อเริ่มใช้งาน',
                      actionLabel: 'เพิ่มวัตถุดิบ',
                      onActionPressed: onAddIngredient,
                    ),
                  )
                else if (visibleIngredients.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'ไม่พบวัตถุดิบในคลัง',
                      description: searchQuery.isEmpty
                          ? 'ลองเปลี่ยนหมวดอาหารหรือตัวกรองที่เลือก'
                          : 'เลือกรายการแนะนำด้านบนเพื่อเพิ่มเข้าคลัง',
                      actionLabel: searchQuery.isEmpty
                          ? 'ล้างตัวกรอง'
                          : 'เปิดหน้ารวมวัตถุดิบ',
                      onActionPressed: searchQuery.isEmpty
                          ? onClearFilters
                          : () => onAddIngredientFromSearch(searchQuery),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      112,
                    ),
                    sliver: SliverList.separated(
                      itemCount: visibleIngredients.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final ingredient = visibleIngredients[index];
                        return IngredientCard(
                          ingredient: ingredient,
                          onEdit: () => onEdit(ingredient),
                          onDelete: () {
                            _confirmDelete(
                              context: context,
                              ingredient: ingredient,
                              onConfirmed: () => onDelete(ingredient),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _buildResultLabel() {
    if (!filter.hasActiveFilters) {
      return 'แสดงทั้งหมด ${visibleIngredients.length} รายการ';
    }
    return 'พบ ${visibleIngredients.length} จาก ${allIngredients.length} รายการ';
  }

  String _buildSubtitle({required int totalCount, required int expiringCount}) {
    if (expiringCount == 0) {
      return 'ทั้งหมด $totalCount รายการ';
    }
    return 'ทั้งหมด $totalCount รายการ • ใกล้หมดอายุ $expiringCount รายการ';
  }

  Future<void> _confirmDelete({
    required BuildContext context,
    required Ingredient ingredient,
    required VoidCallback onConfirmed,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ลบวัตถุดิบ'),
          content: Text('ต้องการลบ "${ingredient.name}" ออกจากคลังหรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('ลบ'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      onConfirmed();
    }
  }
}

class _CatalogSuggestionPanel extends StatelessWidget {
  const _CatalogSuggestionPanel({
    required this.suggestions,
    required this.onSelected,
  });

  final List<FoodCatalogItem> suggestions;
  final ValueChanged<FoodCatalogItem> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: suggestions.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final entry = suggestions[index];
            return ListTile(
              dense: true,
              leading: Text(
                entry.item.emoji,
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(entry.item.name),
              subtitle: Text(entry.category),
              trailing: const Icon(Icons.add_circle_outline_rounded),
              onTap: () => onSelected(entry),
            );
          },
        ),
      ),
    );
  }
}

class _PantrySearchField extends StatelessWidget {
  const _PantrySearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'ค้นหาในคลัง หรือพิมพ์ชื่อเพื่อเพิ่มวัตถุดิบ',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'ล้างคำค้นหา',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }
}

class _PantryFilterBar extends StatelessWidget {
  const _PantryFilterBar({
    required this.categories,
    required this.filter,
    required this.onCategoryChanged,
    required this.onExpiringChanged,
    required this.onSortChanged,
    required this.onClearFilters,
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
