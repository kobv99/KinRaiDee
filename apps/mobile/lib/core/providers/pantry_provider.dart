import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/pantry/data/repositories/hive_pantry_repository.dart';
import '../../features/pantry/domain/repositories/pantry_repository.dart';
import '../models/ingredient.dart';
import '../services/storage_service.dart';

final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  return const HivePantryRepository();
});

class PantryNotifier extends Notifier<List<Ingredient>> {
  PantryRepository get _repository {
    return ref.read(pantryRepositoryProvider);
  }

  @override
  List<Ingredient> build() {
    final ingredients = _repository.getIngredients();
    final favoriteNames = _repository.getFavoriteIngredientNames();

    final legacyFavoriteNames = ingredients
        .where((ingredient) => ingredient.isFavorite)
        .map((ingredient) => _normalizeName(ingredient.name))
        .where((name) => name.isNotEmpty)
        .toSet();

    if (legacyFavoriteNames.isNotEmpty) {
      final migratedFavoriteNames = <String>{
        ...favoriteNames,
        ...legacyFavoriteNames,
      };

      Future<void>.microtask(
        () => _repository.saveFavoriteIngredientNames(migratedFavoriteNames),
      );

      favoriteNames.addAll(legacyFavoriteNames);
    }

    return ingredients
        .map((ingredient) {
          final shouldBeFavorite =
              ingredient.isFavorite ||
              favoriteNames.contains(_normalizeName(ingredient.name));

          if (ingredient.isFavorite == shouldBeFavorite) {
            return ingredient;
          }

          return ingredient.copyWith(isFavorite: shouldBeFavorite);
        })
        .toList(growable: false);
  }

  Future<void> addIngredient(Ingredient ingredient) async {
    final favoriteNames = _repository.getFavoriteIngredientNames();
    final ingredientToAdd = ingredient.copyWith(
      isFavorite:
          ingredient.isFavorite ||
          favoriteNames.contains(_normalizeName(ingredient.name)),
    );
    final updatedIngredients = <Ingredient>[...state, ingredientToAdd];

    state = updatedIngredients;

    await _repository.saveIngredients(updatedIngredients);
  }

  Future<void> updateIngredient(Ingredient ingredient) async {
    final originalIngredient = _findIngredientById(ingredient.id);
    final wasFavorite = originalIngredient?.isFavorite ?? ingredient.isFavorite;

    final updatedIngredient = ingredient.copyWith(
      isFavorite: wasFavorite,
      updatedAt: DateTime.now(),
    );

    final updatedIngredients = state
        .map((currentIngredient) {
          if (currentIngredient.id == ingredient.id) {
            return updatedIngredient;
          }

          return currentIngredient;
        })
        .toList(growable: false);

    state = updatedIngredients;

    if (originalIngredient != null && wasFavorite) {
      final oldName = _normalizeName(originalIngredient.name);
      final newName = _normalizeName(updatedIngredient.name);

      if (oldName != newName) {
        final favoriteNames = _repository.getFavoriteIngredientNames();
        favoriteNames
          ..remove(oldName)
          ..add(newName);
        await _repository.saveFavoriteIngredientNames(favoriteNames);
      }
    }

    await _repository.saveIngredients(updatedIngredients);
  }

  Future<void> toggleFavorite(String id) async {
    final targetIngredient = _findIngredientById(id);

    if (targetIngredient == null) {
      return;
    }

    final normalizedName = _normalizeName(targetIngredient.name);
    final nextFavoriteValue = !targetIngredient.isFavorite;
    final updatedIngredients = state
        .map((ingredient) {
          if (_normalizeName(ingredient.name) != normalizedName) {
            return ingredient;
          }

          return ingredient.copyWith(
            isFavorite: nextFavoriteValue,
            updatedAt: DateTime.now(),
          );
        })
        .toList(growable: false);

    final favoriteNames = _repository.getFavoriteIngredientNames();
    if (nextFavoriteValue) {
      favoriteNames.add(normalizedName);
    } else {
      favoriteNames.remove(normalizedName);
    }

    state = updatedIngredients;

    await _repository.saveFavoriteIngredientNames(favoriteNames);
    await _repository.saveIngredients(updatedIngredients);
  }

  Future<void> removeIngredient(String id) async {
    final updatedIngredients = state
        .where((ingredient) => ingredient.id != id)
        .toList(growable: false);

    state = updatedIngredients;

    await _repository.saveIngredients(updatedIngredients);
  }

  Future<void> clear() async {
    state = <Ingredient>[];

    await _repository.clearIngredients();
  }

  Future<void> reload() async {
    final favoriteNames = _repository.getFavoriteIngredientNames();
    state = _repository
        .getIngredients()
        .map(
          (ingredient) => ingredient.copyWith(
            isFavorite:
                ingredient.isFavorite ||
                favoriteNames.contains(_normalizeName(ingredient.name)),
          ),
        )
        .toList(growable: false);
  }

  Ingredient? _findIngredientById(String id) {
    for (final ingredient in state) {
      if (ingredient.id == id) {
        return ingredient;
      }
    }

    return null;
  }

  static String _normalizeName(String value) {
    return StorageService.normalizeIngredientName(value);
  }
}

final pantryProvider = NotifierProvider<PantryNotifier, List<Ingredient>>(
  PantryNotifier.new,
);
