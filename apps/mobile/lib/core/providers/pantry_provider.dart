import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation/app_navigation_provider.dart';
import '../../features/pantry/data/repositories/hive_pantry_repository.dart';
import '../../features/pantry/domain/models/pantry_quantity_transaction.dart';
import '../../features/pantry/domain/repositories/pantry_repository.dart';
import '../models/ingredient.dart';
import '../services/storage_service.dart';

final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  return const HivePantryRepository();
});

String normalizePantryIngredientName(String value) {
  return StorageService.normalizeIngredientName(value);
}

class FavoriteIngredientNamesNotifier extends Notifier<Set<String>> {
  PantryRepository get _repository {
    return ref.read(pantryRepositoryProvider);
  }

  @override
  Set<String> build() {
    final storedNames = _repository.getFavoriteIngredientNames();
    final legacyNames = _repository
        .getIngredients()
        .where((ingredient) => ingredient.isFavorite)
        .map((ingredient) => normalizePantryIngredientName(ingredient.name))
        .where((name) => name.isNotEmpty)
        .toSet();
    final mergedNames = <String>{...storedNames, ...legacyNames};

    if (!_sameNames(storedNames, mergedNames)) {
      Future<void>.microtask(
        () => _repository.saveFavoriteIngredientNames(mergedNames),
      );
    }

    return Set<String>.unmodifiable(mergedNames);
  }

  Future<void> addName(String name) async {
    final normalizedName = normalizePantryIngredientName(name);
    if (normalizedName.isEmpty || state.contains(normalizedName)) {
      return;
    }

    final updatedNames = <String>{...state, normalizedName};
    state = Set<String>.unmodifiable(updatedNames);
    await _repository.saveFavoriteIngredientNames(updatedNames);
  }

  Future<void> removeName(String name) async {
    final normalizedName = normalizePantryIngredientName(name);
    if (!state.contains(normalizedName)) {
      return;
    }

    final updatedNames = <String>{...state}..remove(normalizedName);
    state = Set<String>.unmodifiable(updatedNames);
    await _repository.saveFavoriteIngredientNames(updatedNames);
  }

  Future<void> replaceName(String oldName, String newName) async {
    final normalizedOldName = normalizePantryIngredientName(oldName);
    final normalizedNewName = normalizePantryIngredientName(newName);

    if (normalizedOldName == normalizedNewName ||
        !state.contains(normalizedOldName)) {
      return;
    }

    final updatedNames = <String>{...state}
      ..remove(normalizedOldName)
      ..add(normalizedNewName);
    state = Set<String>.unmodifiable(updatedNames);
    await _repository.saveFavoriteIngredientNames(updatedNames);
  }

  static bool _sameNames(Set<String> first, Set<String> second) {
    return first.length == second.length && first.containsAll(second);
  }
}

final favoriteIngredientNamesProvider =
    NotifierProvider<FavoriteIngredientNamesNotifier, Set<String>>(
      FavoriteIngredientNamesNotifier.new,
    );

class PantryNotifier extends Notifier<List<Ingredient>> {
  PantryRepository get _repository {
    return ref.read(pantryRepositoryProvider);
  }

  Set<String> get _favoriteNames {
    return ref.read(favoriteIngredientNamesProvider);
  }

  FavoriteIngredientNamesNotifier get _favoriteNotifier {
    return ref.read(favoriteIngredientNamesProvider.notifier);
  }

  @override
  List<Ingredient> build() {
    final favoriteNames = ref.read(favoriteIngredientNamesProvider);
    final ingredients = _repository.getIngredients();
    final synchronizedIngredients = _applyFavoriteFlags(
      ingredients,
      favoriteNames,
    );

    if (_favoriteFlagsChanged(ingredients, synchronizedIngredients)) {
      Future<void>.microtask(
        () => _repository.saveIngredients(synchronizedIngredients),
      );
    }

    return synchronizedIngredients;
  }

  Future<void> addIngredient(Ingredient ingredient) async {
    final normalizedName = normalizePantryIngredientName(ingredient.name);
    final ingredientToAdd = ingredient.copyWith(
      isFavorite: _favoriteNames.contains(normalizedName),
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
      await _favoriteNotifier.replaceName(
        originalIngredient.name,
        updatedIngredient.name,
      );
    }

    await _repository.saveIngredients(updatedIngredients);
  }

  Future<void> toggleFavorite(String id) async {
    final targetIngredient = _findIngredientById(id);
    if (targetIngredient == null) {
      return;
    }

    final normalizedName = normalizePantryIngredientName(targetIngredient.name);
    final nextFavoriteValue = !_favoriteNames.contains(normalizedName);

    if (nextFavoriteValue) {
      await _favoriteNotifier.addName(targetIngredient.name);
    } else {
      await _favoriteNotifier.removeName(targetIngredient.name);
    }

    final updatedIngredients = state
        .map((ingredient) {
          if (normalizePantryIngredientName(ingredient.name) !=
              normalizedName) {
            return ingredient;
          }

          return ingredient.copyWith(
            isFavorite: nextFavoriteValue,
            updatedAt: DateTime.now(),
          );
        })
        .toList(growable: false);

    state = updatedIngredients;
    await _repository.saveIngredients(updatedIngredients);
  }

  Future<void> removeFavoriteByName(String name) async {
    final normalizedName = normalizePantryIngredientName(name);
    await _favoriteNotifier.removeName(name);

    final updatedIngredients = state
        .map((ingredient) {
          if (normalizePantryIngredientName(ingredient.name) !=
              normalizedName) {
            return ingredient;
          }

          return ingredient.copyWith(
            isFavorite: false,
            updatedAt: DateTime.now(),
          );
        })
        .toList(growable: false);

    state = updatedIngredients;
    await _repository.saveIngredients(updatedIngredients);
  }

  Future<void> applyQuantityTransaction(
    PantryQuantityTransaction transaction,
  ) async {
    if (!transaction.hasChanges) {
      return;
    }

    final changesById = <String, PantryQuantityChange>{
      for (final change in transaction.changes) change.ingredientId: change,
    };
    final now = DateTime.now();
    final updatedIngredients = state
        .map((ingredient) {
          final change = changesById[ingredient.id];
          if (change == null) {
            return ingredient;
          }

          return ingredient.copyWith(
            quantity: change.afterQuantity
                .clamp(0, double.infinity)
                .toDouble(),
            updatedAt: now,
          );
        })
        .toList(growable: false);

    state = updatedIngredients;
    await _repository.saveIngredients(updatedIngredients);
    ref.read(appNavigationProvider.notifier).openPantry();
  }

  Future<int> undoQuantityTransaction(
    PantryQuantityTransaction transaction,
  ) async {
    if (!transaction.hasChanges) {
      return 0;
    }

    final changesById = <String, PantryQuantityChange>{
      for (final change in transaction.changes) change.ingredientId: change,
    };
    var restoredCount = 0;
    final now = DateTime.now();
    final updatedIngredients = state
        .map((ingredient) {
          final change = changesById[ingredient.id];
          if (change == null ||
              (ingredient.quantity - change.afterQuantity).abs() > 0.000001) {
            return ingredient;
          }

          restoredCount++;
          return ingredient.copyWith(
            quantity: change.beforeQuantity,
            updatedAt: now,
          );
        })
        .toList(growable: false);

    if (restoredCount == 0) {
      return 0;
    }

    state = updatedIngredients;
    await _repository.saveIngredients(updatedIngredients);
    return restoredCount;
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
    state = _applyFavoriteFlags(_repository.getIngredients(), _favoriteNames);
  }

  Ingredient? _findIngredientById(String id) {
    for (final ingredient in state) {
      if (ingredient.id == id) {
        return ingredient;
      }
    }

    return null;
  }

  static List<Ingredient> _applyFavoriteFlags(
    List<Ingredient> ingredients,
    Set<String> favoriteNames,
  ) {
    return ingredients
        .map(
          (ingredient) => ingredient.copyWith(
            isFavorite: favoriteNames.contains(
              normalizePantryIngredientName(ingredient.name),
            ),
          ),
        )
        .toList(growable: false);
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