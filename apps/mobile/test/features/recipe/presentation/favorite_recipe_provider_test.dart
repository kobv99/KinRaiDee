import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/repositories/recipe_repository.dart';
import 'package:mobile/features/recipe/presentation/providers/recipe_provider.dart';

void main() {
  test('loads persisted favorite recipe ids through the repository boundary', () {
    final repository = _FakeRecipeRepository(
      favoriteIds: <String>{'fried-rice'},
    );
    final container = ProviderContainer(
      overrides: [recipeRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final state = container.read(favoriteRecipeIdsProvider);

    expect(state, <String>{'fried-rice'});
  });

  test('toggle adds and then removes a favorite, persisting each change', () async {
    final repository = _FakeRecipeRepository();
    final container = ProviderContainer(
      overrides: [recipeRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(favoriteRecipeIdsProvider.notifier);

    await notifier.toggle('omelette');

    expect(container.read(favoriteRecipeIdsProvider), <String>{'omelette'});
    expect(repository.savedFavoriteIds, <String>{'omelette'});

    await notifier.toggle('omelette');

    expect(container.read(favoriteRecipeIdsProvider), isEmpty);
    expect(repository.savedFavoriteIds, isEmpty);
  });

  test('toggle ignores a blank recipe id without touching storage', () async {
    final repository = _FakeRecipeRepository();
    final container = ProviderContainer(
      overrides: [recipeRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(favoriteRecipeIdsProvider.notifier).toggle('   ');

    expect(container.read(favoriteRecipeIdsProvider), isEmpty);
    expect(repository.saveCount, 0);
  });

  test(
    'build() degrades to an empty set when storage is unavailable, '
    'matching the isolated-test convention used elsewhere in this app',
    () {
      final repository = _UnavailableStorageRecipeRepository();
      final container = ProviderContainer(
        overrides: [recipeRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      expect(container.read(favoriteRecipeIdsProvider), isEmpty);
    },
  );
}

class _FakeRecipeRepository implements RecipeRepository {
  _FakeRecipeRepository({Set<String>? favoriteIds})
    : savedFavoriteIds = Set<String>.of(favoriteIds ?? const <String>{});

  Set<String> savedFavoriteIds;
  int saveCount = 0;

  @override
  Future<List<Recipe>> getRecipes() async => const <Recipe>[];

  @override
  Set<String> getFavoriteRecipeIds() => Set<String>.of(savedFavoriteIds);

  @override
  Future<void> saveFavoriteRecipeIds(Set<String> ids) async {
    saveCount += 1;
    savedFavoriteIds = Set<String>.of(ids);
  }
}

class _UnavailableStorageRecipeRepository implements RecipeRepository {
  @override
  Future<List<Recipe>> getRecipes() async => const <Recipe>[];

  @override
  Set<String> getFavoriteRecipeIds() {
    throw StateError('StorageService has not been initialized.');
  }

  @override
  Future<void> saveFavoriteRecipeIds(Set<String> ids) async {
    throw StateError('StorageService has not been initialized.');
  }
}
