import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/time/app_clock.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/pantry/domain/models/inventory_state_envelope.dart';
import 'package:mobile/features/shopping/application/shopping_completion_coordinator.dart';
import 'package:mobile/features/shopping/data/repositories/local_shopping_repository.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_category.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_item.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_list.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_source.dart';

import '../../support/inventory_test_support.dart';

void main() {
  final now = DateTime.utc(2026, 7, 27, 10);

  test(
    'completion removes Shopping item, merges Pantry, and records history',
    () async {
      final harness = _Harness.create(
        now: now,
        pantry: <Ingredient>[
          _lot(
            id: 'egg-lot',
            canonicalId: 'egg',
            name: 'ไข่ไก่',
            quantity: 6,
            unit: 'egg',
            now: now,
          ),
        ],
        item: _item(
          id: 'egg-item',
          canonicalId: 'egg',
          name: 'ไข่',
          quantity: 2,
          unit: 'egg',
          category: ShoppingCategory.protein,
          now: now,
        ),
      );

      final completed = await harness.coordinator.completeItem(
        listId: 'weekly',
        expectedListRevision: 0,
        itemId: 'egg-item',
        createdAt: now,
      );

      expect(completed.isSuccess, isTrue);
      expect(completed.snapshot.shoppingLists.single.items, isEmpty);
      expect(completed.snapshot.pantry, hasLength(1));
      expect(completed.snapshot.pantry.single.quantity, 8);
      expect(completed.snapshot.pantry.single.canonicalIngredientId, 'egg');
      await harness.coordinator.completePresentation(
        completed.transaction!.transactionId,
      );

      final history = await harness.shoppingRepository.getPurchaseHistory();
      expect(history, hasLength(1));
      expect(history.single.ingredientName, 'ไข่');
      expect(history.single.quantity, 2);
      expect(history.single.sourceRecipeIds, <String>['omelette']);
      expect(history.single.shoppingListId, 'weekly');
      expect(
        history.single.pantryTransactionId,
        completed.transaction!.transactionId,
      );
    },
  );

  test(
    'convertible units merge and existing duplicates are consolidated',
    () async {
      final harness = _Harness.create(
        now: now,
        pantry: <Ingredient>[
          _lot(
            id: 'fish-sauce-liter',
            canonicalId: 'fish_sauce',
            name: 'น้ำปลา',
            quantity: 0.4,
            unit: 'liter',
            now: now,
          ),
          _lot(
            id: 'fish-sauce-ml',
            canonicalId: 'fish_sauce',
            name: 'Fish sauce',
            quantity: 100,
            unit: 'milliliter',
            now: now.add(const Duration(minutes: 1)),
          ),
        ],
        item: _item(
          id: 'fish-sauce-item',
          canonicalId: 'fish_sauce',
          name: 'น้ำปลา',
          quantity: 250,
          unit: 'milliliter',
          category: ShoppingCategory.seasonings,
          now: now,
        ),
      );

      final completed = await harness.coordinator.completeItem(
        listId: 'weekly',
        expectedListRevision: 0,
        itemId: 'fish-sauce-item',
        createdAt: now,
      );

      expect(completed.isSuccess, isTrue);
      expect(completed.snapshot.pantry, hasLength(1));
      expect(completed.snapshot.pantry.single.canonicalUnitId, 'liter');
      expect(
        completed.snapshot.pantry.single.quantity,
        closeTo(0.75, 0.000001),
      );
    },
  );

  test(
    'canonical stable key and localized alias fallback resolve before merge',
    () async {
      final harness = _Harness.create(
        now: now,
        pantry: <Ingredient>[
          _lot(
            id: 'fish-sauce-liter',
            canonicalId: '',
            name: 'น้ำปลา',
            quantity: 0.4,
            unit: 'liter',
            now: now,
          ),
        ],
        item: _item(
          id: 'fish-sauce-item',
          canonicalId: 'Fish Sauce',
          name: 'น้ำปลา',
          quantity: 0.25,
          unit: 'liter',
          category: ShoppingCategory.seasonings,
          now: now,
        ),
      );

      final completed = await harness.coordinator.completeItem(
        listId: 'weekly',
        expectedListRevision: 0,
        itemId: 'fish-sauce-item',
        createdAt: now,
      );

      expect(completed.isSuccess, isTrue);
      expect(completed.snapshot.pantry, hasLength(1));
      expect(
        completed.snapshot.pantry.single.canonicalIngredientId,
        'fish_sauce',
      );
      expect(
        completed.snapshot.pantry.single.quantity,
        closeTo(0.65, 0.000001),
      );
    },
  );

  test('incompatible units fail without Shopping or Pantry drift', () async {
    final original = _lot(
      id: 'fish-sauce-bottle',
      canonicalId: 'fish_sauce',
      name: 'น้ำปลา',
      quantity: 1,
      unit: 'bottle',
      now: now,
    );
    final harness = _Harness.create(
      now: now,
      pantry: <Ingredient>[original],
      item: _item(
        id: 'fish-sauce-item',
        canonicalId: 'fish_sauce',
        name: 'น้ำปลา',
        quantity: 250,
        unit: 'milliliter',
        category: ShoppingCategory.seasonings,
        now: now,
      ),
    );

    final completed = await harness.coordinator.completeItem(
      listId: 'weekly',
      expectedListRevision: 0,
      itemId: 'fish-sauce-item',
      createdAt: now,
    );

    expect(completed.isSuccess, isFalse);
    expect(completed.code, 'shopping_unit_conversion_required');
    expect(completed.snapshot.pantry.single.toJson(), original.toJson());
    expect(completed.snapshot.shoppingLists.single.items, hasLength(1));
    expect(await harness.shoppingRepository.getPurchaseHistory(), isEmpty);
  });

  test(
    'undo restores Pantry and Shopping and removes projected history',
    () async {
      final original = _lot(
        id: 'egg-lot',
        canonicalId: 'egg',
        name: 'ไข่ไก่',
        quantity: 6,
        unit: 'egg',
        now: now,
      );
      final harness = _Harness.create(
        now: now,
        pantry: <Ingredient>[original],
        item: _item(
          id: 'egg-item',
          canonicalId: 'egg',
          name: 'ไข่',
          quantity: 2,
          unit: 'egg',
          category: ShoppingCategory.protein,
          now: now,
        ),
      );
      final completed = await harness.coordinator.completeItem(
        listId: 'weekly',
        expectedListRevision: 0,
        itemId: 'egg-item',
        createdAt: now,
      );
      await harness.coordinator.completePresentation(
        completed.transaction!.transactionId,
      );

      final undone = await harness.coordinator.undoCompletion(
        purchaseTransactionId: completed.transaction!.transactionId,
        createdAt: now.add(const Duration(seconds: 5)),
      );

      expect(undone.isSuccess, isTrue);
      expect(undone.snapshot.pantry.single.toJson(), original.toJson());
      expect(undone.snapshot.shoppingLists.single.items, hasLength(1));
      expect(undone.snapshot.shoppingLists.single.items.single.id, 'egg-item');
      await harness.coordinator.completePresentation(
        undone.transaction!.transactionId,
      );
      expect(await harness.shoppingRepository.getPurchaseHistory(), isEmpty);
    },
  );
}

class _Harness {
  _Harness({
    required this.repository,
    required this.coordinator,
    required this.shoppingRepository,
  });

  final HiveInventoryCommitRepository repository;
  final ShoppingCompletionCoordinator coordinator;
  final LocalShoppingRepository shoppingRepository;

  factory _Harness.create({
    required DateTime now,
    required List<Ingredient> pantry,
    required ShoppingItem item,
  }) {
    final list = ShoppingList(
      id: 'weekly',
      name: 'Weekly',
      items: <ShoppingItem>[item],
      createdAt: now,
      updatedAt: now,
    );
    final envelope = InventoryStateEnvelope.initial(
      createdAt: now,
      pantry: pantry,
      shoppingLists: <ShoppingList>[list],
    );
    final store = InMemoryInventoryStore(envelope: envelope.toJson());
    final repository = HiveInventoryCommitRepository(
      store: store,
      clock: FixedAppClock(now),
    );
    final coordinator = ShoppingCompletionCoordinator(
      repository: repository,
      registry: _registry,
      unitEngine: UnitConversionEngine.standard(),
      clock: FixedAppClock(now),
      transactionIdGenerator: SequenceTransactionIdGenerator(),
    );
    return _Harness(
      repository: repository,
      coordinator: coordinator,
      shoppingRepository: LocalShoppingRepository(repository),
    );
  }
}

ShoppingItem _item({
  required String id,
  required String canonicalId,
  required String name,
  required double quantity,
  required String unit,
  required ShoppingCategory category,
  required DateTime now,
}) {
  return ShoppingItem(
    id: id,
    canonicalIngredientId: canonicalId,
    displayName: name,
    quantity: quantity,
    unitId: unit,
    category: category,
    source: ShoppingSource.recipe,
    sourceReferenceIds: const <String>['omelette'],
    createdAt: now,
    updatedAt: now,
  );
}

Ingredient _lot({
  required String id,
  required String canonicalId,
  required String name,
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
    canonicalMappingStatus: canonicalId.isEmpty
        ? CanonicalMappingStatus.legacy
        : CanonicalMappingStatus.mapped,
  );
}

final CanonicalIngredientRegistry _registry = CanonicalIngredientRegistry(
  ingredients: <CanonicalIngredient>[
    CanonicalIngredient(
      id: 'egg',
      canonicalName: 'Egg',
      localizedNames: const <String, String>{'th': 'ไข่'},
      aliases: const <String>['chicken egg'],
      searchKeywords: const <String>['ไข่ไก่'],
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
      searchKeywords: const <String>['nam pla'],
      category: 'seasoning',
      defaultStorageType: IngredientStorageType.pantry,
      defaultPurchaseUnitId: 'milliliter',
      defaultInventoryUnitId: 'milliliter',
      emoji: '🧂',
    ),
  ],
);
