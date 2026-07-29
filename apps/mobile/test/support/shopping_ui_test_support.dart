import 'package:flutter/material.dart';
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
import 'package:mobile/features/pantry/domain/models/inventory_state_envelope.dart';
import 'package:mobile/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/presentation/providers/recipe_provider.dart';
import 'package:mobile/features/shopping/application/shopping_providers.dart';
import 'package:mobile/features/shopping/domain/entities/purchase_history_entry.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_category.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_item.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_list.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_source.dart';
import 'package:mobile/features/shopping/domain/models/shopping_mutation.dart';
import 'package:mobile/features/shopping/domain/services/shopping_draft_builder.dart';
import 'package:mobile/features/shopping/presentation/pages/shopping_page.dart';
import 'package:mobile/features/substitution/domain/repositories/ingredient_substitution_repository.dart';
import 'package:mobile/features/substitution/presentation/providers/substitution_provider.dart';

import 'inventory_test_support.dart';

class ShoppingUiHarness {
  ShoppingUiHarness({
    required this.container,
    required this.repository,
    required this.store,
    required this.now,
  });

  final ProviderContainer container;
  final HiveInventoryCommitRepository repository;
  final InMemoryInventoryStore store;
  final DateTime now;

  static Future<ShoppingUiHarness> create({
    List<Ingredient> pantry = const <Ingredient>[],
    List<Recipe> recipes = const <Recipe>[],
    ShoppingList? list,
    DateTime? at,
    bool seedLegacyShoppingState = false,
    IngredientSubstitutionRepository? substitutionRepository,
  }) async {
    final now = at ?? DateTime.utc(2026, 7, 26, 10);
    final store = list != null && seedLegacyShoppingState
        ? InMemoryInventoryStore(
            envelope: InventoryStateEnvelope.initial(
              createdAt: now,
              pantry: pantry,
              shoppingLists: <ShoppingList>[list],
            ).toJson(),
          )
        : InMemoryInventoryStore(legacyPantry: pantry);
    final repository = HiveInventoryCommitRepository(
      store: store,
      clock: FixedAppClock(now),
    );
    await repository.recoverPendingTransactions();
    final container = ProviderContainer(
      overrides: [
        inventoryCommitRepositoryProvider.overrideWithValue(repository),
        pantryRepositoryProvider.overrideWithValue(
          _MemoryPantryRepository(pantry),
        ),
        appClockProvider.overrideWithValue(FixedAppClock(now)),
        transactionIdGeneratorProvider.overrideWithValue(
          SequenceTransactionIdGenerator(
            List<String>.generate(
              60,
              (index) =>
                  '30000000-0000-4000-8000-${(index + 1).toString().padLeft(12, '0')}',
            ),
          ),
        ),
        canonicalIngredientRegistryProvider.overrideWithValue(testRegistry),
        unitConversionEngineProvider.overrideWithValue(testUnits),
        recipesProvider.overrideWith((ref) async => recipes),
        if (substitutionRepository != null)
          ingredientSubstitutionRepositoryProvider.overrideWithValue(
            substitutionRepository,
          ),
      ],
    );
    if (list != null && !seedLegacyShoppingState) {
      final controller = container.read(shoppingMutationControllerProvider);
      final result = await controller.execute(
        ShoppingMutation.upsert(list: list, createdAt: now),
      );
      if (!result.isSuccess) {
        throw StateError('Could not seed Shopping UI: ${result.code}');
      }
    }
    return ShoppingUiHarness(
      container: container,
      repository: repository,
      store: store,
      now: now,
    );
  }

  Future<List<ShoppingList>> lists() {
    return container.read(shoppingListsProvider.future);
  }

  Future<List<PurchaseHistoryEntry>> history() {
    return container.read(purchaseHistoryProvider.future);
  }

  Future<void> pump(WidgetTester tester) async {
    useShoppingSurface(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const ShoppingPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void dispose() => container.dispose();
}

class _MemoryPantryRepository implements PantryRepository {
  _MemoryPantryRepository(List<Ingredient> pantry)
    : _pantry = List<Ingredient>.of(pantry);

  final List<Ingredient> _pantry;
  final Set<String> _favorites = <String>{};

  @override
  List<Ingredient> getIngredients() => List<Ingredient>.of(_pantry);

  @override
  Set<String> getFavoriteIngredientNames() => Set<String>.of(_favorites);

  @override
  Future<void> saveFavoriteIngredientNames(Set<String> names) async {
    _favorites
      ..clear()
      ..addAll(names);
  }
}

void useShoppingSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1500);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 0.82;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

ShoppingList testShoppingList({
  required DateTime now,
  List<ShoppingItem>? items,
}) {
  return ShoppingList(
    id: 'primary-shopping-list',
    name: 'Weekend cooking',
    items:
        items ??
        <ShoppingItem>[
          testShoppingItem(
            id: 'egg-item',
            canonicalId: 'egg',
            name: 'Egg',
            quantity: 6,
            unit: 'piece',
            category: ShoppingCategory.protein,
            recipeIds: const <String>['omelette'],
            now: now,
          ),
          testShoppingItem(
            id: 'rice-item',
            canonicalId: 'rice',
            name: 'Rice',
            quantity: 1,
            unit: 'kilogram',
            category: ShoppingCategory.grains,
            recipeIds: const <String>['fried-rice'],
            now: now,
          ),
        ],
    createdAt: now,
    updatedAt: now,
  );
}

ShoppingItem testShoppingItem({
  required String id,
  required String canonicalId,
  required String name,
  required double quantity,
  required String unit,
  required ShoppingCategory category,
  required List<String> recipeIds,
  required DateTime now,
}) {
  return ShoppingItemFactory(registry: testRegistry, unitEngine: testUnits)
      .create(
        id: id,
        canonicalIngredientId: canonicalId,
        quantity: quantity,
        unit: unit,
        source: ShoppingSource.recipe,
        sourceReferenceIds: recipeIds,
        createdAt: now,
      )
      .copyWith(displayName: name);
}

Ingredient testPantryLot({
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
    canonicalMappingStatus: CanonicalMappingStatus.mapped,
  );
}

final UnitConversionEngine testUnits = UnitConversionEngine.standard();

final CanonicalIngredientRegistry testRegistry = CanonicalIngredientRegistry(
  ingredients: <CanonicalIngredient>[
    CanonicalIngredient(
      id: 'egg',
      canonicalName: 'Egg',
      localizedNames: const <String, String>{'th': 'ไข่ไก่'},
      aliases: const <String>['chicken egg'],
      searchKeywords: const <String>['breakfast protein'],
      category: 'protein',
      defaultStorageType: IngredientStorageType.refrigerated,
      defaultPurchaseUnitId: 'piece',
      defaultInventoryUnitId: 'piece',
    ),
    CanonicalIngredient(
      id: 'rice',
      canonicalName: 'Rice',
      localizedNames: const <String, String>{'th': 'ข้าว'},
      aliases: const <String>['jasmine rice'],
      searchKeywords: const <String>['grain'],
      category: 'grain',
      defaultStorageType: IngredientStorageType.pantry,
      defaultPurchaseUnitId: 'kilogram',
      defaultInventoryUnitId: 'gram',
    ),
    CanonicalIngredient(
      id: 'pork',
      canonicalName: 'Pork',
      localizedNames: const <String, String>{'th': 'หมู'},
      aliases: const <String>['pork'],
      searchKeywords: const <String>['protein'],
      category: 'protein',
      defaultStorageType: IngredientStorageType.refrigerated,
      defaultPurchaseUnitId: 'gram',
      defaultInventoryUnitId: 'gram',
    ),
    CanonicalIngredient(
      id: 'minced_pork',
      canonicalName: 'Minced Pork',
      localizedNames: const <String, String>{'th': 'หมูสับ'},
      aliases: const <String>['ground pork'],
      searchKeywords: const <String>['protein'],
      category: 'protein',
      defaultStorageType: IngredientStorageType.refrigerated,
      defaultPurchaseUnitId: 'gram',
      defaultInventoryUnitId: 'gram',
      parentId: 'pork',
    ),
    CanonicalIngredient(
      id: 'fish_sauce',
      canonicalName: 'Fish Sauce',
      localizedNames: const <String, String>{'th': 'น้ำปลา'},
      aliases: const <String>[],
      searchKeywords: const <String>['เครื่องปรุง'],
      category: 'seasoning',
      defaultStorageType: IngredientStorageType.pantry,
      defaultPurchaseUnitId: 'tablespoon',
      defaultInventoryUnitId: 'tablespoon',
    ),
    CanonicalIngredient(
      id: 'soy_sauce',
      canonicalName: 'Soy Sauce',
      localizedNames: const <String, String>{'th': 'ซีอิ๊วขาว'},
      aliases: const <String>[],
      searchKeywords: const <String>['เครื่องปรุง'],
      category: 'seasoning',
      defaultStorageType: IngredientStorageType.pantry,
      defaultPurchaseUnitId: 'tablespoon',
      defaultInventoryUnitId: 'tablespoon',
    ),
  ],
);
