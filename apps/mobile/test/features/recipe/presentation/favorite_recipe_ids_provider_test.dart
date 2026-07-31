import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/repositories/recipe_repository.dart';
import 'package:mobile/features/recipe/presentation/providers/favorite_recipe_ids_provider.dart';
import 'package:mobile/features/recipe/presentation/providers/recipe_provider.dart';

void main() {
  test('build loads the persisted favorite ids from the repository', () {
    final repository = _FakeRecipeRepository(
      initialFavorites: <String>{'som-tam', 'pad-krapao'},
    );
    final container = _containerFor(repository);
    addTearDown(container.dispose);

    expect(
      container.read(favoriteRecipeIdsProvider),
      <String>{'som-tam', 'pad-krapao'},
    );
  });

  test('toggle adds an id and persists it through the repository', () async {
    final repository = _FakeRecipeRepository();
    final container = _containerFor(repository);
    addTearDown(container.dispose);

    await container
        .read(favoriteRecipeIdsProvider.notifier)
        .toggle('som-tam');

    expect(container.read(favoriteRecipeIdsProvider), <String>{'som-tam'});
    expect(repository.savedFavorites, <String>{'som-tam'});
  });

  test('toggle removes an already-favorited id and persists the removal', () async {
    final repository = _FakeRecipeRepository(
      initialFavorites: <String>{'som-tam'},
    );
    final container = _containerFor(repository);
    addTearDown(container.dispose);

    await container
        .read(favoriteRecipeIdsProvider.notifier)
        .toggle('som-tam');

    expect(container.read(favoriteRecipeIdsProvider), isEmpty);
    expect(repository.savedFavorites, isEmpty);
  });

  test('build falls back to an empty set when storage is unavailable', () {
    final container = _containerFor(_ThrowingRecipeRepository());
    addTearDown(container.dispose);

    expect(container.read(favoriteRecipeIdsProvider), isEmpty);
  });
}

ProviderContainer _containerFor(RecipeRepository repository) {
  return ProviderContainer(
    overrides: [recipeRepositoryProvider.overrideWithValue(repository)],
  );
}

class _FakeRecipeRepository implements RecipeRepository {
  _FakeRecipeRepository({Set<String>? initialFavorites})
    : savedFavorites = {...?initialFavorites};

  Set<String> savedFavorites;

  @override
  Future<List<Recipe>> getRecipes() async => const <Recipe>[];

  @override
  Set<String> getFavoriteRecipeIds() => savedFavorites;

  @override
  Future<void> saveFavoriteRecipeIds(Set<String> ids) async {
    savedFavorites = {...ids};
  }
}

class _ThrowingRecipeRepository implements RecipeRepository {
  @override
  Future<List<Recipe>> getRecipes() async => const <Recipe>[];

  @override
  Set<String> getFavoriteRecipeIds() {
    throw StateError('storage not initialized');
  }

  @override
  Future<void> saveFavoriteRecipeIds(Set<String> ids) {
    throw StateError('storage not initialized');
  }
}
