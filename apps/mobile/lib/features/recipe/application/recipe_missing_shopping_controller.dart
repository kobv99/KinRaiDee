import '../../../core/models/ingredient.dart';
import '../../../core/time/app_clock.dart';
import '../../pantry/application/inventory_transaction_coordinator.dart';
import '../../shopping/application/shopping_providers.dart';
import '../../shopping/domain/entities/shopping_item.dart';
import '../../shopping/domain/entities/shopping_list.dart';
import '../../shopping/domain/models/shopping_mutation.dart';
import '../../shopping/domain/repositories/shopping_repository.dart';
import '../../shopping/domain/services/shopping_engine.dart';
import '../domain/entities/recipe.dart';

enum RecipeMissingShoppingOutcome { committed, noMissingIngredients, unchanged, failed }

class RecipeMissingShoppingResult {
  const RecipeMissingShoppingResult({
    required this.outcome,
    required this.changedItemCount,
    this.transactionResult,
    this.code = '',
  });

  final RecipeMissingShoppingOutcome outcome;
  final int changedItemCount;
  final InventoryTransactionResult? transactionResult;
  final String code;

  bool get isSuccess =>
      outcome == RecipeMissingShoppingOutcome.committed ||
      outcome == RecipeMissingShoppingOutcome.noMissingIngredients ||
      outcome == RecipeMissingShoppingOutcome.unchanged;
}

class RecipeMissingShoppingController {
  const RecipeMissingShoppingController({
    required ShoppingEngine engine,
    required ShoppingRepository shoppingRepository,
    required ShoppingMutationController mutationController,
    required List<Ingredient> Function() readPantry,
    required AppClock clock,
  }) : _engine = engine,
       _shoppingRepository = shoppingRepository,
       _mutationController = mutationController,
       _readPantry = readPantry,
       _clock = clock;

  final ShoppingEngine _engine;
  final ShoppingRepository _shoppingRepository;
  final ShoppingMutationController _mutationController;
  final List<Ingredient> Function() _readPantry;
  final AppClock _clock;

  Future<RecipeMissingShoppingResult> addMissingIngredients({
    required Recipe recipe,
    required int servings,
  }) async {
    final lists = await _shoppingRepository.getLists();
    final existing = lists.firstOrNull;
    final generatedAt = _clock.now().toUtc();
    final generation = _engine.generate(
      listId: existing?.id ?? 'primary-shopping-list',
      name: existing?.name ?? 'รายการซื้อของของฉัน',
      recipes: <ShoppingRecipeRequest>[
        ShoppingRecipeRequest(recipe: recipe, servings: servings),
      ],
      pantry: _readPantry(),
      generatedAt: generatedAt,
      existingList: existing,
    );

    if (generation.missingIngredientCount == 0) {
      return const RecipeMissingShoppingResult(
        outcome: RecipeMissingShoppingOutcome.noMissingIngredients,
        changedItemCount: 0,
      );
    }

    final changedItemCount = _changedItemCount(existing, generation.list);
    if (changedItemCount == 0) {
      return const RecipeMissingShoppingResult(
        outcome: RecipeMissingShoppingOutcome.unchanged,
        changedItemCount: 0,
      );
    }

    final transactionResult = await _mutationController.execute(
      ShoppingMutation.upsert(
        list: generation.list,
        createdAt: generatedAt,
      ),
    );
    if (!transactionResult.isSuccess) {
      return RecipeMissingShoppingResult(
        outcome: RecipeMissingShoppingOutcome.failed,
        changedItemCount: 0,
        transactionResult: transactionResult,
        code: transactionResult.code,
      );
    }
    return RecipeMissingShoppingResult(
      outcome: RecipeMissingShoppingOutcome.committed,
      changedItemCount: changedItemCount,
      transactionResult: transactionResult,
    );
  }

  int _changedItemCount(ShoppingList? before, ShoppingList after) {
    final beforeByCanonical = <String, ShoppingItem>{
      for (final item in before?.items ?? const <ShoppingItem>[])
        item.canonicalIngredientId: item,
    };
    var changed = 0;
    for (final item in after.items) {
      final previous = beforeByCanonical[item.canonicalIngredientId];
      if (previous == null || !_sameActionableItem(previous, item)) {
        changed++;
      }
    }
    return changed;
  }

  bool _sameActionableItem(ShoppingItem first, ShoppingItem second) {
    return first.canonicalIngredientId == second.canonicalIngredientId &&
        first.quantity == second.quantity &&
        first.unitId == second.unitId &&
        first.source == second.source &&
        _sameStrings(first.sourceReferenceIds, second.sourceReferenceIds);
  }

  bool _sameStrings(List<String> first, List<String> second) {
    if (first.length != second.length) {
      return false;
    }
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) {
        return false;
      }
    }
    return true;
  }
}
