// ignore_for_file: prefer_initializing_formals

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pantry/application/inventory_transaction_coordinator.dart';
import '../../pantry/application/inventory_transaction_providers.dart';
import '../data/repositories/local_shopping_repository.dart';
import '../domain/entities/shopping_list.dart';
import '../domain/models/shopping_mutation.dart';
import '../domain/repositories/shopping_repository.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return LocalShoppingRepository(ref.watch(inventoryCommitRepositoryProvider));
});

final shoppingListsProvider = FutureProvider<List<ShoppingList>>((ref) {
  return ref.watch(shoppingRepositoryProvider).getLists();
});

class ShoppingMutationController {
  ShoppingMutationController({
    required InventoryTransactionCoordinator coordinator,
    required void Function() onDurableCommit,
  }) : _coordinator = coordinator,
       _onDurableCommit = onDurableCommit;

  final InventoryTransactionCoordinator _coordinator;
  final void Function() _onDurableCommit;

  Future<InventoryTransactionResult> execute(ShoppingMutation command) async {
    final result = await _coordinator.mutateShopping(command);
    if (!result.isSuccess) {
      return result;
    }
    final transactionId = result.transaction?.transactionId;
    if (result.outcome == InventoryTransactionOutcome.committed &&
        transactionId != null) {
      await _coordinator.completePresentation(transactionId);
    }
    _onDurableCommit();
    return result;
  }
}

final shoppingMutationControllerProvider = Provider<ShoppingMutationController>(
  (ref) {
    return ShoppingMutationController(
      coordinator: ref.watch(inventoryTransactionCoordinatorProvider),
      onDurableCommit: () => ref.invalidate(shoppingListsProvider),
    );
  },
);
