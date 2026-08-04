import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/time/app_clock.dart';
import 'package:mobile/features/pantry/application/canonical_ingredient_migration.dart';
import 'package:mobile/features/pantry/application/canonical_ingredient_semantic_migration.dart';
import 'package:mobile/features/pantry/application/inventory_transaction_coordinator.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/pantry/domain/models/cooking_history_entry.dart';

import '../../../support/inventory_test_support.dart';

/// Mirrors main.dart's `_bootstrap` sequence — recover, run the semantic
/// migration, run the general migration on its result, commit the combined
/// final snapshot once — to prove the two migration passes never produce
/// two transactions, and that an already-current snapshot produces zero.
void main() {
  final now = DateTime.utc(2026, 8, 4);
  final registry = CanonicalIngredientRegistry(
    ingredients: <CanonicalIngredient>[
      CanonicalIngredient(
        id: 'chicken_drumstick',
        canonicalName: 'Chicken Drumstick',
        localizedNames: const <String, String>{'th': 'น่องไก่'},
        aliases: const <String>[],
        searchKeywords: const <String>[],
        category: 'protein',
        defaultStorageType: IngredientStorageType.refrigerated,
        defaultPurchaseUnitId: 'kilogram',
        defaultInventoryUnitId: 'gram',
      ),
    ],
  );
  final unitEngine = UnitConversionEngine.standard();

  Future<_Harness> harness(List<Ingredient> pantry) =>
      _Harness.create(now: now, pantry: pantry);

  // Each commit is itself a multi-phase durable write (prepare / commit /
  // complete), so raw store write counts don't map 1:1 to "one logical
  // transaction". The envelope's `revision` does: _targetEnvelope always
  // increments it by exactly 1 per commit, so a delta of 1 proves exactly
  // one migrateCanonicalIngredients transaction was applied, and a delta of
  // 0 proves none was.
  Future<int> runStartupMigration(_Harness harness) async {
    final before = (await harness.repository.loadConsistentSnapshot()).revision;
    final recovery = await harness.repository.loadConsistentSnapshot();
    final semantic = const CanonicalIngredientSemanticMigration().migrate(
      pantry: recovery.pantry,
      history: recovery.history,
    );
    final general = CanonicalIngredientMigration(
      registry: registry,
      unitEngine: unitEngine,
    ).migrate(pantry: semantic.pantry, history: semantic.history);
    if (semantic.changed || general.changed) {
      final result = await harness.coordinator.migrateCanonicalIngredients(
        pantry: general.pantry,
        history: general.history,
        targetSchemaVersion: canonicalIngredientMigrationVersion,
      );
      expect(result.isSuccess, isTrue);
    }
    final after = (await harness.repository.loadConsistentSnapshot()).revision;
    return after - before;
  }

  test(
    'commits exactly once when both migration passes have changes',
    () async {
      final h = await harness(<Ingredient>[
        Ingredient(
          id: 'lot-1',
          name: 'น่องไก่',
          category: 'protein',
          emoji: '',
          quantity: 500,
          unit: 'กรัม',
          createdAt: now,
          updatedAt: now,
          schemaVersion: 1,
          canonicalIngredientId: 'chicken_thigh',
          canonicalUnitId: '',
          canonicalMappingStatus: CanonicalMappingStatus.legacy,
        ),
      ]);

      final writes = await runStartupMigration(h);

      expect(writes, 1);
      final committed = await h.repository.loadConsistentSnapshot();
      expect(
        committed.pantry.single.canonicalIngredientId,
        'chicken_drumstick',
      );
      expect(
        committed.pantry.single.schemaVersion,
        canonicalIngredientMigrationVersion,
      );
    },
  );

  test('commits zero times when nothing needs migrating', () async {
    final h = await harness(<Ingredient>[
      Ingredient(
        id: 'lot-1',
        name: 'น่องไก่',
        category: 'protein',
        emoji: '',
        quantity: 500,
        unit: 'กรัม',
        createdAt: now,
        updatedAt: now,
        schemaVersion: canonicalIngredientMigrationVersion,
        canonicalIngredientId: 'chicken_drumstick',
        canonicalUnitId: 'gram',
        canonicalMappingStatus: CanonicalMappingStatus.mapped,
      ),
    ]);

    final writes = await runStartupMigration(h);

    expect(writes, 0);
  });
}

class _Harness {
  const _Harness({
    required this.store,
    required this.repository,
    required this.coordinator,
  });

  final InMemoryInventoryStore store;
  final HiveInventoryCommitRepository repository;
  final InventoryTransactionCoordinator coordinator;

  static Future<_Harness> create({
    required DateTime now,
    required List<Ingredient> pantry,
    List<CookingHistoryEntry> history = const <CookingHistoryEntry>[],
  }) async {
    final store = InMemoryInventoryStore(
      legacyPantry: pantry,
      legacyHistory: history,
    );
    final clock = FixedAppClock(now);
    final repository = HiveInventoryCommitRepository(
      store: store,
      clock: clock,
    );
    await repository.recoverPendingTransactions();
    return _Harness(
      store: store,
      repository: repository,
      coordinator: InventoryTransactionCoordinator(
        repository: repository,
        clock: clock,
        transactionIdGenerator: SequenceTransactionIdGenerator(),
      ),
    );
  }
}
