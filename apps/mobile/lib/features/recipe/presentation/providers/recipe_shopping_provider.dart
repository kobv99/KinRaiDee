import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/pantry_provider.dart';
import '../../../pantry/application/inventory_transaction_providers.dart';
import '../../../shopping/application/shopping_providers.dart';
import '../../../shopping/domain/entities/shopping_item_status.dart';
import '../../../shopping/domain/entities/shopping_list.dart';
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
/// [ShoppingItem.sourceReferenceIds]).
///
/// Deliberately a plain function rather than a `Provider.family`: Recipe
/// Detail and the Cooking Wizard are two separate `ConsumerStatefulWidget`s
/// that can both be mounted at once (the wizard is pushed on top of Recipe
/// Detail, not instead of it), and both need this same per-recipe set. A
/// `Provider.family` instance for a given `recipeId` would then be watched
/// by two independently-paused/resumed widget subscriptions at the same
/// time across the very Navigator push transition that was implicated in
/// the Sprint 5.6 blank-body report — one extra shared provider hop that a
/// plain function watching the already-fetched shopping lists avoids
/// entirely. Callers already watch [shoppingListsProvider] themselves (or
/// can cheaply do so) and pass the resolved value in here.
Set<String> recipeIngredientIdsInShopping(
  List<ShoppingList> lists,
  String recipeId,
) {
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
}
