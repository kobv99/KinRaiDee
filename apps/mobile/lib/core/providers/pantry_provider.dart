import 'dart:async';

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
    final storedFavoriteNames = _repository.getFavoriteIngredientNames();
    final favoriteNames = <String>{
      ...storedFavoriteNames,
      ...ingredients
          .where((ingredient) => ingredient.isFavorite)
          .map((ingredient) => _normalizeName(ingredient.name)),
    };

    if (favoriteNames.length != storedFavoriteNames.length) {
      unawaited(_repository.saveFavoriteIngredientNames(favoriteNames));
    }

    final synchronizedIngredients = ingredients
        .map(
          (ingredient) => ingredient.copyWith(
            isFavorite: favoriteNames.contains(_normalizeName(ingredient.name)),
          ),
        )
        .toList(growable: false);

    if (_favoriteFlagsChanged(ingredients, synchronizedIngredients)) {
      unawaited(_repository.saveIngredients(synchronizedIngredients));
    }

    return synchronizedIngredients;
  }

  Future<void> addIngredient(Ingredient ingredient) async {
    final favoriteNames = _repository.getFavoriteIngredientNames();
    final ingredientToAdd = ingredient.copyWith(
      isFavorite: favoriteNames.contains(_normalizeName(ingredient.name)),
    );
    final updatedIngredients = <Ingredient>[...state, ingredientToAdd];

    state = updatedIngredients;

    await _repository.saveIngredients(updatedIngredients);
  }

  Future<void> updateIngredient(Ingredient ingredient) async {
    final originalIngredient = state
        .where((currentIngredient) => currentIngredient.id == ingredient.id)
        .firstOrNull;
    final wasFavorite = originalIngredient?.isFavorite ?? ingredient.isFavorite;

    final updatedIngredients = state
        .map((currentIngredient) {
          if (currentIngredient.id == ingredient.id) {
            return ingredient.copyWith(
              isFavorite: wasFavorite,
              updatedAt: DateTime.now(),
            );
          }

          return currentIngredient;
        })
        .toList(growable: false);

    state = updatedIngredients;

    if (originalIngredient != null &&
        _normalizeName(originalIngredient.name) != _normalizeName(ingredient.name) &&
        wasFavorite) {
      final favoriteNames = _repository.getFavoriteIngredientNames();
      favoriteNames
        ..remove(_normalizeName(originalIngredient.name))
        ..add(_normalizeName(ingredient.name));
      await _repository.saveFavoriteIngredientNames(favoriteNames);
    }

    await _repository.saveIngredients(updatedIngredients);
  }

  Future<void> toggleFavorite(String id) async {
    final targetIngredient = state
        .where((ingredient) => ingredient.id == id)
        .firstOrNull;

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

    await Future.wait([
      _repository.saveIngredients(updatedIngredients),
      _repository.saveFavoriteIngredientNames(favoriteNames),
    ]);
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
            isFavorite: favoriteNames.contains(_normalizeName(ingredient.name)),
          ),
        )
        .toList(growable: false);
  }

  static String _normalizeName(String value) {
    return StorageService.normalizeIngredientName(value);
  }

  static bool _favoriteFlagsChanged(
    List<Ingredient> original,
    List<Ingredient> synchronized,
  ) {
    if (original.length != synchronized.length) {
      return true;
    }

    for (var index = 0; index < original.length; index++) {
      if (original[index].isFavorite != synchronized[index].isFavorite) {
        return true;
      }
    }

    return false;
  }
}

final pantryProvider = NotifierProvider<PantryNotifier, List<Ingredient>>(
  PantryNotifier.new,
);
