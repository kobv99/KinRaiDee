import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/time/app_clock.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/pantry/data/storage/inventory_store.dart';
import 'package:mobile/features/pantry/domain/models/inventory_state_envelope.dart';
import 'package:mobile/features/pantry/domain/models/inventory_transaction_record.dart';
import 'package:mobile/features/pantry/domain/models/pantry_quantity_transaction.dart';
import 'package:mobile/features/pantry/domain/repositories/inventory_commit_repository.dart';

import '../../../support/inventory_test_support.dart';

void main() {
  final now = DateTime.utc(2026, 7, 26, 10);

  group('HiveInventoryCommitRepository', () {
    test('migrates and verifies legacy data at revision zero', () async {
      final store = InMemoryInventoryStore(
        legacyPantry: <Ingredient>[_ingredient(10, now)],
      );
      final repository = _repository(store, now);

      final recovery = await repository.recoverPendingTransactions();

      expect(recovery.outcome, InventoryRecoveryOutcome.noWork);
      expect(recovery.snapshot.revision, 0);
      expect(recovery.snapshot.pantry.single.quantity, 10);
      expect(recovery.snapshot.hasValidChecksum, isTrue);
      expect(store.legacyBackup, isNotNull);
      expect(await repository.loadJournal(), isEmpty);
    });

    test('commits one envelope and completes its lifecycle', () async {
      final store = InMemoryInventoryStore(
        legacyPantry: <Ingredient>[_ingredient(10, now)],
      );
      final repository = _repository(store, now);
      final before = await repository.loadConsistentSnapshot();
      final commit = _commit(before, now, afterQuantity: 6);

      final result = await repository.commit(commit);

      expect(result.outcome, InventoryCommitOutcome.committed);
      expect(result.snapshot!.revision, 1);
      expect(result.snapshot!.pantry.single.quantity, 6);
      expect(
        (await repository.loadJournal()).single.state,
        InventoryTransactionState.committed,
      );

      await repository.complete(commit.transactionId);
      expect(
        (await repository.loadJournal()).single.state,
        InventoryTransactionState.completed,
      );
      await repository.complete(commit.transactionId);
    });

    test('duplicate commit returns the original durable outcome', () async {
      final store = InMemoryInventoryStore(
        legacyPantry: <Ingredient>[_ingredient(10, now)],
      );
      final repository = _repository(store, now);
      final before = await repository.loadConsistentSnapshot();
      final commit = _commit(before, now, afterQuantity: 6);
      await repository.commit(commit);

      final duplicate = await repository.commit(commit);
      final collision = await repository.commit(
        InventoryCommit(
          transactionId: commit.transactionId,
          kind: commit.kind,
          commandChecksum: 'different',
          createdAt: commit.createdAt,
          before: commit.before,
          after: commit.after,
        ),
      );

      expect(duplicate.outcome, InventoryCommitOutcome.alreadyCommitted);
      expect(duplicate.snapshot!.pantry.single.quantity, 6);
      expect(collision.outcome, InventoryCommitOutcome.recoveryRequired);
      expect(collision.code, 'transaction_identity_conflict');
    });

    for (final stage in <InventoryCommitStage>[
      InventoryCommitStage.created,
      InventoryCommitStage.validating,
      InventoryCommitStage.prepared,
      InventoryCommitStage.committing,
      InventoryCommitStage.envelopeWritten,
      InventoryCommitStage.committed,
    ]) {
      test(
        'recovers deterministic state after interruption at ${stage.name}',
        () async {
          final store = InMemoryInventoryStore(
            legacyPantry: <Ingredient>[_ingredient(10, now)],
          );
          final baselineRepository = _repository(store, now);
          final before = await baselineRepository.loadConsistentSnapshot();
          final commit = _commit(before, now, afterQuantity: 6);
          final interruptedRepository = HiveInventoryCommitRepository(
            store: store,
            clock: FixedAppClock(now),
            observer: InterruptOnceObserver(stage),
          );

          await expectLater(
            interruptedRepository.commit(commit),
            throwsA(isA<InventoryProcessInterruption>()),
          );

          final restarted = _repository(store, now);
          final recovery = await restarted.recoverPendingTransactions();
          final record = (await restarted.loadJournal()).single;
          final targetWasWritten =
              stage == InventoryCommitStage.envelopeWritten ||
              stage == InventoryCommitStage.committed;

          expect(recovery.allowsMutation, isTrue);
          expect(
            recovery.snapshot.pantry.single.quantity,
            targetWasWritten ? 6 : 10,
          );
          expect(
            record.state,
            targetWasWritten
                ? InventoryTransactionState.completed
                : InventoryTransactionState.rolledBack,
          );
        },
      );
    }

    test('restart completes a commit interrupted while completing', () async {
      final store = InMemoryInventoryStore(
        legacyPantry: <Ingredient>[_ingredient(10, now)],
      );
      final repository = HiveInventoryCommitRepository(
        store: store,
        clock: FixedAppClock(now),
        observer: InterruptOnceObserver(InventoryCommitStage.completing),
      );
      final before = await repository.loadConsistentSnapshot();
      final commit = _commit(before, now, afterQuantity: 6);
      await repository.commit(commit);

      await expectLater(
        repository.complete(commit.transactionId),
        throwsA(isA<InventoryProcessInterruption>()),
      );

      final restarted = _repository(store, now);
      final recovery = await restarted.recoverPendingTransactions();
      expect(recovery.snapshot.pantry.single.quantity, 6);
      expect(
        (await restarted.loadJournal()).single.state,
        InventoryTransactionState.completed,
      );
    });

    test('ordinary failure before envelope write rolls back to base', () async {
      final store = InMemoryInventoryStore(
        legacyPantry: <Ingredient>[_ingredient(10, now)],
      );
      final before = await _repository(store, now).loadConsistentSnapshot();
      final repository = HiveInventoryCommitRepository(
        store: store,
        clock: FixedAppClock(now),
        observer: _ThrowOnceObserver(InventoryCommitStage.committing),
      );

      final result = await repository.commit(
        _commit(before, now, afterQuantity: 6),
      );

      expect(result.outcome, InventoryCommitOutcome.storageFailure);
      expect(result.snapshot!.pantry.single.quantity, 10);
      expect(
        (await repository.loadJournal()).single.state,
        InventoryTransactionState.rolledBack,
      );
    });

    test('failure after target write finalizes without replay', () async {
      final store = InMemoryInventoryStore(
        legacyPantry: <Ingredient>[_ingredient(10, now)],
      );
      final before = await _repository(store, now).loadConsistentSnapshot();
      final repository = HiveInventoryCommitRepository(
        store: store,
        clock: FixedAppClock(now),
        observer: _ThrowOnceObserver(InventoryCommitStage.envelopeWritten),
      );

      final result = await repository.commit(
        _commit(before, now, afterQuantity: 6),
      );

      expect(result.outcome, InventoryCommitOutcome.committed);
      expect(result.snapshot!.pantry.single.quantity, 6);
      expect(result.snapshot!.revision, 1);
      expect(
        (await repository.loadJournal()).single.state,
        InventoryTransactionState.completed,
      );
    });

    test('corrupt envelope and journal fail closed', () async {
      final valid = InventoryStateEnvelope.initial(
        createdAt: now,
        pantry: <Ingredient>[_ingredient(10, now)],
      );
      final corruptEnvelope = valid.toJson()..['revision'] = 99;
      final envelopeStore = InMemoryInventoryStore(envelope: corruptEnvelope);
      final envelopeRecovery = await _repository(
        envelopeStore,
        now,
      ).recoverPendingTransactions();
      expect(
        envelopeRecovery.outcome,
        InventoryRecoveryOutcome.recoveryRequired,
      );

      final journalStore = InMemoryInventoryStore(
        envelope: valid.toJson(),
        journal: <String, dynamic>{
          'journalVersion': 1,
          'records': <Map<String, dynamic>>[
            <String, dynamic>{
              'transactionVersion': 1,
              'commandVersion': 1,
              'transactionId': transactionId,
              'kind': 'completeCooking',
              'state': 'unknown',
            },
          ],
        },
      );
      final journalRecovery = await _repository(
        journalStore,
        now,
      ).recoverPendingTransactions();
      expect(
        journalRecovery.outcome,
        InventoryRecoveryOutcome.recoveryRequired,
      );
    });
  });
}

const String transactionId = '10000000-0000-4000-8000-000000000001';

HiveInventoryCommitRepository _repository(
  InMemoryInventoryStore store,
  DateTime now,
) {
  return HiveInventoryCommitRepository(store: store, clock: FixedAppClock(now));
}

InventoryCommit _commit(
  InventoryStateEnvelope before,
  DateTime now, {
  required double afterQuantity,
}) {
  final pantry = <Ingredient>[
    before.pantry.single.copyWith(quantity: afterQuantity, updatedAt: now),
  ];
  final after = InventoryStateEnvelope(
    revision: before.revision + 1,
    lastAppliedTransactionId: transactionId,
    updatedAt: now,
    pantry: pantry,
    history: before.history,
  ).withComputedChecksum();
  return InventoryCommit(
    transactionId: transactionId,
    kind: InventoryTransactionKind.completeCooking,
    commandChecksum: calculateChecksum(<String, dynamic>{
      'kind': 'completeCooking',
      'quantity': afterQuantity,
    }),
    createdAt: now,
    before: before,
    after: after,
  );
}

Ingredient _ingredient(double quantity, DateTime now) {
  return Ingredient(
    id: 'egg',
    name: 'Egg',
    category: 'test',
    emoji: 'x',
    quantity: quantity,
    unit: 'piece',
    createdAt: now,
    updatedAt: now,
  );
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
      throw StateError('Injected ordinary failure.');
    }
  }
}
