import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../core/domain/ingredients/canonical_ingredient.dart';
import '../providers/ingredient_picker_providers.dart';
import '../widgets/ingredient_family_card.dart';
import '../widgets/ingredient_option_tile.dart';
import '../widgets/picker_sticky_continue_bar.dart';
import 'ingredient_batch_review_page.dart';

/// A single family's children: direct selectable ingredients and any
/// nested families, at arbitrary taxonomy depth (each nested family opens
/// another instance of this same page). The breadcrumb always comes from
/// the registry's own root-first ancestor chain — never assembled from
/// navigation-stack bookkeeping.
class IngredientFamilyPage extends ConsumerWidget {
  const IngredientFamilyPage({super.key, required this.familyId});

  final String familyId;

  Future<void> _openNestedFamily(BuildContext context, String nestedId) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => IngredientFamilyPage(familyId: nestedId),
      ),
    );
    if (result == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

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
    final registry = ref.watch(canonicalIngredientRegistryProvider);
    final family = registry?.byId(familyId);
    final children = ref.watch(ingredientFamilyChildrenProvider(familyId));
    final selection = ref.watch(ingredientPickerSelectionProvider);
    final ownedIds = ref.watch(pantryCanonicalIngredientIdsProvider);

    final breadcrumbIds = registry == null
        ? const <String>[]
        : <String>[...registry.ancestorChainFor(familyId), familyId];
    final breadcrumbNames = breadcrumbIds
        .map((id) => registry?.byId(id)?.displayName() ?? id)
        .toList(growable: false);

    final selectableChildren = children
        .where(
          (child) => child.nodeType == CanonicalIngredientNodeType.ingredient,
        )
        .toList(growable: false);
    final nestedFamilies = children
        .where((child) => child.nodeType == CanonicalIngredientNodeType.family)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(family?.displayName() ?? familyId)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (breadcrumbNames.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  key: const ValueKey<String>('ingredient-picker-breadcrumb'),
                  breadcrumbNames.join(' › '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Expanded(
              child: ListView(
                key: ValueKey<String>('ingredient-family-list-$familyId'),
                children: [
                  ...selectableChildren.map(
                    (child) => IngredientOptionTile(
                      ingredient: child,
                      selected: selection.contains(child.id),
                      alreadyInPantry: ownedIds.contains(child.id),
                      onTap: () => ref
                          .read(ingredientPickerSelectionProvider.notifier)
                          .toggle(child.id),
                    ),
                  ),
                  ...nestedFamilies.map(
                    (nested) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: IngredientFamilyCard(
                        id: nested.id,
                        displayName: nested.displayName(),
                        emoji: nested.emoji,
                        onTap: () => _openNestedFamily(context, nested.id),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
