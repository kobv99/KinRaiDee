import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/services/storage_service.dart';
import 'package:mobile/core/time/app_clock.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/pantry/data/storage/inventory_store.dart';
import 'package:mobile/features/pantry/domain/models/inventory_state_envelope.dart';
import 'package:mobile/features/pantry/domain/models/pantry_quantity_transaction.dart';
import 'package:mobile/features/pantry/domain/repositories/inventory_commit_repository.dart';

import '../../../support/inventory_test_support.dart';

void main() {
  final now = DateTime.utc(2026, 7, 26, 11);
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kinraidee_inventory_');
    Hive.init(directory.path);
    await Hive.openBox<dynamic>(StorageService.pantryBoxName);
  });

  tearDown(() async {
    await Hive.close();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  test('durable envelope survives closing and reopening Hive', () async {
    final box = Hive.box<dynamic>(StorageService.pantryBoxName);
    await box.put(StorageService.ingredientsKey, <Map<String, dynamic>>[
      _ingredient(now).toJson(),
    ]);
    final repository = HiveInventoryCommitRepository(clock: FixedAppClock(now));
    final before = await repository.loadConsistentSnapshot();
    final commit = _commit(before, now);
    final result = await repository.commit(commit);
    await repository.complete(commit.transactionId);
    expect(result.snapshot!.pantry.single.quantity, 6);

    await Hive.close();
    Hive.init(directory.path);
    await Hive.openBox<dynamic>(StorageService.pantryBoxName);

    final restarted = HiveInventoryCommitRepository(clock: FixedAppClock(now));
    final recovery = await restarted.recoverPendingTransactions();
    expect(recovery.allowsMutation, isTrue);
    expect(recovery.snapshot.revision, 1);
    expect(recovery.snapshot.pantry.single.quantity, 6);
    expect((await restarted.loadJournal()).single.transactionId, transactionId);
  });

  test(
    'restart finalizes target written before journal finalization',
    () async {
      final box = Hive.box<dynamic>(StorageService.pantryBoxName);
      await box.put(StorageService.ingredientsKey, <Map<String, dynamic>>[
        _ingredient(now).toJson(),
      ]);
      final baseline = HiveInventoryCommitRepository(clock: FixedAppClock(now));
      final before = await baseline.loadConsistentSnapshot();
      final interrupted = HiveInventoryCommitRepository(
        clock: FixedAppClock(now),
        observer: InterruptOnceObserver(InventoryCommitStage.envelopeWritten),
      );

      await expectLater(
        interrupted.commit(_commit(before, now)),
        throwsA(isA<InventoryProcessInterruption>()),
      );
      await Hive.close();
      Hive.init(directory.path);
      await Hive.openBox<dynamic>(StorageService.pantryBoxName);

      final restarted = HiveInventoryCommitRepository(
        clock: FixedAppClock(now),
      );
      final recovery = await restarted.recoverPendingTransactions();
      expect(recovery.snapshot.pantry.single.quantity, 6);
      expect(recovery.snapshot.revision, 1);
    },
  );
}

const String transactionId = '20000000-0000-4000-8000-000000000001';

InventoryCommit _commit(InventoryStateEnvelope before, DateTime now) {
  final after = InventoryStateEnvelope(
    revision: before.revision + 1,
    lastAppliedTransactionId: transactionId,
    updatedAt: now,
    pantry: <Ingredient>[
      before.pantry.single.copyWith(quantity: 6, updatedAt: now),
    ],
    history: before.history,
  ).withComputedChecksum();
  return InventoryCommit(
    transactionId: transactionId,
    kind: InventoryTransactionKind.completeCooking,
    commandChecksum: calculateChecksum(<String, dynamic>{'quantity': 6}),
    createdAt: now,
    before: before,
    after: after,
  );
}

Ingredient _ingredient(DateTime now) {
  return Ingredient(
    id: 'egg',
    name: 'Egg',
    category: 'test',
    emoji: 'x',
    quantity: 10,
    unit: 'piece',
    createdAt: now,
    updatedAt: now,
  );
}
