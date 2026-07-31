import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/pantry_provider.dart';
import '../../../pantry/application/inventory_transaction_providers.dart';
import '../../../shopping/application/shopping_providers.dart';
import '../../../shopping/domain/entities/shopping_item_status.dart';
import '../../application/recipe_missing_shopping_controller.dart';

final recipeMissingShoppingControllerProvider =
    Provider<RecipeMissingShoppingController?>((ref) {
      final engine = ref.watch(shoppingEngineProvider);
      if (engine == null) {
        return null;
      }
      return RecipeMissingShoppingController(
        engine: engine,
        shoppingRepository: ref.watch(shoppingRepositoryProvider),
        executeShoppingMutation: ref
            .watch(shoppingMutationControllerProvider)
            .execute,
        readPantry: () => ref.read(pantryProvider),
        clock: ref.watch(appClockProvider),
      );
    });

/// Canonical ingredient ids for [recipeId] that already have an active
/// Shopping item sourced from that recipe (via
/// [ShoppingItem.sourceReferenceIds]). Recomputes whenever the Shopping
/// lists change, so Recipe Detail can distinguish "missing and not
/// planned" from "missing but already in Shopping" and stay reactive when
/// items are added, purchased, or removed from Shopping elsewhere.
final recipeIngredientIdsInShoppingProvider =
    Provider.family<Set<String>, String>((ref, recipeId) {
      final lists = ref.watch(shoppingListsProvider).value ?? const [];
      final ids = <String>{};
      for (final list in lists) {
        for (final item in list.items) {
          if (item.status != ShoppingItemStatus.active) {
            continue;
          }
          if (item.sourceReferenceIds.contains(recipeId)) {
            ids.add(item.canonicalIngredientId);
          }
        }
      }
      return ids;
    });
