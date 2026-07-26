import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/core/time/app_clock.dart';
import 'package:mobile/features/pantry/application/inventory_transaction_coordinator.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/pantry/data/storage/inventory_store.dart';
import 'package:mobile/features/pantry/domain/models/inventory_state_envelope.dart';
import 'package:mobile/features/pantry/domain/models/inventory_transaction_record.dart';
import 'package:mobile/features/pantry/domain/models/pantry_quantity_transaction.dart';
import 'package:mobile/features/shopping/data/repositories/local_shopping_repository.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_category.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_item.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_list.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_source.dart';
import 'package:mobile/features/shopping/domain/models/shopping_mutation.dart';
import 'package:mobile/features/shopping/domain/services/shopping_draft_builder.dart';

import '../../support/inventory_test_support.dart';

void main() {
  final now = DateTime.utc(2026, 7, 26, 12);

  test(
    'Shopping create, retry, update, and remove use one durable journal',
    () async {
      final harness = await _Harness.create(now);
      final list = _list(now);
      final create = ShoppingMutation.upsert(
        transactionId: _transactionIds[0],
        expectedRevision: 0,
        list: list,
        createdAt: now,
      );

      final created = await harness.coordinator.mutateShopping(create);

      expect(created.outcome, InventoryTransactionOutcome.committed);
      expect(created.snapshot.revision, 1);
      expect(created.snapshot.minimumReaderVersion, 2);
      expect(created.snapshot.capabilities, contains(shoppingStateCapability));
      expect(created.snapshot.shoppingLists.single.id, 'weekly');
      await harness.coordinator.completePresentation(_transactionIds[0]);

      final retry = await harness.coordinator.mutateShopping(create);
      expect(retry.outcome, InventoryTransactionOutcome.alreadyCommitted);
      expect(retry.snapshot.revision, 1);
      expect(await harness.shoppingRepository.getLists(), hasLength(1));

      final collision = await harness.coordinator.mutateShopping(
        ShoppingMutation.upsert(
          transactionId: _transactionIds[0],
          expectedRevision: 0,
          list: list.copyWith(name: 'Different command'),
          createdAt: now,
        ),
      );
      expect(collision.outcome, InventoryTransactionOutcome.recoveryRequired);
      expect(collision.code, 'transaction_identity_conflict');

      final persisted = retry.snapshot.shoppingLists.single;
      final update = ShoppingMutation.upsert(
        transactionId: _transactionIds[1],
        expectedRevision: 1,
        list: persisted.copyWith(name: 'Updated weekly list'),
        createdAt: now.add(const Duration(minutes: 1)),
      );
      final updated = await harness.coordinator.mutateShopping(update);

      expect(updated.snapshot.revision, 2);
      expect(updated.snapshot.shoppingLists.single.revision, 1);
      expect(updated.snapshot.shoppingLists.single.name, 'Updated weekly list');
      await harness.coordinator.completePresentation(_transactionIds[1]);

      final remove = ShoppingMutation.remove(
        transactionId: _transactionIds[2],
        expectedRevision: 2,
        listId: 'weekly',
        expectedListRevision: 1,
        createdAt: now.add(const Duration(minutes: 2)),
      );
      final removed = await harness.coordinator.mutateShopping(remove);

      expect(removed.outcome, InventoryTransactionOutcome.committed);
      expect(removed.snapshot.revision, 3);
      expect(removed.snapshot.shoppingLists, isEmpty);
      await harness.coordinator.completePresentation(_transactionIds[2]);

      final duplicateRemove = await harness.coordinator.mutateShopping(remove);
      expect(
        duplicateRemove.outcome,
        InventoryTransactionOutcome.alreadyCommitted,
      );
      expect(duplicateRemove.snapshot.revision, 3);

      final journal = await harness.repository.loadJournal();
      expect(journal, hasLength(3));
      expect(
        journal.every(
          (record) =>
              record.kind == InventoryTransactionKind.shoppingMutation &&
              record.state == InventoryTransactionState.completed,
        ),
        isTrue,
      );
    },
  );

  test(
    'rejects stale list revisions and invalid canonical identities',
    () async {
      final harness = await _Harness.create(now);
      final created = await harness.coordinator.mutateShopping(
        ShoppingMutation.upsert(
          transactionId: _transactionIds[0],
          expectedRevision: 0,
          list: _list(now),
          createdAt: now,
        ),
      );
      await harness.coordinator.completePresentation(_transactionIds[0]);
      final current = created.snapshot.shoppingLists.single;
      final updated = await harness.coordinator.mutateShopping(
        ShoppingMutation.upsert(
          transactionId: _transactionIds[1],
          expectedRevision: 1,
          list: current.copyWith(name: 'Updated'),
          createdAt: now.add(const Duration(minutes: 1)),
        ),
      );
      await harness.coordinator.completePresentation(_transactionIds[1]);

      final stale = await harness.coordinator.mutateShopping(
        ShoppingMutation.upsert(
          transactionId: _transactionIds[2],
          expectedRevision: 2,
          list: current.copyWith(name: 'Stale'),
          createdAt: now.add(const Duration(minutes: 2)),
        ),
      );
      expect(stale.outcome, InventoryTransactionOutcome.conflict);
      expect(stale.code, 'stale_shopping_list_revision');
      expect(stale.snapshot.shoppingLists.single.name, 'Updated');

      final invalid = ShoppingList(
        id: 'invalid',
        name: 'Invalid',
        items: <ShoppingItem>[
          ShoppingItem(
            id: 'unknown',
            canonicalIngredientId: 'unknown',
            displayName: 'Unknown',
            quantity: 1,
            unitId: 'piece',
            category: ShoppingCategory.other,
            source: ShoppingSource.manual,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      final rejected = await harness.coordinator.mutateShopping(
        ShoppingMutation.upsert(
          transactionId: _transactionIds[3],
          expectedRevision: updated.snapshot.revision,
          list: invalid,
          createdAt: now.add(const Duration(minutes: 3)),
        ),
      );
      expect(rejected.outcome, InventoryTransactionOutcome.validationFailure);
      expect(rejected.code, 'unknown_canonical_shopping_ingredient');
      expect(rejected.snapshot.revision, 2);
    },
  );

  test(
    'startup recovery retains Shopping committed before interruption',
    () async {
      final store = InMemoryInventoryStore();
      final baseline = HiveInventoryCommitRepository(
        store: store,
        clock: FixedAppClock(now),
      );
      await baseline.recoverPendingTransactions();
      final interruptedRepository = HiveInventoryCommitRepository(
        store: store,
        clock: FixedAppClock(now),
        observer: InterruptOnceObserver(InventoryCommitStage.envelopeWritten),
      );
      final coordinator = _coordinator(interruptedRepository, now);

      await expectLater(
        coordinator.mutateShopping(
          ShoppingMutation.upsert(
            transactionId: _transactionIds[0],
            expectedRevision: 0,
            list: _list(now),
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
      expect(recovery.snapshot.shoppingLists.single.id, 'weekly');
      expect(recovery.snapshot.hasValidChecksum, isTrue);
      expect(
        (await restarted.loadJournal()).single.state,
        InventoryTransactionState.completed,
      );
    },
  );

  test(
    'legacy envelope remains readable before Shopping capability exists',
    () {
      final legacy = InventoryStateEnvelope(
        minimumReaderVersion: 1,
        revision: 0,
        lastAppliedTransactionId: '',
        updatedAt: now,
        pantry: const [],
        history: const [],
      ).withComputedChecksum();

      final restored = InventoryStateEnvelope.fromJson(legacy.toJson());

      expect(restored.hasValidChecksum, isTrue);
      expect(restored.minimumReaderVersion, 1);
      expect(restored.shoppingLists, isEmpty);
      expect(restored.capabilities, isNot(contains(shoppingStateCapability)));
    },
  );

  test('failed Shopping commit rolls back the complete envelope', () async {
    final store = InMemoryInventoryStore();
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

    final result = await _coordinator(repository, now).mutateShopping(
      ShoppingMutation.upsert(
        transactionId: _transactionIds[0],
        expectedRevision: 0,
        list: _list(now),
        createdAt: now,
      ),
    );

    expect(result.outcome, InventoryTransactionOutcome.storageFailure);
    expect(result.snapshot.revision, 0);
    expect(result.snapshot.shoppingLists, isEmpty);
    final journal = await repository.loadJournal();
    expect(journal.single.state, InventoryTransactionState.rolledBack);
  });
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
      throw StateError('Injected Shopping commit failure');
    }
  }
}

class _Harness {
  const _Harness({
    required this.repository,
    required this.coordinator,
    required this.shoppingRepository,
  });

  final HiveInventoryCommitRepository repository;
  final InventoryTransactionCoordinator coordinator;
  final LocalShoppingRepository shoppingRepository;

  static Future<_Harness> create(DateTime now) async {
    final repository = HiveInventoryCommitRepository(
      store: InMemoryInventoryStore(),
      clock: FixedAppClock(now),
    );
    await repository.recoverPendingTransactions();
    return _Harness(
      repository: repository,
      coordinator: _coordinator(repository, now),
      shoppingRepository: LocalShoppingRepository(repository),
    );
  }
}

InventoryTransactionCoordinator _coordinator(
  HiveInventoryCommitRepository repository,
  DateTime now,
) {
  return InventoryTransactionCoordinator(
    repository: repository,
    clock: FixedAppClock(now),
    transactionIdGenerator: SequenceTransactionIdGenerator(_transactionIds),
    canonicalIngredientRegistry: _registry(),
    unitConversionEngine: UnitConversionEngine.standard(),
  );
}

ShoppingList _list(DateTime now) {
  final item =
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
      );
  return ShoppingList(
    id: 'weekly',
    name: 'Weekly',
    items: <ShoppingItem>[item],
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

const List<String> _transactionIds = <String>[
  '20000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000002',
  '20000000-0000-4000-8000-000000000003',
  '20000000-0000-4000-8000-000000000004',
  '20000000-0000-4000-8000-000000000005',
];
