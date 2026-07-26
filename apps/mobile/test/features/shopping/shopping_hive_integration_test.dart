import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/core/services/storage_service.dart';
import 'package:mobile/core/time/app_clock.dart';
import 'package:mobile/features/pantry/application/inventory_transaction_coordinator.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/shopping/data/repositories/local_shopping_repository.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_list.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_source.dart';
import 'package:mobile/features/shopping/domain/models/shopping_mutation.dart';
import 'package:mobile/features/shopping/domain/services/shopping_draft_builder.dart';

import '../../support/inventory_test_support.dart';

void main() {
  final now = DateTime.utc(2026, 7, 26, 12);
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kinraidee_shopping_');
    Hive.init(directory.path);
    await Hive.openBox<dynamic>(StorageService.pantryBoxName);
  });

  tearDown(() async {
    await Hive.close();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  test('Shopping envelope and journal survive a Hive restart', () async {
    final repository = HiveInventoryCommitRepository(clock: FixedAppClock(now));
    await repository.recoverPendingTransactions();
    final coordinator = InventoryTransactionCoordinator(
      repository: repository,
      clock: FixedAppClock(now),
      transactionIdGenerator: SequenceTransactionIdGenerator(),
      canonicalIngredientRegistry: _registry(),
      unitConversionEngine: UnitConversionEngine.standard(),
    );
    final result = await coordinator.mutateShopping(
      ShoppingMutation.upsert(list: _list(now), createdAt: now),
    );
    await coordinator.completePresentation(result.transaction!.transactionId);

    await Hive.close();
    Hive.init(directory.path);
    await Hive.openBox<dynamic>(StorageService.pantryBoxName);

    final restarted = HiveInventoryCommitRepository(clock: FixedAppClock(now));
    final recovery = await restarted.recoverPendingTransactions();
    final lists = await LocalShoppingRepository(restarted).getLists();

    expect(recovery.allowsMutation, isTrue);
    expect(recovery.snapshot.hasValidChecksum, isTrue);
    expect(lists.single.id, 'weekly');
    expect(lists.single.items.single.canonicalIngredientId, 'egg');
    expect((await restarted.loadJournal()).single.transactionId, isNotEmpty);
  });
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
