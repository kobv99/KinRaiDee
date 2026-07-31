import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/canonical_ingredient_providers.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/providers/pantry_provider.dart';
import 'package:mobile/core/time/app_clock.dart';
import 'package:mobile/features/pantry/application/inventory_transaction_providers.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/pantry/domain/repositories/pantry_repository.dart';

import '../../support/inventory_test_support.dart';

void main() {
  final now = DateTime.utc(2026, 7, 27, 10);

  test(
    'add merges convertible quantity into one canonical Pantry record',
    () async {
      final existing = _ingredient(
        id: 'fish-sauce-liter',
        name: 'น้ำปลา',
        canonicalId: 'fish_sauce',
        quantity: 0.4,
        unit: 'liter',
        now: now,
      );
      final harness = await _createHarness(<Ingredient>[existing], now);
      addTearDown(harness.container.dispose);

      await harness.container
          .read(pantryProvider.notifier)
          .addIngredient(
            _ingredient(
              id: 'fish-sauce-ml',
              name: 'Fish Sauce',
              canonicalId: 'Fish Sauce',
              quantity: 250,
              unit: 'milliliter',
              now: now.add(const Duration(minutes: 1)),
            ),
          );

      final pantry = harness.container.read(pantryProvider);
      expect(pantry, hasLength(1));
      expect(pantry.single.id, 'fish-sauce-liter');
      expect(pantry.single.canonicalIngredientId, 'fish_sauce');
      expect(pantry.single.canonicalUnitId, 'liter');
      expect(pantry.single.quantity, closeTo(0.65, 0.000001));
    },
  );

  test(
    'update into an existing canonical identity consolidates records',
    () async {
      final egg = _ingredient(
        id: 'egg-existing',
        name: 'ไข่',
        canonicalId: 'egg',
        quantity: 6,
        unit: 'egg',
        now: now,
      );
      final edited = _ingredient(
        id: 'custom-record',
        name: 'รายการเดิม',
        canonicalId: 'fish_sauce',
        quantity: 1,
        unit: 'liter',
        now: now,
      );
      final harness = await _createHarness(<Ingredient>[egg, edited], now);
      addTearDown(harness.container.dispose);

      await harness.container
          .read(pantryProvider.notifier)
          .updateIngredient(
            edited.copyWith(
              name: 'ไข่ไก่',
              quantity: 2,
              unit: 'ฟอง',
              canonicalIngredientId: 'egg',
              canonicalUnitId: 'egg',
            ),
          );

      final pantry = harness.container.read(pantryProvider);
      expect(pantry, hasLength(1));
      expect(pantry.single.canonicalIngredientId, 'egg');
      expect(pantry.single.quantity, 8);
    },
  );

  test('incompatible add fails without creating a duplicate', () async {
    final existing = _ingredient(
      id: 'fish-sauce-bottle',
      name: 'น้ำปลา',
      canonicalId: 'fish_sauce',
      quantity: 1,
      unit: 'bottle',
      now: now,
    );
    final harness = await _createHarness(<Ingredient>[existing], now);
    addTearDown(harness.container.dispose);

    await expectLater(
      harness.container
          .read(pantryProvider.notifier)
          .addIngredient(
            _ingredient(
              id: 'fish-sauce-ml',
              name: 'น้ำปลา',
              canonicalId: 'fish_sauce',
              quantity: 250,
              unit: 'milliliter',
              now: now,
            ),
          ),
      throwsA(
        isA<InventoryTransactionException>().having(
          (error) => error.code,
          'code',
          'pantry_unit_conversion_required',
        ),
      ),
    );

    final pantry = harness.container.read(pantryProvider);
    expect(pantry, hasLength(1));
    expect(pantry.single.toJson(), existing.toJson());
  });
}

Future<({ProviderContainer container})> _createHarness(
  List<Ingredient> ingredients,
  DateTime now,
) async {
  final pantryRepository = _MemoryPantryRepository(ingredients);
  final inventoryRepository = HiveInventoryCommitRepository(
    store: InMemoryInventoryStore(legacyPantry: ingredients),
    clock: FixedAppClock(now),
  );
  await inventoryRepository.recoverPendingTransactions();
  final container = ProviderContainer(
    overrides: [
      pantryRepositoryProvider.overrideWithValue(pantryRepository),
      inventoryCommitRepositoryProvider.overrideWithValue(inventoryRepository),
      appClockProvider.overrideWithValue(FixedAppClock(now)),
      transactionIdGeneratorProvider.overrideWithValue(
        SequenceTransactionIdGenerator(),
      ),
      canonicalIngredientRegistryProvider.overrideWithValue(_registry),
      unitConversionEngineProvider.overrideWithValue(
        UnitConversionEngine.standard(),
      ),
    ],
  );
  return (container: container);
}

Ingredient _ingredient({
  required String id,
  required String name,
  required String canonicalId,
  required double quantity,
  required String unit,
  required DateTime now,
}) {
  return Ingredient(
    id: id,
    name: name,
    category: 'test',
    emoji: 'T',
    quantity: quantity,
    unit: unit,
    createdAt: now,
    updatedAt: now,
    canonicalIngredientId: canonicalId,
    canonicalUnitId: unit,
    canonicalMappingStatus: CanonicalMappingStatus.mapped,
  );
}

class _MemoryPantryRepository implements PantryRepository {
  _MemoryPantryRepository(List<Ingredient> ingredients)
    : _ingredients = List<Ingredient>.of(ingredients);

  final List<Ingredient> _ingredients;

  @override
  List<Ingredient> getIngredients() => List<Ingredient>.of(_ingredients);

  @override
  Set<String> getFavoriteIngredientNames() => const <String>{};

  @override
  Future<void> saveFavoriteIngredientNames(Set<String> names) async {}
}

final CanonicalIngredientRegistry _registry = CanonicalIngredientRegistry(
  ingredients: <CanonicalIngredient>[
    CanonicalIngredient(
      id: 'egg',
      canonicalName: 'Egg',
      localizedNames: const <String, String>{'th': 'ไข่'},
      aliases: const <String>['ไข่ไก่'],
      searchKeywords: const <String>[],
      category: 'protein',
      defaultStorageType: IngredientStorageType.refrigerated,
      defaultPurchaseUnitId: 'egg',
      defaultInventoryUnitId: 'egg',
      emoji: '🥚',
    ),
    CanonicalIngredient(
      id: 'fish_sauce',
      canonicalName: 'Fish Sauce',
      localizedNames: const <String, String>{'th': 'น้ำปลา'},
      aliases: const <String>['fish sauce'],
      searchKeywords: const <String>[],
      category: 'seasoning',
      defaultStorageType: IngredientStorageType.pantry,
      defaultPurchaseUnitId: 'milliliter',
      defaultInventoryUnitId: 'milliliter',
      emoji: '🧂',
    ),
  ],
);
