import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/providers/pantry_provider.dart';
import 'package:mobile/features/pantry/domain/repositories/pantry_repository.dart';

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
    final firstContainer = ProviderContainer(
      overrides: [pantryRepositoryProvider.overrideWithValue(repository)],
    );

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

    final refreshedContainer = ProviderContainer(
      overrides: [pantryRepositoryProvider.overrideWithValue(repository)],
    );
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
    final container = ProviderContainer(
      overrides: [pantryRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container
        .read(pantryProvider.notifier)
        .removeFavoriteByName('ไข่ไก่');

    expect(container.read(favoriteIngredientNamesProvider), isEmpty);
    expect(container.read(pantryProvider).single.isFavorite, isFalse);
    expect(repository.favoriteNames, isEmpty);
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
