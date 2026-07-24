import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/navigation/app_navigation_provider.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/providers/pantry_provider.dart';
import 'package:mobile/features/pantry/domain/models/pantry_quantity_transaction.dart';
import 'package:mobile/features/pantry/domain/repositories/pantry_repository.dart';

void main() {
  test('successful cooking deduction opens the Pantry tab', () async {
    final now = DateTime(2026, 7, 24);
    final repository = _FakePantryRepository(
      <Ingredient>[
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
      ],
    );
    final container = ProviderContainer(
      overrides: [pantryRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    container
        .read(appNavigationProvider.notifier)
        .selectTab(AppNavigationNotifier.recipeTab);
    expect(
      container.read(appNavigationProvider),
      AppNavigationNotifier.recipeTab,
    );

    await container.read(pantryProvider.notifier).applyQuantityTransaction(
      PantryQuantityTransaction(
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
      ),
    );

    expect(container.read(pantryProvider).single.quantity, 6);
    expect(
      container.read(appNavigationProvider),
      AppNavigationNotifier.pantryTab,
    );
  });
}

class _FakePantryRepository implements PantryRepository {
  _FakePantryRepository(List<Ingredient> ingredients)
    : _ingredients = List<Ingredient>.of(ingredients);

  List<Ingredient> _ingredients;

  @override
  Future<void> clearIngredients() async {
    _ingredients = <Ingredient>[];
  }

  @override
  Set<String> getFavoriteIngredientNames() => <String>{};

  @override
  List<Ingredient> getIngredients() => List<Ingredient>.of(_ingredients);

  @override
  Future<void> saveFavoriteIngredientNames(Set<String> names) async {}

  @override
  Future<void> saveIngredients(List<Ingredient> ingredients) async {
    _ingredients = List<Ingredient>.of(ingredients);
  }
}