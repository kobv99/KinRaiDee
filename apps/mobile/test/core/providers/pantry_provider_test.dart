import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/providers/pantry_provider.dart';
import 'package:mobile/core/time/app_clock.dart';
import 'package:mobile/features/pantry/application/inventory_transaction_providers.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/pantry/domain/models/cooking_history_entry.dart';
import 'package:mobile/features/pantry/domain/models/pantry_quantity_transaction.dart';
import 'package:mobile/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:mobile/features/pantry/presentation/providers/cooking_history_provider.dart';

import '../../support/inventory_test_support.dart';

void main() {
  test('frequent ingredient survives delete, refresh, and re-add', () async {
    final now = DateTime(2026, 7, 23);
    final original = Ingredient(
      id: '1',
      name: 'หมูสับ',
      category: 'เนื้อสัตว์',
      emoji: '🐷',
      quantity: 1,
      unit: 'กิโลกรัม',
      createdAt: now,
      updatedAt: now,
    );
    final repository = _FakePantryRepository(<Ingredient>[original]);
    final firstHarness = await _createContainer(repository, now);
    final firstContainer = firstHarness.container;

    final firstNotifier = firstContainer.read(pantryProvider.notifier);
    await firstNotifier.toggleFavorite(original.id);

    expect(firstContainer.read(pantryProvider).single.isFavorite, isTrue);
    expect(
      firstContainer.read(favoriteIngredientNamesProvider),
      contains('หมูสับ'),
    );

    await firstNotifier.removeIngredient(original.id);

    expect(firstContainer.read(pantryProvider), isEmpty);
    expect(
      firstContainer.read(favoriteIngredientNamesProvider),
      contains('หมูสับ'),
    );
    expect(repository.favoriteNames, contains('หมูสับ'));
    firstContainer.dispose();

    repository.replaceIngredients(
      (await firstHarness.inventory.loadConsistentSnapshot()).pantry,
    );
    final refreshedHarness = await _createContainer(
      repository,
      now,
      inventory: firstHarness.inventory,
      generator: firstHarness.generator,
    );
    final refreshedContainer = refreshedHarness.container;
    addTearDown(refreshedContainer.dispose);

    expect(refreshedContainer.read(pantryProvider), isEmpty);
    expect(
      refreshedContainer.read(favoriteIngredientNamesProvider),
      contains('หมูสับ'),
    );

    await refreshedContainer
        .read(pantryProvider.notifier)
        .addIngredient(
          original.copyWith(
            id: '2',
            isFavorite: false,
            createdAt: now.add(const Duration(minutes: 1)),
            updatedAt: now.add(const Duration(minutes: 1)),
          ),
        );

    expect(refreshedContainer.read(pantryProvider).single.isFavorite, isTrue);
  });

  test('removing from frequent ingredients clears pantry star', () async {
    final now = DateTime(2026, 7, 23);
    final ingredient = Ingredient(
      id: '1',
      name: 'ไข่ไก่',
      category: 'ไข่',
      emoji: '🥚',
      quantity: 12,
      unit: 'ฟอง',
      createdAt: now,
      updatedAt: now,
      isFavorite: true,
    );
    final repository = _FakePantryRepository(
      <Ingredient>[ingredient],
      favoriteNames: <String>{'ไข่ไก่'},
    );
    final harness = await _createContainer(repository, now);
    final container = harness.container;
    addTearDown(container.dispose);

    await container
        .read(pantryProvider.notifier)
        .removeFavoriteByName('ไข่ไก่');

    expect(container.read(favoriteIngredientNamesProvider), isEmpty);
    expect(container.read(pantryProvider).single.isFavorite, isFalse);
    expect(repository.favoriteNames, isEmpty);
  });

  test('quantity transaction can be applied and safely undone', () async {
    final now = DateTime(2026, 7, 24);
    final ingredient = Ingredient(
      id: 'egg-lot',
      name: 'ไข่ไก่',
      category: 'ไข่',
      emoji: '🥚',
      quantity: 10,
      unit: 'ฟอง',
      createdAt: now,
      updatedAt: now,
    );
    final repository = _FakePantryRepository(<Ingredient>[ingredient]);
    final harness = await _createContainer(repository, now);
    final container = harness.container;
    addTearDown(container.dispose);
    final notifier = container.read(pantryProvider.notifier);
    final transaction = PantryQuantityTransaction(
      recipeId: 'egg_omelette',
      recipeName: 'ไข่เจียว',
      servings: 4,
      changes: const <PantryQuantityChange>[
        PantryQuantityChange(
          ingredientId: 'egg-lot',
          ingredientName: 'ไข่ไก่',
          unit: 'ฟอง',
          beforeQuantity: 10,
          afterQuantity: 6,
        ),
      ],
      createdAt: now,
    );

    final committed = await notifier.applyQuantityTransaction(transaction);

    expect(container.read(pantryProvider).single.quantity, 6);
    expect(
      (await harness.inventory.loadConsistentSnapshot()).pantry.single.quantity,
      6,
    );
    expect(
      container.read(cookingHistoryProvider).single.status,
      CookingHistoryStatus.completed,
    );

    final restored = await notifier.undoQuantityTransaction(committed);

    expect(restored, 1);
    expect(container.read(pantryProvider).single.quantity, 10);
    expect(
      (await harness.inventory.loadConsistentSnapshot()).pantry.single.quantity,
      10,
    );
    expect(
      container.read(cookingHistoryProvider).single.status,
      CookingHistoryStatus.cancelled,
    );
  });

  test('undo does not overwrite a quantity edited after deduction', () async {
    final now = DateTime(2026, 7, 24);
    final ingredient = Ingredient(
      id: 'shrimp-lot',
      name: 'กุ้ง',
      category: 'อาหารทะเล',
      emoji: '🦐',
      quantity: 500,
      unit: 'กรัม',
      createdAt: now,
      updatedAt: now,
    );
    final repository = _FakePantryRepository(<Ingredient>[ingredient]);
    final harness = await _createContainer(repository, now);
    final container = harness.container;
    addTearDown(container.dispose);
    final notifier = container.read(pantryProvider.notifier);
    final transaction = PantryQuantityTransaction(
      recipeId: 'shrimp_garlic',
      recipeName: 'กุ้งผัดกระเทียม',
      servings: 2,
      changes: const <PantryQuantityChange>[
        PantryQuantityChange(
          ingredientId: 'shrimp-lot',
          ingredientName: 'กุ้ง',
          unit: 'กรัม',
          beforeQuantity: 500,
          afterQuantity: 300,
        ),
      ],
      createdAt: now,
    );

    final committed = await notifier.applyQuantityTransaction(transaction);
    await notifier.updateIngredient(
      container.read(pantryProvider).single.copyWith(quantity: 250),
    );
    final restored = await notifier.undoQuantityTransaction(committed);

    expect(restored, 0);
    expect(container.read(pantryProvider).single.quantity, 250);
    expect(
      container.read(cookingHistoryProvider).single.status,
      CookingHistoryStatus.completed,
    );
  });
}

class _FakePantryRepository implements PantryRepository {
  _FakePantryRepository(
    List<Ingredient> ingredients, {
    Set<String>? favoriteNames,
  }) : _ingredients = List<Ingredient>.of(ingredients),
       favoriteNames = Set<String>.of(favoriteNames ?? <String>{});

  List<Ingredient> _ingredients;
  Set<String> favoriteNames;

  void replaceIngredients(List<Ingredient> ingredients) {
    _ingredients = List<Ingredient>.of(ingredients);
  }

  @override
  Set<String> getFavoriteIngredientNames() {
    return Set<String>.of(favoriteNames);
  }

  @override
  List<Ingredient> getIngredients() {
    return List<Ingredient>.of(_ingredients);
  }

  @override
  Future<void> saveFavoriteIngredientNames(Set<String> names) async {
    favoriteNames = Set<String>.of(names);
  }
}

Future<
  ({
    ProviderContainer container,
    HiveInventoryCommitRepository inventory,
    SequenceTransactionIdGenerator generator,
  })
>
_createContainer(
  _FakePantryRepository pantry,
  DateTime now, {
  HiveInventoryCommitRepository? inventory,
  SequenceTransactionIdGenerator? generator,
}) async {
  final resolvedInventory =
      inventory ??
      HiveInventoryCommitRepository(
        store: InMemoryInventoryStore(legacyPantry: pantry.getIngredients()),
        clock: FixedAppClock(now),
      );
  await resolvedInventory.recoverPendingTransactions();
  final resolvedGenerator = generator ?? SequenceTransactionIdGenerator();
  return (
    inventory: resolvedInventory,
    generator: resolvedGenerator,
    container: ProviderContainer(
      overrides: [
        pantryRepositoryProvider.overrideWithValue(pantry),
        inventoryCommitRepositoryProvider.overrideWithValue(resolvedInventory),
        appClockProvider.overrideWithValue(FixedAppClock(now)),
        transactionIdGeneratorProvider.overrideWithValue(resolvedGenerator),
      ],
    ),
  );
}
