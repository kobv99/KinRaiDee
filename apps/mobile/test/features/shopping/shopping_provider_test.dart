import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/canonical_ingredient_providers.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/core/time/app_clock.dart';
import 'package:mobile/features/pantry/application/inventory_transaction_coordinator.dart';
import 'package:mobile/features/pantry/application/inventory_transaction_providers.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/shopping/application/shopping_providers.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_list.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_source.dart';
import 'package:mobile/features/shopping/domain/models/shopping_mutation.dart';
import 'package:mobile/features/shopping/domain/services/shopping_draft_builder.dart';

import '../../support/inventory_test_support.dart';

void main() {
  final now = DateTime.utc(2026, 7, 26, 12);

  test('Riverpod refreshes Shopping only after a durable commit', () async {
    final store = InMemoryInventoryStore();
    final repository = HiveInventoryCommitRepository(
      store: store,
      clock: FixedAppClock(now),
    );
    await repository.recoverPendingTransactions();
    final container = _container(repository, now);
    addTearDown(container.dispose);
    expect(await container.read(shoppingListsProvider.future), isEmpty);

    final result = await container
        .read(shoppingMutationControllerProvider)
        .execute(ShoppingMutation.upsert(list: _list(now), createdAt: now));

    expect(result.outcome, InventoryTransactionOutcome.committed);
    expect(await container.read(shoppingListsProvider.future), hasLength(1));
    expect(store.envelope, isNotNull);
  });

  test(
    'failed persistence never publishes optimistic Shopping state',
    () async {
      final store = InMemoryInventoryStore();
      final repository = HiveInventoryCommitRepository(
        store: store,
        clock: FixedAppClock(now),
      );
      await repository.recoverPendingTransactions();
      final container = _container(repository, now);
      addTearDown(container.dispose);
      expect(await container.read(shoppingListsProvider.future), isEmpty);
      store.failEnvelopeWrites = true;

      final result = await container
          .read(shoppingMutationControllerProvider)
          .execute(ShoppingMutation.upsert(list: _list(now), createdAt: now));

      expect(result.outcome, InventoryTransactionOutcome.storageFailure);
      expect(await container.read(shoppingListsProvider.future), isEmpty);
    },
  );
}

ProviderContainer _container(
  HiveInventoryCommitRepository repository,
  DateTime now,
) {
  return ProviderContainer(
    overrides: [
      inventoryCommitRepositoryProvider.overrideWithValue(repository),
      appClockProvider.overrideWithValue(FixedAppClock(now)),
      transactionIdGeneratorProvider.overrideWithValue(
        SequenceTransactionIdGenerator(),
      ),
      canonicalIngredientRegistryProvider.overrideWithValue(_registry()),
      unitConversionEngineProvider.overrideWithValue(
        UnitConversionEngine.standard(),
      ),
    ],
  );
}

ShoppingList _list(DateTime now) {
  return ShoppingList(
    id: 'weekly',
    name: 'Weekly',
    items: [
      ShoppingItemFactory(
        registry: _registry(),
        unitEngine: UnitConversionEngine.standard(),
      ).create(
        id: 'weekly::egg::piece',
        canonicalIngredientId: 'egg',
        quantity: 6,
        unit: 'piece',
        source: ShoppingSource.manual,
        createdAt: now,
      ),
    ],
    createdAt: now,
    updatedAt: now,
  );
}

CanonicalIngredientRegistry _registry() {
  return CanonicalIngredientRegistry(
    ingredients: <CanonicalIngredient>[
      CanonicalIngredient(
        id: 'egg',
        canonicalName: 'Egg',
        localizedNames: const <String, String>{'th': 'Egg'},
        aliases: const <String>[],
        searchKeywords: const <String>[],
        category: 'protein',
        defaultStorageType: IngredientStorageType.refrigerated,
        defaultPurchaseUnitId: 'piece',
        defaultInventoryUnitId: 'piece',
      ),
    ],
  );
}
