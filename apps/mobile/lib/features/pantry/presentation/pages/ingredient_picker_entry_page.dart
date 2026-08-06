import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/ingredient_browse_facet.dart';
import '../providers/ingredient_picker_providers.dart';
import '../widgets/ingredient_family_card.dart';
import '../widgets/ingredient_search_result_tile.dart';
import '../widgets/picker_sticky_continue_bar.dart';
import 'ingredient_batch_review_page.dart';
import 'ingredient_facet_category_page.dart';
import 'ingredient_family_page.dart';
import 'ingredient_quick_add_page.dart';

/// Entry point of the multi-select ingredient picker: a global search field
/// plus 15 root browse categories (9 real taxonomy families + 6 browse
/// facets, both rendered through the same unchanged card component). The
/// family count is read from the registry at runtime, never hardcoded —
/// adding a 9th (or Nth) taxonomy root requires no change here.
/// Contains no recipe/compatibility logic. Browse-mode taps only toggle
/// the shared session state (committed later from batch review); search
/// results instead open a direct single-item quick-add — the two flows
/// share no selection state.
class IngredientPickerEntryPage extends ConsumerStatefulWidget {
  const IngredientPickerEntryPage({super.key});

  @override
  ConsumerState<IngredientPickerEntryPage> createState() =>
      _IngredientPickerEntryPageState();
}

class _IngredientPickerEntryPageState
    extends ConsumerState<IngredientPickerEntryPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFamily(String familyId) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => IngredientFamilyPage(familyId: familyId),
      ),
    );
    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openFacet(String facetId) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => IngredientFacetCategoryPage(facetId: facetId),
      ),
    );
    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openReview() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const IngredientBatchReviewPage(),
      ),
    );
    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// Search's direct-add is a separate, single-item flow — a successful
  /// add returns to the search results (not out of the whole picker), so
  /// the user can keep searching and adding more without losing their
  /// place. It never touches the Browse selection session.
  Future<void> _openQuickAdd(String canonicalId) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => IngredientQuickAddPage(canonicalId: canonicalId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(ingredientPickerSelectionProvider);
    final ownedIds = ref.watch(pantryCanonicalIngredientIdsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('เลือกวัตถุดิบ')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                key: const ValueKey<String>('ingredient-picker-search-field'),
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'ค้นหาวัตถุดิบ...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: _query.trim().isEmpty
                  ? _CategoryGrid(
                      onFamilyTap: _openFamily,
                      onFacetTap: _openFacet,
                    )
                  : _SearchResults(
                      query: _query,
                      ownedIds: ownedIds,
                      onSelect: _openQuickAdd,
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: selection.isEmpty
          ? null
          : PickerStickyContinueBar(
              selectedCount: selection.length,
              onPressed: _openReview,
            ),
    );
  }
}

class _CategoryGrid extends ConsumerWidget {
  const _CategoryGrid({required this.onFamilyTap, required this.onFacetTap});

  final ValueChanged<String> onFamilyTap;
  final ValueChanged<String> onFacetTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final families = ref.watch(rootIngredientFamiliesProvider);
    if (families.isEmpty) {
      return const Center(child: Text('ไม่พบหมวดหมู่วัตถุดิบ'));
    }
    // Same approved grid: unchanged column count, spacing, card size,
    // typography. The only change is the number of tiles it renders — the
    // real taxonomy families (dynamic, from the registry — currently 9,
    // but this reads registry.length so it never needs a code change)
    // followed by the 6 approved browse facets (static, from the domain
    // layer).
    final tileCount = families.length + ingredientBrowseFacets.length;
    return GridView.builder(
      key: const ValueKey<String>('ingredient-picker-family-grid'),
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
      ),
      itemCount: tileCount,
      itemBuilder: (context, index) {
        if (index < families.length) {
          final family = families[index];
          return IngredientFamilyCard(
            id: family.id,
            displayName: family.displayName(),
            emoji: family.emoji,
            onTap: () => onFamilyTap(family.id),
          );
        }
        final facet = ingredientBrowseFacets[index - families.length];
        return IngredientFamilyCard(
          id: facet.id,
          displayName: facet.displayName,
          emoji: facet.emoji,
          onTap: () => onFacetTap(facet.id),
        );
      },
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.query,
    required this.ownedIds,
    required this.onSelect,
  });

  final String query;
  final Set<String> ownedIds;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(ingredientSearchResultsProvider(query));
    if (results.isEmpty) {
      return const Center(child: Text('ไม่พบวัตถุดิบที่ค้นหา'));
    }
    return ListView.builder(
      key: const ValueKey<String>('ingredient-picker-search-results'),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        final id = result.ingredient.id;
        return IngredientSearchResultTile(
          result: result,
          alreadyInPantry: ownedIds.contains(id),
          onTap: () => onSelect(id),
        );
      },
    );
  }
}
