import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/providers/pantry_provider.dart';
import 'package:mobile/features/pantry/domain/repositories/pantry_repository.dart';

void main() {
  test('favorite survives delete and is restored when the same item is added', () async {
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
    final container = ProviderContainer(
      overrides: [pantryRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(pantryProvider.notifier);

    await notifier.toggleFavorite(original.id);
    expect(container.read(pantryProvider).single.isFavorite, isTrue);

    await notifier.removeIngredient(original.id);
    expect(container.read(pantryProvider), isEmpty);
    expect(repository.favoriteNames, contains('หมูสับ'));

    await notifier.addIngredient(
      original.copyWith(
        id: '2',
        isFavorite: false,
        createdAt: now.add(const Duration(minutes: 1)),
        updatedAt: now.add(const Duration(minutes: 1)),
      ),
    );

    expect(container.read(pantryProvider).single.isFavorite, isTrue);
  });
}

class _FakePantryRepository implements PantryRepository {
  _FakePantryRepository(List<Ingredient> ingredients)
      : _ingredients = List<Ingredient>.of(ingredients);

  List<Ingredient> _ingredients;
  Set<String> favoriteNames = <String>{};

  @override
  Future<void> clearIngredients() async {
    _ingredients = <Ingredient>[];
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

  @override
  Future<void> saveIngredients(List<Ingredient> ingredients) async {
    _ingredients = List<Ingredient>.of(ingredients);
  }
}
