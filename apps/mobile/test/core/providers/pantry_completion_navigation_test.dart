import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/navigation/app_navigation_provider.dart';
import 'package:mobile/app/navigation/cooking_completion_provider.dart';
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
  test(
    'successful cooking deduction opens Pantry and records history',
    () async {
      final now = DateTime(2026, 7, 24);
      final repository = _FakePantryRepository(<Ingredient>[
        Ingredient(
          id: 'egg-lot',
          name: 'ไข่ไก่',
          category: 'ไข่',
          emoji: '🥚',
          quantity: 10,
          unit: 'ฟอง',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final inventory = HiveInventoryCommitRepository(
        store: InMemoryInventoryStore(
          legacyPantry: repository.getIngredients(),
        ),
        clock: FixedAppClock(now),
      );
      await inventory.recoverPendingTransactions();
      final container = ProviderContainer(
        overrides: [
          pantryRepositoryProvider.overrideWithValue(repository),
          inventoryCommitRepositoryProvider.overrideWithValue(inventory),
          appClockProvider.overrideWithValue(FixedAppClock(now)),
          transactionIdGeneratorProvider.overrideWithValue(
            SequenceTransactionIdGenerator(),
          ),
        ],
      );
      addTearDown(container.dispose);
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

      container
          .read(appNavigationProvider.notifier)
          .selectTab(AppNavigationNotifier.recipeTab);
      expect(
        container.read(appNavigationProvider),
        AppNavigationNotifier.recipeTab,
      );

      final committed = await container
          .read(pantryProvider.notifier)
          .applyQuantityTransaction(transaction);

      expect(container.read(pantryProvider).single.quantity, 6);
      expect(
        container.read(appNavigationProvider),
        AppNavigationNotifier.pantryTab,
      );
      expect(container.read(cookingCompletionProvider), same(committed));
      final history = container.read(cookingHistoryProvider);
      expect(history, hasLength(1));
      expect(history.single.recipeName, 'ไข่เจียว');
      expect(history.single.status, CookingHistoryStatus.completed);
      expect(history.single.changes.single.consumedQuantity, 4);
    },
  );
}

class _FakePantryRepository implements PantryRepository {
  _FakePantryRepository(List<Ingredient> ingredients)
    : _ingredients = List<Ingredient>.of(ingredients);

  final List<Ingredient> _ingredients;

  @override
  Set<String> getFavoriteIngredientNames() => <String>{};

  @override
  List<Ingredient> getIngredients() => List<Ingredient>.of(_ingredients);

  @override
  Future<void> saveFavoriteIngredientNames(Set<String> names) async {}
}
