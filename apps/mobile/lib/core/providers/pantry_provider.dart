import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/pantry/data/repositories/hive_pantry_repository.dart';
import '../../features/pantry/domain/repositories/pantry_repository.dart';
import '../models/ingredient.dart';
import '../services/storage_service.dart';

final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  return const HivePantryRepository();
});

class PantryNotifier extends Notifier<List<Ingredient>> {
  Set<String> _favoriteNames = <String>{};

  PantryRepository get _repository {
    return ref.read(pantryRepositoryProvider);
  }

  @override
  List<Ingredient> build() {
    final ingredients = _repository.getIngredients();
    final storedFavoriteNames = _repository.getFavoriteIngredientNames();
    final legacyFavoriteNames = ingredients
        .where((ingredient) => ingredient.isFavorite)
        .map((ingredient) => _normalizeName(ingredient.name))
        .where((name) => name.isNotEmpty)
        .toSet();

    _favoriteNames = <String>{
      ...storedFavoriteNames,
      ...legacyFavoriteNames,
    };

    if (_favoriteNames.length != storedFavoriteNames.length) {
      final namesToPersist = Set<String>.of(_favoriteNames);
      Future<void>.microtask(
        () => _repository.saveFavoriteIngredientNames(namesToPersist),
      );
    }

    return _applyFavoriteFlags(ingredients);
  }

  Future<void> addIngredient(Ingredient ingredient) async {
    final normalizedName = _normalizeName(ingredient.name);
    final ingredientToAdd = ingredient.copyWith(
      isFavorite:
          ingredient.isFavorite || _favoriteNames.contains(normalizedName),
    );
    final updatedIngredients = <Ingredient>[...state, ingredientToAdd];

    state = updatedIngredients;
    await _repository.saveIngredients(updatedIngredients);
  }

  Future<void> updateIngredient(Ingredient ingredient) async {
    final originalIngredient = _findIngredientById(ingredient.id);
    final wasFavorite = originalIngredient?.isFavorite ?? ingredient.isFavorite;
    final oldName = originalIngredient == null
        ? null
        : _normalizeName(originalIngredient.name);
    final newName = _normalizeName(ingredient.name);

    if (wasFavorite && oldName != newName) {
      if (oldName != null) {
        _favoriteNames.remove(oldName);
      }
      if (newName.isNotEmpty) {
        _favoriteNames.add(newName);
      }
      await _repository.saveFavoriteIngredientNames(
        Set<String>.of(_favoriteNames),
      );
    }

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
    await _repository.saveIngredients(updatedIngredients);
  }

  Future<void> toggleFavorite(String id) async {
    final targetIngredient = _findIngredientById(id);
    if (targetIngredient == null) {
      return;
    }

    final normalizedName = _normalizeName(targetIngredient.name);
    final nextFavoriteValue = !targetIngredient.isFavorite;

    if (nextFavoriteValue) {
      _favoriteNames.add(normalizedName);
    } else {
      _favoriteNames.remove(normalizedName);
    }

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

    state = updatedIngredients;

    await _repository.saveFavoriteIngredientNames(
      Set<String>.of(_favoriteNames),
    );
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
    _favoriteNames = _repository.getFavoriteIngredientNames();
    state = _applyFavoriteFlags(_repository.getIngredients());
  }

  List<Ingredient> _applyFavoriteFlags(List<Ingredient> ingredients) {
    return ingredients
        .map((ingredient) {
          final shouldBeFavorite =
              ingredient.isFavorite ||
              _favoriteNames.contains(_normalizeName(ingredient.name));

          if (ingredient.isFavorite == shouldBeFavorite) {
            return ingredient;
          }

          return ingredient.copyWith(isFavorite: shouldBeFavorite);
        })
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
