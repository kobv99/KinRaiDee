// ignore_for_file: prefer_initializing_formals

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/canonical_ingredient_providers.dart';
import '../../../core/providers/pantry_provider.dart';
import '../../pantry/application/inventory_transaction_coordinator.dart';
import '../../pantry/application/inventory_transaction_providers.dart';
import '../../pantry/domain/models/pantry_quantity_transaction.dart';
import '../data/repositories/local_shopping_repository.dart';
import '../domain/entities/purchase_history_entry.dart';
import '../domain/entities/shopping_list.dart';
import '../domain/models/shopping_mutation.dart';
import '../domain/repositories/shopping_repository.dart';
import '../domain/services/shopping_engine.dart';
import 'shopping_completion_coordinator.dart';

final shoppingEngineProvider = Provider<ShoppingEngine?>((ref) {
  final registry = ref.watch(canonicalIngredientRegistryProvider);
  return registry == null
      ? null
      : ShoppingEngine(
          registry: registry,
          unitEngine: ref.watch(unitConversionEngineProvider),
        );
});

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return LocalShoppingRepository(ref.watch(inventoryCommitRepositoryProvider));
});

final shoppingListsProvider = FutureProvider<List<ShoppingList>>((ref) {
  return ref.watch(shoppingRepositoryProvider).getLists();
});

final purchaseHistoryProvider = FutureProvider<List<PurchaseHistoryEntry>>((ref) {
  return ref.watch(shoppingRepositoryProvider).getPurchaseHistory();
});

final shoppingCompletionCoordinatorProvider =
    Provider<ShoppingCompletionCoordinator?>((ref) {
      final registry = ref.watch(canonicalIngredientRegistryProvider);
      if (registry == null) {
        return null;
      }
      return ShoppingCompletionCoordinator(
        repository: ref.watch(inventoryCommitRepositoryProvider),
        registry: registry,
        unitEngine: ref.watch(unitConversionEngineProvider),
        clock: ref.watch(appClockProvider),
        transactionIdGenerator: ref.watch(transactionIdGeneratorProvider),
      );
    });

class ShoppingCompletionController {
  ShoppingCompletionController({
    required ShoppingCompletionCoordinator? coordinator,
    required void Function(InventoryTransactionResult) onDurableCommit,
  }) : _coordinator = coordinator,
       _onDurableCommit = onDurableCommit;

  final ShoppingCompletionCoordinator? _coordinator;
  final void Function(InventoryTransactionResult) _onDurableCommit;

  Future<InventoryTransactionResult> complete({
    required String listId,
    required int expectedListRevision,
    required String itemId,
    required DateTime createdAt,
  }) {
    final coordinator = _coordinator;
    if (coordinator == null) {
      throw StateError('Canonical Shopping contract is unavailable.');
    }
    return _finish(
      coordinator,
      coordinator.completeItem(
        listId: listId,
        expectedListRevision: expectedListRevision,
        itemId: itemId,
        createdAt: createdAt,
      ),
    );
  }

  Future<InventoryTransactionResult> undo({
    required String purchaseTransactionId,
    required DateTime createdAt,
  }) {
    final coordinator = _coordinator;
    if (coordinator == null) {
      throw StateError('Canonical Shopping contract is unavailable.');
    }
    return _finish(
      coordinator,
      coordinator.undoCompletion(
        purchaseTransactionId: purchaseTransactionId,
        createdAt: createdAt,
      ),
    );
  }

  Future<InventoryTransactionResult> _finish(
    ShoppingCompletionCoordinator coordinator,
    Future<InventoryTransactionResult> operation,
  ) async {
    final result = await operation;
    if (!result.isSuccess) {
      return result;
    }
    final transactionId = result.transaction?.transactionId;
    if (result.outcome == InventoryTransactionOutcome.committed &&
        transactionId != null &&
        transactionId.isNotEmpty) {
      await coordinator.completePresentation(transactionId);
    }
    _onDurableCommit(result);
    return result;
  }
}

final shoppingCompletionControllerProvider =
    Provider<ShoppingCompletionController>((ref) {
      return ShoppingCompletionController(
        coordinator: ref.watch(shoppingCompletionCoordinatorProvider),
        onDurableCommit: (result) {
          ref
              .read(pantryProvider.notifier)
              .replaceFromCommittedSnapshot(result.snapshot.pantry);
          ref.invalidate(shoppingListsProvider);
          ref.invalidate(purchaseHistoryProvider);
        },
      );
    });

class ShoppingMutationController {
  ShoppingMutationController({
    required InventoryTransactionCoordinator coordinator,
    required void Function(InventoryTransactionResult) onDurableCommit,
  }) : _coordinator = coordinator,
       _onDurableCommit = onDurableCommit;

  final InventoryTransactionCoordinator _coordinator;
  final void Function(InventoryTransactionResult) _onDurableCommit;

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
    _onDurableCommit(result);
    return result;
  }
}

final shoppingMutationControllerProvider = Provider<ShoppingMutationController>(
  (ref) {
    return ShoppingMutationController(
      coordinator: ref.watch(inventoryTransactionCoordinatorProvider),
      onDurableCommit: (result) {
        final kind = result.transaction?.kind;
        if (kind == InventoryTransactionKind.shoppingPurchase ||
            kind == InventoryTransactionKind.undoShoppingPurchase) {
          ref
              .read(pantryProvider.notifier)
              .replaceFromCommittedSnapshot(result.snapshot.pantry);
        }
        ref.invalidate(shoppingListsProvider);
        ref.invalidate(purchaseHistoryProvider);
      },
    );
  },
);
