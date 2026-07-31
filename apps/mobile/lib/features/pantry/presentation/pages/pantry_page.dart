import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/navigation/app_navigation_provider.dart';
import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/models/ingredient.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../recipe/domain/services/main_ingredient_resolver.dart';
import '../../../recipe/presentation/providers/recipe_provider.dart';
import '../../domain/models/food_category.dart';
import '../../domain/services/pantry_expiry_priority.dart';
import '../../domain/services/pantry_search_engine.dart';
import '../providers/pantry_filter_provider.dart';
import '../widgets/add_ingredient_dialog.dart';
import '../widgets/ingredient_card.dart';
import '../widgets/pantry_catalog_panel.dart';
import '../widgets/pantry_filter_bar.dart';
import '../widgets/pantry_frequent_section.dart';
import '../widgets/pantry_overview_card.dart';
import '../widgets/pantry_search_field.dart';
import '../widgets/pantry_use_soon_section.dart';

class PantryPage extends ConsumerStatefulWidget {
  const PantryPage({super.key});

  @override
  ConsumerState<PantryPage> createState() => _PantryPageState();
}

class _PantryPageState extends ConsumerState<PantryPage> {
  final TextEditingController _searchController = TextEditingController();

  String? _loadingRecipeIngredientId;

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

  Future<void> _addFrequentIngredient(FoodCatalogItem entry) async {
    final ingredient = await showDialog<Ingredient>(
      context: context,
      builder: (context) {
        return AddIngredientDialog(initialCatalogItem: entry);
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

  Future<void> _findRecipesForIngredient(Ingredient ingredient) async {
    if (PantryExpiryPriority.isExpired(ingredient)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ingredient.name} หมดอายุแล้ว โปรดตรวจสอบก่อนนำไปทำอาหาร',
          ),
        ),
      );
      return;
    }

    setState(() {
      _loadingRecipeIngredientId = ingredient.id;
    });

    try {
      final recipes = await ref.read(recipesProvider.future);
      final resolution = const MainIngredientResolver().resolve(
        pantryIngredientName: ingredient.name,
        canonicalIngredientId: ingredient.canonicalIngredientId,
        registry: ref.read(canonicalIngredientRegistryProvider),
        recipes: recipes,
      );

      if (!mounted) {
        return;
      }

      if (resolution == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ยังไม่มีสูตรที่ใช้ ${ingredient.name} เป็นวัตถุดิบหลัก',
            ),
          ),
        );
        return;
      }

      final urgency = PantryExpiryPriority.urgencyLabel(ingredient);
      await ref
          .read(heroSelectionProvider.notifier)
          .selectForSession(
            resolution.key,
            reason: 'เลือกจาก Pantry เพราะ ${ingredient.name} $urgency',
          );
      ref.read(recommendationSessionProvider.notifier).reset();
      ref.read(appNavigationProvider.notifier).openRecipes();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'เปิดเมนูไม่สำเร็จ กรุณาลองใหม่อีกครั้ง ข้อมูลใน Pantry ยังปลอดภัย',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingRecipeIngredientId = null;
        });
      }
    }
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
    final favoriteNames = ref.watch(favoriteIngredientNamesProvider);
    final frequentItems = allFoodCatalogItems
        .where(
          (entry) => favoriteNames.contains(
            normalizePantryIngredientName(entry.item.name),
          ),
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('คลังวัตถุดิบ')),
      body: SafeArea(
        child: _PantryContent(
          allIngredients: allIngredients,
          visibleIngredients: visibleIngredients,
          frequentItems: frequentItems,
          filter: filter,
          categories: categories,
          searchController: _searchController,
          loadingRecipeIngredientId: _loadingRecipeIngredientId,
          onFindRecipes: _findRecipesForIngredient,
          onAddIngredient: () => _addIngredient(),
          onAddIngredientFromSearch: _addIngredient,
          onAddFrequentIngredient: _addFrequentIngredient,
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
          onFavoriteToggle: (ingredient) {
            ref.read(pantryProvider.notifier).toggleFavorite(ingredient.id);
          },
          onRemoveFrequentIngredient: (entry) {
            ref
                .read(pantryProvider.notifier)
                .removeFavoriteByName(entry.item.name);
          },
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
    required this.frequentItems,
    required this.filter,
    required this.categories,
    required this.searchController,
    required this.loadingRecipeIngredientId,
    required this.onFindRecipes,
    required this.onAddIngredient,
    required this.onAddIngredientFromSearch,
    required this.onAddFrequentIngredient,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onExpiringChanged,
    required this.onSortChanged,
    required this.onClearFilters,
    required this.onDelete,
    required this.onEdit,
    required this.onFavoriteToggle,
    required this.onRemoveFrequentIngredient,
  });

  final List<Ingredient> allIngredients;
  final List<Ingredient> visibleIngredients;
  final List<FoodCatalogItem> frequentItems;
  final PantryFilterState filter;
  final List<String> categories;
  final TextEditingController searchController;
  final String? loadingRecipeIngredientId;
  final ValueChanged<Ingredient> onFindRecipes;
  final VoidCallback onAddIngredient;
  final ValueChanged<String?> onAddIngredientFromSearch;
  final ValueChanged<FoodCatalogItem> onAddFrequentIngredient;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onExpiringChanged;
  final ValueChanged<PantrySortOption> onSortChanged;
  final VoidCallback onClearFilters;
  final ValueChanged<Ingredient> onDelete;
  final ValueChanged<Ingredient> onEdit;
  final ValueChanged<Ingredient> onFavoriteToggle;
  final ValueChanged<FoodCatalogItem> onRemoveFrequentIngredient;

  List<FoodCatalogItem> get _catalogSuggestions {
    return PantrySearchEngine.rankCatalogItems(
      allFoodCatalogItems,
      filter.searchQuery,
    ).take(8).toList(growable: false);
  }

  List<Ingredient> get _useSoonIngredients {
    return PantryExpiryPriority.useSoonItems(allIngredients, limit: 3);
  }

  @override
  Widget build(BuildContext context) {
    final expiringCount = PantryExpiryPriority.useSoonItems(
      allIngredients,
    ).length;
    final searchQuery = filter.searchQuery.trim();
    final suggestions = _catalogSuggestions;
    final useSoonIngredients = _useSoonIngredients;

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
                  sliver: const SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'วัตถุดิบของคุณ',
                      subtitle:
                          'จัดการของที่มี ใช้ของให้ทัน และหยิบของโปรดได้เร็วขึ้น',
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
                    child: PantryOverviewCard(
                      totalCount: allIngredients.length,
                      expiringCount: expiringCount,
                      favoriteCount: frequentItems.length,
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
                        PantrySearchField(
                          controller: searchController,
                          onChanged: onSearchChanged,
                          onClear: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                        ),
                        if (searchQuery.isNotEmpty &&
                            suggestions.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          PantryCatalogPanel(
                            suggestions: suggestions,
                            searchQuery: searchQuery,
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
                if (useSoonIngredients.isNotEmpty)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      AppSpacing.sm,
                      horizontalPadding,
                      AppSpacing.md,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: PantryUseSoonSection(
                        ingredients: useSoonIngredients,
                        loadingIngredientId: loadingRecipeIngredientId,
                        onFindRecipes: onFindRecipes,
                      ),
                    ),
                  ),
                if (frequentItems.isNotEmpty)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      AppSpacing.sm,
                      horizontalPadding,
                      AppSpacing.md,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: PantryFrequentSection(
                        items: frequentItems,
                        onItemTap: onAddFrequentIngredient,
                        onRemove: onRemoveFrequentIngredient,
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  sliver: SliverToBoxAdapter(
                    child: PantryFilterBar(
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
                      _buildResultLabel(searchQuery),
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
                          ? 'ไม่พบคำนี้หรือคำใกล้เคียงในรายการวัตถุดิบ ลองใช้คำค้นหาอื่น'
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
                      description: frequentItems.isEmpty
                          ? 'พิมพ์ชื่อวัตถุดิบด้านบน หรือกดปุ่มเพิ่มวัตถุดิบเพื่อเริ่มใช้งาน'
                          : 'เลือกจากซื้อประจำด้านบน หรือเพิ่มวัตถุดิบรายการใหม่',
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
                          : suggestions.isEmpty
                          ? 'ไม่พบคำนี้หรือคำใกล้เคียง ลองใช้คำค้นหาอื่น'
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
                          searchQuery: searchQuery,
                          onEdit: () => onEdit(ingredient),
                          onFavoriteToggle: () => onFavoriteToggle(ingredient),
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

  String _buildResultLabel(String searchQuery) {
    if (searchQuery.isNotEmpty) {
      return 'พบ ${visibleIngredients.length} จาก ${allIngredients.length} รายการ • เรียงตามความใกล้เคียง';
    }

    if (!filter.hasActiveFilters &&
        filter.sortOption == PantrySortOption.expirySoonest) {
      return 'แสดงทั้งหมด ${visibleIngredients.length} รายการ • ของใกล้หมดอายุอยู่ด้านบน';
    }

    return 'พบ ${visibleIngredients.length} จาก ${allIngredients.length} รายการ';
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

    if (confirmed ?? false) {
      onConfirmed();
    }
  }
}
