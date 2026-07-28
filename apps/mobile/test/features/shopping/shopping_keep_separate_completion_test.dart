import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/time/app_clock.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/pantry/domain/models/inventory_state_envelope.dart';
import 'package:mobile/features/shopping/application/shopping_completion_coordinator.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_category.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_item.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_list.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_source.dart';

import '../../support/inventory_test_support.dart';

void main() {
  test('explicit keep separate preserves both incompatible Pantry units', () async {
    final now = DateTime.utc(2026, 7, 28, 8);
    final existing = Ingredient(
      id: 'fish-sauce-bottle',
      name: 'Fish Sauce',
      category: 'seasoning',
      emoji: '',
      quantity: 1,
      unit: 'bottle',
      createdAt: now,
      updatedAt: now,
      canonicalIngredientId: 'fish_sauce',
      canonicalUnitId: 'bottle',
      canonicalMappingStatus: CanonicalMappingStatus.mapped,
    );
    final item = ShoppingItem(
      id: 'fish-sauce-item',
      canonicalIngredientId: 'fish_sauce',
      displayName: 'Fish Sauce',
      quantity: 250,
      unitId: 'milliliter',
      category: ShoppingCategory.seasonings,
      source: ShoppingSource.recipe,
      sourceReferenceIds: const <String>['tom-yum'],
      createdAt: now,
      updatedAt: now,
    );
    final envelope = InventoryStateEnvelope.initial(
      createdAt: now,
      pantry: <Ingredient>[existing],
      shoppingLists: <ShoppingList>[
        ShoppingList(
          id: 'weekly',
          name: 'Weekly',
          items: <ShoppingItem>[item],
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    final repository = HiveInventoryCommitRepository(
      store: InMemoryInventoryStore(envelope: envelope.toJson()),
      clock: FixedAppClock(now),
    );
    final coordinator = ShoppingCompletionCoordinator(
      repository: repository,
      registry: _registry,
      unitEngine: UnitConversionEngine.standard(),
      clock: FixedAppClock(now),
      transactionIdGenerator: SequenceTransactionIdGenerator(),
    );

    final normal = await coordinator.completeItem(
      listId: 'weekly',
      expectedListRevision: 0,
      itemId: item.id,
      createdAt: now,
    );
    expect(normal.isSuccess, isFalse);
    expect(normal.code, 'shopping_unit_conversion_required');

    final separate = await coordinator.completeItem(
      listId: 'weekly',
      expectedListRevision: 0,
      itemId: item.id,
      createdAt: now,
      keepSeparate: true,
    );

    expect(separate.isSuccess, isTrue);
    expect(separate.snapshot.shoppingLists.single.items, isEmpty);
    expect(separate.snapshot.pantry, hasLength(2));
    expect(
      separate.snapshot.pantry.map((lot) => lot.canonicalUnitId).toSet(),
      <String>{'bottle', 'milliliter'},
    );
    expect(
      separate.snapshot.pantry
          .where((lot) => lot.canonicalUnitId == 'bottle')
          .single
          .quantity,
      1,
    );
    expect(
      separate.snapshot.pantry
          .where((lot) => lot.canonicalUnitId == 'milliliter')
          .single
          .quantity,
      250,
    );
  });
}

final CanonicalIngredientRegistry _registry = CanonicalIngredientRegistry(
  ingredients: <CanonicalIngredient>[
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
    ),
  ],
);
