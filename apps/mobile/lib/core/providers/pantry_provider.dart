import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/pantry/data/repositories/hive_pantry_repository.dart';
import '../../features/pantry/domain/repositories/pantry_repository.dart';
import '../models/ingredient.dart';

final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  return const HivePantryRepository();
});

class PantryNotifier extends Notifier<List<Ingredient>> {
  PantryRepository get _repository {
    return ref.read(pantryRepositoryProvider);
  }

  @override
  List<Ingredient> build() {
    return _repository.getIngredients();
  }

  Future<void> addIngredient(Ingredient ingredient) async {
    final updatedIngredients = <Ingredient>[...state, ingredient];

    state = updatedIngredients;

    await _repository.saveIngredients(updatedIngredients);
  }

  Future<void> updateIngredient(Ingredient ingredient) async {
    final updatedIngredients = state
        .map((currentIngredient) {
          if (currentIngredient.id == ingredient.id) {
            return ingredient.copyWith(updatedAt: DateTime.now());
          }

          return currentIngredient;
        })
        .toList(growable: false);

    state = updatedIngredients;

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
    state = _repository.getIngredients();
  }
}

final pantryProvider = NotifierProvider<PantryNotifier, List<Ingredient>>(
  PantryNotifier.new,
);
