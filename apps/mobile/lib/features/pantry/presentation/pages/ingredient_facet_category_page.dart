import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../domain/models/ingredient_browse_facet.dart';
import '../providers/ingredient_picker_providers.dart';
import '../widgets/ingredient_option_tile.dart';
import '../widgets/picker_sticky_continue_bar.dart';
import 'ingredient_batch_review_page.dart';

/// A flat browse facet (e.g. "อาหารแปรรูป", "ผัก") — unlike
/// [IngredientFamilyPage], this never nests further; every member is shown
/// as a single flat list, each with its own *real* canonical breadcrumb
/// (its actual taxonomy ancestry, if any), not the facet's own label —
/// showing "หมู" for moo_yor here is more useful than repeating
/// "อาหารแปรรูป", which is already the screen title.
class IngredientFacetCategoryPage extends ConsumerWidget {
  const IngredientFacetCategoryPage({super.key, required this.facetId});

  final String facetId;

  Future<void> _openReview(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const IngredientBatchReviewPage(),
      ),
    );
    if (result == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facet = ingredientBrowseFacets.firstWhere((f) => f.id == facetId);
    final registry = ref.watch(canonicalIngredientRegistryProvider);
    final members = ref.watch(ingredientBrowseFacetMembersProvider(facetId));
    final selection = ref.watch(ingredientPickerSelectionProvider);
    final ownedIds = ref.watch(pantryCanonicalIngredientIdsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(facet.displayName)),
      body: SafeArea(
        child: members.isEmpty
            ? const Center(
                key: ValueKey<String>('ingredient-facet-empty-state'),
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('ยังไม่มีวัตถุดิบในหมวดนี้'),
                ),
              )
            : ListView.builder(
                key: ValueKey<String>('ingredient-facet-list-$facetId'),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final ingredient = members[index];
                  final breadcrumb = registry == null
                      ? const <String>[]
                      : registry
                            .ancestorChainFor(ingredient.id)
                            .map((id) => registry.byId(id)?.displayName() ?? id)
                            .toList(growable: false);
                  return IngredientOptionTile(
                    ingredient: ingredient,
                    breadcrumb: breadcrumb,
                    selected: selection.contains(ingredient.id),
                    alreadyInPantry: ownedIds.contains(ingredient.id),
                    onTap: () => ref
                        .read(ingredientPickerSelectionProvider.notifier)
                        .toggle(ingredient.id),
                  );
                },
              ),
      ),
      bottomNavigationBar: selection.isEmpty
          ? null
          : PickerStickyContinueBar(
              selectedCount: selection.length,
              onPressed: () => _openReview(context),
            ),
    );
  }
}
