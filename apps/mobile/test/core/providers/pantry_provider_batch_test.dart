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

final _now = DateTime(2026, 8, 4);
final _registry = CanonicalIngredientRegistry(
  ingredients: <CanonicalIngredient>[
    CanonicalIngredient(
      id: 'pork_belly',
      canonicalName: 'Pork belly',
      localizedNames: const <String, String>{'th': 'หมูสามชั้น'},
      aliases: const <String>[],
      searchKeywords: const <String>[],
      category: 'protein',
      defaultStorageType: IngredientStorageType.refrigerated,
      defaultPurchaseUnitId: 'kilogram',
      defaultInventoryUnitId: 'gram',
      taxonomyType: IngredientTaxonomyType.cut,
    ),
    CanonicalIngredient(
      id: 'mackerel',
      canonicalName: 'Mackerel',
      localizedNames: const <String, String>{'th': 'ปลาทู'},
      aliases: const <String>[],
      searchKeywords: const <String>[],
      category: 'seafood',
      defaultStorageType: IngredientStorageType.refrigerated,
      defaultPurchaseUnitId: 'whole',
      defaultInventoryUnitId: 'whole',
      taxonomyType: IngredientTaxonomyType.species,
    ),
  ],
);
final _unitEngine = UnitConversionEngine.standard();

void main() {
  test('a batch of distinct ingredients commits in exactly one transaction '
      'and one state publication', () async {
    final harness = await _createContainer();
    final container = harness.container;
    addTearDown(container.dispose);
    final beforeRevision =
        (await harness.inventory.loadConsistentSnapshot()).revision;

    var publishCount = 0;
    container.listen(pantryProvider, (previous, next) => publishCount++);

    await container.read(pantryProvider.notifier).addIngredientsBatch(
      <Ingredient>[
        _draft('pork_belly', 'หมูสามชั้น', 300, 'กรัม'),
        _draft('mackerel', 'ปลาทู', 1, 'ตัว'),
      ],
    );

    final afterRevision =
        (await harness.inventory.loadConsistentSnapshot()).revision;
    expect(afterRevision - beforeRevision, 1);
    expect(publishCount, 1);
    expect(container.read(pantryProvider), hasLength(2));
    expect(
      container.read(pantryProvider).map((i) => i.canonicalIngredientId),
      containsAll(<String>['pork_belly', 'mackerel']),
    );
  });

  test('two selections resolving to the same canonical id merge into one lot, '
      'not two', () async {
    final harness = await _createContainer();
    final container = harness.container;
    addTearDown(container.dispose);

    await container
        .read(pantryProvider.notifier)
        .addIngredientsBatch(<Ingredient>[
          _draft('pork_belly', 'หมูสามชั้น', 300, 'กรัม'),
          _draft('pork_belly', 'หมูสามชั้น', 200, 'กรัม'),
        ]);

    final pantry = container.read(pantryProvider);
    expect(pantry, hasLength(1));
    expect(pantry.single.quantity, 500);
  });

  test('a repository failure produces zero partial additions — the pantry is '
      'unchanged', () async {
    final harness = await _createContainer();
    final container = harness.container;
    addTearDown(container.dispose);
    harness.store.failEnvelopeWrites = true;

    await expectLater(
      container.read(pantryProvider.notifier).addIngredientsBatch(<Ingredient>[
        _draft('pork_belly', 'หมูสามชั้น', 300, 'กรัม'),
        _draft('mackerel', 'ปลาทู', 1, 'ตัว'),
      ]),
      throwsA(isA<InventoryTransactionException>()),
    );

    expect(container.read(pantryProvider), isEmpty);
  });

  test('retrying after a failure succeeds and adds every item once', () async {
    final harness = await _createContainer();
    final container = harness.container;
    addTearDown(container.dispose);
    harness.store.failEnvelopeWrites = true;

    final batch = <Ingredient>[
      _draft('pork_belly', 'หมูสามชั้น', 300, 'กรัม'),
      _draft('mackerel', 'ปลาทู', 1, 'ตัว'),
    ];

    await expectLater(
      container.read(pantryProvider.notifier).addIngredientsBatch(batch),
      throwsA(isA<InventoryTransactionException>()),
    );
    expect(container.read(pantryProvider), isEmpty);

    harness.store.failEnvelopeWrites = false;
    await container.read(pantryProvider.notifier).addIngredientsBatch(batch);

    final pantry = container.read(pantryProvider);
    expect(pantry, hasLength(2));
  });

  test('an empty batch is a no-op', () async {
    final harness = await _createContainer();
    final container = harness.container;
    addTearDown(container.dispose);
    final beforeRevision =
        (await harness.inventory.loadConsistentSnapshot()).revision;

    await container
        .read(pantryProvider.notifier)
        .addIngredientsBatch(const <Ingredient>[]);

    final afterRevision =
        (await harness.inventory.loadConsistentSnapshot()).revision;
    expect(afterRevision, beforeRevision);
    expect(container.read(pantryProvider), isEmpty);
  });
}

Ingredient _draft(
  String canonicalId,
  String name,
  double quantity,
  String unit,
) {
  return Ingredient(
    id: '$canonicalId-draft',
    name: name,
    category: 'test',
    emoji: '',
    quantity: quantity,
    unit: unit,
    createdAt: _now,
    updatedAt: _now,
  );
}

Future<
  ({
    ProviderContainer container,
    HiveInventoryCommitRepository inventory,
    InMemoryInventoryStore store,
  })
>
_createContainer() async {
  final store = InMemoryInventoryStore();
  final inventory = HiveInventoryCommitRepository(
    store: store,
    clock: FixedAppClock(_now),
  );
  await inventory.recoverPendingTransactions();
  final container = ProviderContainer(
    overrides: [
      pantryRepositoryProvider.overrideWithValue(_EmptyPantryRepository()),
      inventoryCommitRepositoryProvider.overrideWithValue(inventory),
      appClockProvider.overrideWithValue(FixedAppClock(_now)),
      transactionIdGeneratorProvider.overrideWithValue(
        SequenceTransactionIdGenerator(),
      ),
      canonicalIngredientRegistryProvider.overrideWithValue(_registry),
      unitConversionEngineProvider.overrideWithValue(_unitEngine),
    ],
  );
  return (container: container, inventory: inventory, store: store);
}

class _EmptyPantryRepository implements PantryRepository {
  @override
  Set<String> getFavoriteIngredientNames() => const <String>{};

  @override
  List<Ingredient> getIngredients() => const <Ingredient>[];

  @override
  Future<void> saveFavoriteIngredientNames(Set<String> names) async {}
}
