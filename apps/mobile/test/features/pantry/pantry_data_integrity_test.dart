import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/canonical_ingredient_providers.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/providers/pantry_provider.dart';
import 'package:mobile/core/time/app_clock.dart';
import 'package:mobile/features/pantry/application/inventory_transaction_providers.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:mobile/features/pantry/presentation/providers/pantry_filter_provider.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';

import '../../support/inventory_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'created ingredients publish, persist, search, and reload immediately',
    () async {
      final now = DateTime.utc(2026, 7, 29, 9);
      final registry = await IngredientCatalog().loadRegistry();
      final clock = _TestAppClock(now);
      final inventory = HiveInventoryCommitRepository(
        store: InMemoryInventoryStore(),
        clock: clock,
      );
      await inventory.recoverPendingTransactions();

      final container = ProviderContainer(
        overrides: [
          pantryRepositoryProvider.overrideWithValue(
            const _EmptyPantryRepository(),
          ),
          inventoryCommitRepositoryProvider.overrideWithValue(inventory),
          canonicalIngredientRegistryProvider.overrideWithValue(registry),
          appClockProvider.overrideWithValue(clock),
          transactionIdGeneratorProvider.overrideWithValue(
            SequenceTransactionIdGenerator(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(pantryProvider.notifier);
      final examples = <Ingredient>[
        _ingredient(
          id: 'duck-lot',
          name: 'Duck',
          unit: 'กรัม',
          canonicalUnitId: 'gram',
          now: now,
        ),
        _ingredient(
          id: 'chicken-lot',
          name: 'Chicken Breast',
          unit: 'กรัม',
          canonicalUnitId: 'gram',
          now: now,
        ),
        _ingredient(
          id: 'tilapia-lot',
          name: 'Tilapia',
          unit: 'ตัว',
          canonicalUnitId: 'whole',
          now: now,
        ),
      ];

      for (final ingredient in examples) {
        await notifier.addIngredient(ingredient);
      }

      expect(container.read(pantryProvider), hasLength(3));
      expect(
        container
            .read(pantryProvider)
            .map((item) => item.canonicalIngredientId)
            .toSet(),
        containsAll(<String>{'duck', 'chicken_breast', 'tilapia'}),
      );

      final persisted = await inventory.loadConsistentSnapshot();
      expect(persisted.pantry, hasLength(3));

      container.read(pantryFilterProvider.notifier).setSearchQuery('Tilapia');
      expect(container.read(filteredPantryProvider).single.name, 'Tilapia');

      await notifier.reload();
      expect(container.read(pantryProvider), hasLength(3));
    },
  );
}

Ingredient _ingredient({
  required String id,
  required String name,
  required String unit,
  required String canonicalUnitId,
  required DateTime now,
}) {
  return Ingredient(
    id: id,
    name: name,
    category: 'เนื้อสัตว์',
    emoji: '🍽️',
    quantity: 1,
    unit: unit,
    createdAt: now,
    updatedAt: now,
    canonicalUnitId: canonicalUnitId,
  );
}

class _TestAppClock implements AppClock {
  const _TestAppClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

class _EmptyPantryRepository implements PantryRepository {
  const _EmptyPantryRepository();

  @override
  List<Ingredient> getIngredients() => const <Ingredient>[];

  @override
  Set<String> getFavoriteIngredientNames() => const <String>{};

  @override
  Future<void> saveFavoriteIngredientNames(Set<String> names) async {}
}
