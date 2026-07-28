import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/core/time/app_clock.dart';
import 'package:mobile/features/pantry/application/inventory_transaction_coordinator.dart';
import 'package:mobile/features/pantry/domain/models/inventory_state_envelope.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/shopping/application/shopping_recommendation_controller.dart';
import 'package:mobile/features/shopping/domain/entities/purchase_history_entry.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_list.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_recommendation.dart';
import 'package:mobile/features/shopping/domain/models/shopping_mutation.dart';
import 'package:mobile/features/shopping/domain/repositories/shopping_repository.dart';

void main() {
  test('explicit repeated Add reaches target once without duplicates', () async {
    final now = DateTime.utc(2026, 7, 28, 10);
    final repository = _MemoryShoppingRepository();
    var mutationCount = 0;
    final controller = ShoppingRecommendationController(
      repository: repository,
      registry: _registry,
      unitEngine: UnitConversionEngine.standard(),
      clock: FixedAppClock(now),
      executeMutation: (mutation) async {
        mutationCount++;
        final list = mutation.list!;
        repository.lists = <ShoppingList>[list];
        return InventoryTransactionResult(
          outcome: InventoryTransactionOutcome.committed,
          code: 'committed',
          snapshot: InventoryStateEnvelope.initial(
            createdAt: now,
            shoppingLists: <ShoppingList>[list],
          ),
        );
      },
    );

    final first = await controller.addToShopping(_recommendation);
    final second = await controller.addToShopping(_recommendation);

    expect(first.outcome, ShoppingRecommendationAddOutcome.added);
    expect(second.outcome, ShoppingRecommendationAddOutcome.unchanged);
    expect(mutationCount, 1);
    final items = repository.lists.single.items;
    expect(items, hasLength(1));
    expect(items.single.canonicalIngredientId, 'egg');
    expect(items.single.quantity, 2);
  });
}

final CanonicalIngredientRegistry _registry = CanonicalIngredientRegistry(
  ingredients: <CanonicalIngredient>[
    CanonicalIngredient(
      id: 'egg',
      canonicalName: 'Egg',
      localizedNames: const <String, String>{'th': 'ไข่'},
      aliases: const <String>[],
      searchKeywords: const <String>[],
      category: 'protein',
      defaultStorageType: IngredientStorageType.refrigerated,
      defaultPurchaseUnitId: 'piece',
      defaultInventoryUnitId: 'piece',
    ),
  ],
);

final ShoppingRecommendation _recommendation = ShoppingRecommendation(
  canonicalIngredientId: 'egg',
  displayName: 'ไข่',
  emoji: '🥚',
  recommendedQuantity: 2,
  targetShoppingQuantity: 2,
  existingShoppingQuantity: 0,
  recommendedUnitId: 'piece',
  score: 1000,
  evidence: RecommendationEvidence(
    impactedRecipeCount: 1,
    recipesUnlocked: 1,
    averageReadinessBefore: 0,
    averageReadinessAfter: 1,
    averageReadinessIncrease: 1,
    totalReadinessIncrease: 1,
    primaryRecipeCount: 1,
    secondaryRecipeCount: 0,
    ingredientFrequency: 1,
    reasonCodes: const <RecommendationReasonCode>[],
  ),
  topRecipes: const <RecommendationRecipeImpact>[
    RecommendationRecipeImpact(
      recipeId: 'omelette',
      recipeName: 'Omelette',
      readinessBefore: 0,
      readinessAfter: 1,
      readinessIncrease: 1,
      becomesUnlocked: true,
      ingredientRole: RecipeIngredientRole.primary,
      shortageQuantity: 2,
      shortageUnitId: 'piece',
    ),
  ],
);

class _MemoryShoppingRepository implements ShoppingRepository {
  List<ShoppingList> lists = <ShoppingList>[];

  @override
  Future<ShoppingList?> getList(String id) async {
    for (final list in lists) {
      if (list.id == id) {
        return list;
      }
    }
    return null;
  }

  @override
  Future<List<ShoppingList>> getLists() async => List<ShoppingList>.of(lists);

  @override
  Future<List<PurchaseHistoryEntry>> getPurchaseHistory() async =>
      const <PurchaseHistoryEntry>[];
}
