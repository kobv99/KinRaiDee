import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation/app_navigation_provider.dart';
import '../../app/navigation/cooking_completion_provider.dart';
import '../../app/providers/canonical_ingredient_providers.dart';
import '../../features/pantry/application/canonical_ingredient_migration.dart';
import '../../features/pantry/application/inventory_transaction_coordinator.dart';
import '../../features/pantry/application/inventory_transaction_providers.dart';
import '../../features/pantry/data/repositories/hive_pantry_repository.dart';
import '../../features/pantry/domain/models/pantry_quantity_transaction.dart';
import '../../features/pantry/domain/repositories/pantry_repository.dart';
import '../../features/pantry/domain/services/cooking_history_adjustment_planner.dart';
import '../../features/pantry/presentation/providers/cooking_history_provider.dart';
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

  InventoryTransactionCoordinator get _coordinator {
    return ref.read(inventoryTransactionCoordinatorProvider);
  }

  @override
  List<Ingredient> build() {
    final favoriteNames = ref.read(favoriteIngredientNamesProvider);
    final ingredients = _repository.getIngredients();
    final synchronizedIngredients = _applyFavoriteFlags(
      ingredients,
      favoriteNames,
    );

    return synchronizedIngredients;
  }

  Future<void> addIngredient(Ingredient ingredient) async {
    final normalizedName = normalizePantryIngredientName(ingredient.name);
    final ingredientToAdd = _canonicalize(
      ingredient.copyWith(isFavorite: _favoriteNames.contains(normalizedName)),
    );
    final updatedIngredients = <Ingredient>[...state, ingredientToAdd];
    await _commitPantryMutation(updatedIngredients, source: 'addIngredient');
  }

  Future<void> updateIngredient(Ingredient ingredient) async {
    final originalIngredient = _findIngredientById(ingredient.id);
    final wasFavorite = originalIngredient?.isFavorite ?? ingredient.isFavorite;
    final updatedIngredient = _canonicalize(
      ingredient.copyWith(
        isFavorite: wasFavorite,
        updatedAt: ref.read(appClockProvider).now(),
      ),
    );
    final updatedIngredients = state
        .map((currentIngredient) {
          if (currentIngredient.id == ingredient.id) {
            return updatedIngredient;
          }

          return currentIngredient;
        })
        .toList(growable: false);

    await _commitPantryMutation(updatedIngredients, source: 'updateIngredient');

    if (originalIngredient != null && wasFavorite) {
      await _favoriteNotifier.replaceName(
        originalIngredient.name,
        updatedIngredient.name,
      );
    }
  }

  Ingredient _canonicalize(Ingredient ingredient) {
    final registry = ref.read(canonicalIngredientRegistryProvider);
    if (registry == null) {
      return ingredient;
    }
    return CanonicalIngredientMigration(
      registry: registry,
      unitEngine: ref.read(unitConversionEngineProvider),
    ).migratePantryIngredient(ingredient);
  }

  Future<void> toggleFavorite(String id) async {
    final targetIngredient = _findIngredientById(id);
    if (targetIngredient == null) {
      return;
    }

    final normalizedName = normalizePantryIngredientName(targetIngredient.name);
    final nextFavoriteValue = !_favoriteNames.contains(normalizedName);

    final now = ref.read(appClockProvider).now();
    final updatedIngredients = state
        .map((ingredient) {
          if (normalizePantryIngredientName(ingredient.name) !=
              normalizedName) {
            return ingredient;
          }

          return ingredient.copyWith(
            isFavorite: nextFavoriteValue,
            updatedAt: now,
          );
        })
        .toList(growable: false);
    await _commitPantryMutation(updatedIngredients, source: 'toggleFavorite');
    if (nextFavoriteValue) {
      await _favoriteNotifier.addName(targetIngredient.name);
    } else {
      await _favoriteNotifier.removeName(targetIngredient.name);
    }
  }

  Future<void> removeFavoriteByName(String name) async {
    final normalizedName = normalizePantryIngredientName(name);
    final now = ref.read(appClockProvider).now();
    final updatedIngredients = state
        .map((ingredient) {
          if (normalizePantryIngredientName(ingredient.name) !=
              normalizedName) {
            return ingredient;
          }

          return ingredient.copyWith(isFavorite: false, updatedAt: now);
        })
        .toList(growable: false);
    await _commitPantryMutation(updatedIngredients, source: 'removeFavorite');
    await _favoriteNotifier.removeName(name);
  }

  Future<PantryQuantityTransaction> applyQuantityTransaction(
    PantryQuantityTransaction transaction,
  ) async {
    if (!transaction.hasChanges) {
      return transaction;
    }
    final result = await _coordinator.completeCooking(transaction);
    await _publishCommitted(result);
    final committedTransaction = result.transaction ?? transaction;
    ref.read(cookingCompletionProvider.notifier).publish(committedTransaction);
    ref.read(appNavigationProvider.notifier).openPantry();
    return committedTransaction;
  }

  Future<int> undoQuantityTransaction(
    PantryQuantityTransaction transaction,
  ) async {
    if (!transaction.hasChanges || transaction.transactionId.isEmpty) {
      return 0;
    }
    final result = await _coordinator.undoCooking(transaction);
    if (result.outcome == InventoryTransactionOutcome.conflict ||
        result.outcome == InventoryTransactionOutcome.validationFailure ||
        result.outcome == InventoryTransactionOutcome.alreadyUndone) {
      return 0;
    }
    await _publishCommitted(result);
    return transaction.changedIngredientCount;
  }

  Future<InventoryTransactionResult> applyHistoryAdjustment({
    required CookingHistoryAdjustmentPlan plan,
    required InventoryTransactionKind kind,
  }) async {
    final result = await _coordinator.applyHistoryAdjustment(
      plan: plan,
      kind: kind,
    );
    if (result.outcome == InventoryTransactionOutcome.alreadyCancelled) {
      return result;
    }
    await _publishCommitted(result);
    return result;
  }

  Future<void> removeIngredient(String id) async {
    final updatedIngredients = state
        .where((ingredient) => ingredient.id != id)
        .toList(growable: false);

    await _commitPantryMutation(updatedIngredients, source: 'removeIngredient');
  }

  Future<void> clear() async {
    await _commitPantryMutation(const <Ingredient>[], source: 'clearPantry');
  }

  Future<void> reload() async {
    final snapshot = await _coordinator.loadSnapshot();
    state = _applyFavoriteFlags(snapshot.pantry, _favoriteNames);
    ref
        .read(cookingHistoryProvider.notifier)
        .replaceFromCommittedSnapshot(snapshot.history);
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

  Future<void> _commitPantryMutation(
    List<Ingredient> ingredients, {
    required String source,
  }) async {
    final result = await _coordinator.replacePantry(
      ingredients,
      source: source,
    );
    await _publishCommitted(result);
  }

  Future<void> _publishCommitted(InventoryTransactionResult result) async {
    if (!result.isSuccess) {
      throw InventoryTransactionException(result.code, result.outcome);
    }
    state = List<Ingredient>.unmodifiable(result.snapshot.pantry);
    ref
        .read(cookingHistoryProvider.notifier)
        .replaceFromCommittedSnapshot(result.snapshot.history);
    final transactionId = result.transaction?.transactionId;
    if (transactionId != null &&
        transactionId.isNotEmpty &&
        (result.outcome == InventoryTransactionOutcome.committed ||
            result.outcome == InventoryTransactionOutcome.alreadyCommitted)) {
      await _coordinator.completePresentation(transactionId);
    }
  }
}

final pantryProvider = NotifierProvider<PantryNotifier, List<Ingredient>>(
  PantryNotifier.new,
);

class InventoryTransactionException implements Exception {
  const InventoryTransactionException(this.code, this.outcome);

  final String code;
  final InventoryTransactionOutcome outcome;

  @override
  String toString() => 'Inventory transaction failed: $code';
}
