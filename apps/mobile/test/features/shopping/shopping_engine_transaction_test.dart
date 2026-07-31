import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/time/app_clock.dart';
import 'package:mobile/features/pantry/application/inventory_transaction_coordinator.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/pantry/data/storage/inventory_store.dart';
import 'package:mobile/features/pantry/domain/models/inventory_state_envelope.dart';
import 'package:mobile/features/pantry/domain/models/inventory_transaction_record.dart';
import 'package:mobile/features/pantry/domain/models/pantry_quantity_transaction.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_item.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_item_status.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_list.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_source.dart';
import 'package:mobile/features/shopping/domain/models/shopping_mutation.dart';
import 'package:mobile/features/shopping/domain/services/shopping_draft_builder.dart';

import '../../support/inventory_test_support.dart';

void main() {
  final now = DateTime.utc(2026, 7, 27, 10);

  test(
    'add, update, and remove item mutations are revisioned and durable',
    () async {
      final harness = await _Harness.create(
        now,
        list: _list(now, items: const []),
      );
      final item = _item(now, id: 'egg-item', quantity: 6);

      final added = await harness.coordinator.mutateShopping(
        ShoppingMutation.addItem(
          transactionId: _ids[0],
          expectedRevision: 0,
          listId: 'weekly',
          expectedListRevision: 0,
          item: item,
          createdAt: now,
        ),
      );
      expect(added.outcome, InventoryTransactionOutcome.committed);
      expect(added.snapshot.shoppingLists.single.revision, 1);
      expect(added.snapshot.shoppingLists.single.items.single.quantity, 6);
      await harness.coordinator.completePresentation(_ids[0]);

      final updated = await harness.coordinator.mutateShopping(
        ShoppingMutation.updateQuantity(
          transactionId: _ids[1],
          expectedRevision: 1,
          listId: 'weekly',
          expectedListRevision: 1,
          itemId: 'egg-item',
          quantity: 12,
          unitId: 'piece',
          createdAt: now.add(const Duration(minutes: 1)),
        ),
      );
      expect(updated.snapshot.shoppingLists.single.revision, 2);
      expect(updated.snapshot.shoppingLists.single.items.single.quantity, 12);
      await harness.coordinator.completePresentation(_ids[1]);

      final removed = await harness.coordinator.mutateShopping(
        ShoppingMutation.removeItem(
          transactionId: _ids[2],
          expectedRevision: 2,
          listId: 'weekly',
          expectedListRevision: 2,
          itemId: 'egg-item',
          createdAt: now.add(const Duration(minutes: 2)),
        ),
      );
      expect(removed.snapshot.shoppingLists.single.items, isEmpty);
      expect(removed.snapshot.shoppingLists.single.revision, 3);
    },
  );

  test(
    'rejects negative quantity and duplicate active canonical entries',
    () async {
      final harness = await _Harness.create(
        now,
        list: _list(now, items: <ShoppingItem>[_item(now)]),
      );

      final negative = await harness.coordinator.mutateShopping(
        ShoppingMutation.updateQuantity(
          transactionId: _ids[0],
          expectedRevision: 0,
          listId: 'weekly',
          expectedListRevision: 0,
          itemId: 'egg-item',
          quantity: -1,
          createdAt: now,
        ),
      );
      expect(negative.outcome, InventoryTransactionOutcome.validationFailure);
      expect(negative.code, 'invalid_shopping_quantity');

      final duplicate = await harness.coordinator.mutateShopping(
        ShoppingMutation.addItem(
          transactionId: _ids[1],
          expectedRevision: 0,
          listId: 'weekly',
          expectedListRevision: 0,
          item: _item(now, id: 'duplicate'),
          createdAt: now,
        ),
      );
      expect(duplicate.outcome, InventoryTransactionOutcome.validationFailure);
      expect(duplicate.code, 'duplicate_active_shopping_ingredient');
      expect(duplicate.snapshot.revision, 0);
    },
  );

  test(
    'purchase updates Pantry and duplicate attempts are idempotent',
    () async {
      final harness = await _Harness.create(
        now,
        list: _list(now, items: <ShoppingItem>[_item(now, quantity: 6)]),
        pantry: <Ingredient>[_pantry(now, quantity: 2)],
      );
      final command = ShoppingMutation.markPurchased(
        transactionId: _ids[0],
        expectedRevision: 0,
        listId: 'weekly',
        expectedListRevision: 0,
        itemId: 'egg-item',
        createdAt: now,
      );

      final purchased = await harness.coordinator.mutateShopping(command);

      expect(purchased.outcome, InventoryTransactionOutcome.committed);
      expect(
        purchased.transaction?.kind,
        InventoryTransactionKind.shoppingPurchase,
      );
      expect(purchased.snapshot.pantry.single.quantity, 8);
      final purchasedItem =
          purchased.snapshot.shoppingLists.single.items.single;
      expect(purchasedItem.status, ShoppingItemStatus.purchased);
      expect(purchasedItem.purchase?.beforeQuantity, 2);
      expect(purchasedItem.purchase?.afterQuantity, 8);
      await harness.coordinator.completePresentation(_ids[0]);

      final retry = await harness.coordinator.mutateShopping(command);
      expect(retry.outcome, InventoryTransactionOutcome.alreadyCommitted);
      expect(retry.snapshot.pantry.single.quantity, 8);

      final semanticDuplicate = await harness.coordinator.mutateShopping(
        ShoppingMutation.markPurchased(
          transactionId: _ids[1],
          expectedRevision: 0,
          listId: 'weekly',
          expectedListRevision: 0,
          itemId: 'egg-item',
          createdAt: now,
        ),
      );
      expect(
        semanticDuplicate.outcome,
        InventoryTransactionOutcome.alreadyCommitted,
      );
      expect(semanticDuplicate.code, 'already_purchased');
      expect((await harness.repository.loadJournal()), hasLength(1));
    },
  );

  test('undo purchase restores the exact previous Pantry state once', () async {
    final harness = await _Harness.create(
      now,
      list: _list(now, items: <ShoppingItem>[_item(now, quantity: 6)]),
      pantry: <Ingredient>[_pantry(now, quantity: 2)],
    );
    final purchased = await harness.coordinator.mutateShopping(
      ShoppingMutation.markPurchased(
        transactionId: _ids[0],
        expectedRevision: 0,
        listId: 'weekly',
        expectedListRevision: 0,
        itemId: 'egg-item',
        createdAt: now,
      ),
    );
    await harness.coordinator.completePresentation(_ids[0]);

    final undone = await harness.coordinator.mutateShopping(
      ShoppingMutation.markUnpurchased(
        transactionId: _ids[1],
        expectedRevision: purchased.snapshot.revision,
        listId: 'weekly',
        expectedListRevision: 1,
        itemId: 'egg-item',
        createdAt: now.add(const Duration(minutes: 1)),
      ),
    );

    expect(undone.outcome, InventoryTransactionOutcome.committed);
    expect(
      undone.transaction?.kind,
      InventoryTransactionKind.undoShoppingPurchase,
    );
    expect(undone.transaction?.reversesTransactionId, _ids[0]);
    expect(undone.snapshot.pantry.single.quantity, 2);
    final item = undone.snapshot.shoppingLists.single.items.single;
    expect(item.status, ShoppingItemStatus.active);
    expect(item.purchase, isNull);
    await harness.coordinator.completePresentation(_ids[1]);

    final duplicate = await harness.coordinator.mutateShopping(
      ShoppingMutation.markUnpurchased(
        transactionId: _ids[2],
        expectedRevision: 0,
        listId: 'weekly',
        expectedListRevision: 0,
        itemId: 'egg-item',
        createdAt: now,
      ),
    );
    expect(duplicate.outcome, InventoryTransactionOutcome.alreadyCommitted);
    expect(duplicate.code, 'already_unpurchased');
    expect(duplicate.snapshot.pantry.single.quantity, 2);
  });

  test(
    'purchase creates a mapped Pantry lot and undo removes that lot',
    () async {
      final harness = await _Harness.create(
        now,
        list: _list(
          now,
          items: <ShoppingItem>[_item(now, quantity: 6, unit: 'egg')],
        ),
      );
      final purchased = await harness.coordinator.mutateShopping(
        ShoppingMutation.markPurchased(
          transactionId: _ids[0],
          expectedRevision: 0,
          listId: 'weekly',
          expectedListRevision: 0,
          itemId: 'egg-item',
          createdAt: now,
        ),
      );

      expect(purchased.snapshot.pantry, hasLength(1));
      expect(
        purchased.snapshot.pantry.single.canonicalMappingStatus,
        CanonicalMappingStatus.mapped,
      );
      expect(purchased.snapshot.pantry.single.canonicalIngredientId, 'egg');
      expect(purchased.snapshot.pantry.single.emoji, '🥚');
      expect(purchased.snapshot.pantry.single.unit, 'ฟอง');
      expect(purchased.snapshot.pantry.single.canonicalUnitId, 'egg');
      await harness.coordinator.completePresentation(_ids[0]);

      final undone = await harness.coordinator.mutateShopping(
        ShoppingMutation.markUnpurchased(
          transactionId: _ids[1],
          expectedRevision: 1,
          listId: 'weekly',
          expectedListRevision: 1,
          itemId: 'egg-item',
          createdAt: now.add(const Duration(minutes: 1)),
        ),
      );
      expect(undone.snapshot.pantry, isEmpty);
    },
  );

  test('archive, restore, and clear completed items preserve Pantry', () async {
    final harness = await _Harness.create(
      now,
      list: _list(now, items: <ShoppingItem>[_item(now)]),
    );
    final purchased = await harness.coordinator.mutateShopping(
      ShoppingMutation.markPurchased(
        transactionId: _ids[0],
        expectedRevision: 0,
        listId: 'weekly',
        expectedListRevision: 0,
        itemId: 'egg-item',
        createdAt: now,
      ),
    );
    await harness.coordinator.completePresentation(_ids[0]);

    final archived = await harness.coordinator.mutateShopping(
      ShoppingMutation.archiveCompleted(
        transactionId: _ids[1],
        expectedRevision: purchased.snapshot.revision,
        listId: 'weekly',
        expectedListRevision: 1,
        createdAt: now.add(const Duration(minutes: 1)),
      ),
    );
    expect(
      archived.snapshot.shoppingLists.single.items.single.status,
      ShoppingItemStatus.archived,
    );
    await harness.coordinator.completePresentation(_ids[1]);

    final restored = await harness.coordinator.mutateShopping(
      ShoppingMutation.restoreArchived(
        transactionId: _ids[2],
        expectedRevision: archived.snapshot.revision,
        listId: 'weekly',
        expectedListRevision: 2,
        createdAt: now.add(const Duration(minutes: 2)),
      ),
    );
    expect(
      restored.snapshot.shoppingLists.single.items.single.status,
      ShoppingItemStatus.purchased,
    );
    await harness.coordinator.completePresentation(_ids[2]);

    final cleared = await harness.coordinator.mutateShopping(
      ShoppingMutation.clearCompleted(
        transactionId: _ids[3],
        expectedRevision: restored.snapshot.revision,
        listId: 'weekly',
        expectedListRevision: 3,
        createdAt: now.add(const Duration(minutes: 3)),
      ),
    );
    expect(cleared.snapshot.shoppingLists.single.items, isEmpty);
    expect(cleared.snapshot.pantry, hasLength(1));
  });

  test('undo fails closed when Pantry changed after purchase', () async {
    final harness = await _Harness.create(
      now,
      list: _list(now, items: <ShoppingItem>[_item(now)]),
      pantry: <Ingredient>[_pantry(now, quantity: 2)],
    );
    final purchased = await harness.coordinator.mutateShopping(
      ShoppingMutation.markPurchased(
        transactionId: _ids[0],
        expectedRevision: 0,
        listId: 'weekly',
        expectedListRevision: 0,
        itemId: 'egg-item',
        createdAt: now,
      ),
    );
    await harness.coordinator.completePresentation(_ids[0]);
    final editedPantry = purchased.snapshot.pantry.single.copyWith(quantity: 7);
    final edited = await harness.coordinator.replacePantry(<Ingredient>[
      editedPantry,
    ], source: 'test-edit');
    await harness.coordinator.completePresentation(
      edited.transaction!.transactionId,
    );

    final undo = await harness.coordinator.mutateShopping(
      ShoppingMutation.markUnpurchased(
        transactionId: _ids[2],
        expectedRevision: edited.snapshot.revision,
        listId: 'weekly',
        expectedListRevision: 1,
        itemId: 'egg-item',
        createdAt: now.add(const Duration(minutes: 2)),
      ),
    );

    expect(undo.outcome, InventoryTransactionOutcome.conflict);
    expect(undo.code, 'purchase_pantry_state_changed');
    expect(undo.snapshot.pantry.single.quantity, 7);
    expect(
      undo.snapshot.shoppingLists.single.items.single.status,
      ShoppingItemStatus.purchased,
    );
  });

  test('crash recovery completes Shopping and Pantry together', () async {
    final initial = InventoryStateEnvelope.initial(
      createdAt: now,
      pantry: <Ingredient>[_pantry(now, quantity: 2)],
      shoppingLists: <ShoppingList>[
        _list(now, items: <ShoppingItem>[_item(now)]),
      ],
    );
    final store = InMemoryInventoryStore(envelope: initial.toJson());
    final baseline = HiveInventoryCommitRepository(
      store: store,
      clock: FixedAppClock(now),
    );
    await baseline.recoverPendingTransactions();
    final interrupted = HiveInventoryCommitRepository(
      store: store,
      clock: FixedAppClock(now),
      observer: InterruptOnceObserver(InventoryCommitStage.envelopeWritten),
    );

    await expectLater(
      _coordinator(interrupted, now).mutateShopping(
        ShoppingMutation.markPurchased(
          transactionId: _ids[0],
          expectedRevision: 0,
          listId: 'weekly',
          expectedListRevision: 0,
          itemId: 'egg-item',
          createdAt: now,
        ),
      ),
      throwsA(isA<InventoryProcessInterruption>()),
    );

    final restarted = HiveInventoryCommitRepository(
      store: store,
      clock: FixedAppClock(now),
    );
    final recovery = await restarted.recoverPendingTransactions();

    expect(recovery.allowsMutation, isTrue);
    expect(recovery.snapshot.pantry.single.quantity, 8);
    expect(
      recovery.snapshot.shoppingLists.single.items.single.status,
      ShoppingItemStatus.purchased,
    );
    expect(
      (await restarted.loadJournal()).single.state,
      InventoryTransactionState.completed,
    );
  });

  test('ordinary purchase failure rolls back Shopping and Pantry', () async {
    final initial = InventoryStateEnvelope.initial(
      createdAt: now,
      pantry: <Ingredient>[_pantry(now, quantity: 2)],
      shoppingLists: <ShoppingList>[
        _list(now, items: <ShoppingItem>[_item(now)]),
      ],
    );
    final store = InMemoryInventoryStore(envelope: initial.toJson());
    final baseline = HiveInventoryCommitRepository(
      store: store,
      clock: FixedAppClock(now),
    );
    await baseline.recoverPendingTransactions();
    final repository = HiveInventoryCommitRepository(
      store: store,
      clock: FixedAppClock(now),
      observer: _ThrowOnceObserver(InventoryCommitStage.committing),
    );

    final failed = await _coordinator(repository, now).mutateShopping(
      ShoppingMutation.markPurchased(
        transactionId: _ids[0],
        expectedRevision: 0,
        listId: 'weekly',
        expectedListRevision: 0,
        itemId: 'egg-item',
        createdAt: now,
      ),
    );

    expect(failed.outcome, InventoryTransactionOutcome.storageFailure);
    expect(failed.snapshot.pantry.single.quantity, 2);
    expect(
      failed.snapshot.shoppingLists.single.items.single.status,
      ShoppingItemStatus.active,
    );
    expect(
      (await repository.loadJournal()).single.state,
      InventoryTransactionState.rolledBack,
    );
  });
}

class _Harness {
  const _Harness({required this.repository, required this.coordinator});

  final HiveInventoryCommitRepository repository;
  final InventoryTransactionCoordinator coordinator;

  static Future<_Harness> create(
    DateTime now, {
    required ShoppingList list,
    List<Ingredient> pantry = const <Ingredient>[],
  }) async {
    final initial = InventoryStateEnvelope.initial(
      createdAt: now,
      pantry: pantry,
      shoppingLists: <ShoppingList>[list],
    );
    final repository = HiveInventoryCommitRepository(
      store: InMemoryInventoryStore(envelope: initial.toJson()),
      clock: FixedAppClock(now),
    );
    await repository.recoverPendingTransactions();
    return _Harness(
      repository: repository,
      coordinator: _coordinator(repository, now),
    );
  }
}

class _ThrowOnceObserver implements InventoryCommitObserver {
  _ThrowOnceObserver(this.stage);

  final InventoryCommitStage stage;
  bool thrown = false;

  @override
  Future<void> reached(
    InventoryCommitStage current,
    InventoryTransactionRecord record,
  ) async {
    if (!thrown && current == stage) {
      thrown = true;
      throw StateError('Injected Shopping purchase failure');
    }
  }
}

InventoryTransactionCoordinator _coordinator(
  HiveInventoryCommitRepository repository,
  DateTime now,
) {
  return InventoryTransactionCoordinator(
    repository: repository,
    clock: FixedAppClock(now),
    transactionIdGenerator: SequenceTransactionIdGenerator(_generatedIds),
    canonicalIngredientRegistry: _registry(),
    unitConversionEngine: UnitConversionEngine.standard(),
  );
}

ShoppingList _list(DateTime now, {required List<ShoppingItem> items}) {
  return ShoppingList(
    id: 'weekly',
    name: 'Weekly',
    items: items,
    createdAt: now,
    updatedAt: now,
  );
}

ShoppingItem _item(
  DateTime now, {
  String id = 'egg-item',
  double quantity = 6,
  String unit = 'piece',
}) {
  return ShoppingItemFactory(
    registry: _registry(),
    unitEngine: UnitConversionEngine.standard(),
  ).create(
    id: id,
    canonicalIngredientId: 'egg',
    quantity: quantity,
    unit: unit,
    source: ShoppingSource.manual,
    createdAt: now,
  );
}

Ingredient _pantry(DateTime now, {required double quantity}) {
  return Ingredient(
    id: 'egg-lot',
    name: 'Egg',
    category: 'protein',
    emoji: '',
    quantity: quantity,
    unit: 'piece',
    createdAt: now,
    updatedAt: now,
    canonicalIngredientId: 'egg',
    canonicalUnitId: 'piece',
    canonicalMappingStatus: CanonicalMappingStatus.mapped,
  );
}

CanonicalIngredientRegistry _registry() {
  return CanonicalIngredientRegistry(
    ingredients: <CanonicalIngredient>[
      CanonicalIngredient(
        id: 'egg',
        canonicalName: 'Egg',
        emoji: '🥚',
        localizedNames: const <String, String>{'th': 'Egg'},
        aliases: const <String>[],
        searchKeywords: const <String>[],
        category: 'protein',
        defaultStorageType: IngredientStorageType.refrigerated,
        defaultPurchaseUnitId: 'egg',
        defaultInventoryUnitId: 'egg',
      ),
    ],
  );
}

const List<String> _ids = <String>[
  '30000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000002',
  '30000000-0000-4000-8000-000000000003',
  '30000000-0000-4000-8000-000000000004',
  '30000000-0000-4000-8000-000000000005',
  '30000000-0000-4000-8000-000000000006',
  '30000000-0000-4000-8000-000000000007',
  '30000000-0000-4000-8000-000000000008',
];

const List<String> _generatedIds = <String>[
  '40000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000002',
  '40000000-0000-4000-8000-000000000003',
  '40000000-0000-4000-8000-000000000004',
];
