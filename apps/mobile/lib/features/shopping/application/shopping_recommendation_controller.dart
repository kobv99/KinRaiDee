import '../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../../../core/domain/units/unit_contract.dart';
import '../../../core/time/app_clock.dart';
import '../../pantry/application/inventory_transaction_coordinator.dart';
import '../domain/entities/shopping_item.dart';
import '../domain/entities/shopping_item_status.dart';
import '../domain/entities/shopping_list.dart';
import '../domain/entities/shopping_recommendation.dart';
import '../domain/entities/shopping_source.dart';
import '../domain/models/shopping_mutation.dart';
import '../domain/repositories/shopping_repository.dart';
import '../domain/services/shopping_draft_builder.dart';

typedef ShoppingRecommendationMutationExecutor =
    Future<InventoryTransactionResult> Function(ShoppingMutation mutation);

enum ShoppingRecommendationAddOutcome { added, updated, unchanged, failed }

class ShoppingRecommendationAddResult {
  const ShoppingRecommendationAddResult({
    required this.outcome,
    this.transactionResult,
    this.code = '',
  });

  final ShoppingRecommendationAddOutcome outcome;
  final InventoryTransactionResult? transactionResult;
  final String code;

  bool get isSuccess =>
      outcome == ShoppingRecommendationAddOutcome.added ||
      outcome == ShoppingRecommendationAddOutcome.updated ||
      outcome == ShoppingRecommendationAddOutcome.unchanged;
}

class ShoppingRecommendationController {
  const ShoppingRecommendationController({
    required this.repository,
    required this.registry,
    required this.unitEngine,
    required this.executeMutation,
    required this.clock,
  });

  final ShoppingRepository repository;
  final CanonicalIngredientRegistry registry;
  final UnitConversionEngine unitEngine;
  final ShoppingRecommendationMutationExecutor executeMutation;
  final AppClock clock;

  Future<ShoppingRecommendationAddResult> addToShopping(
    ShoppingRecommendation recommendation,
  ) async {
    final createdAt = clock.now().toUtc();
    final lists = await repository.getLists();
    final current = lists.firstOrNull;
    final listId = current?.id ?? 'primary-shopping-list';
    final listName = current?.name ?? 'รายการซื้อของของฉัน';
    final activeCompatible = <ShoppingItem>[
      for (final item in current?.items ?? const <ShoppingItem>[])
        if (item.status == ShoppingItemStatus.active &&
            registry.areCompatibleIds(
              item.canonicalIngredientId,
              recommendation.canonicalIngredientId,
            ))
          item,
    ]..sort((first, second) => first.id.compareTo(second.id));

    final currentCoverage = _coverage(
      activeCompatible,
      recommendation.recommendedUnitId,
    );
    final target = recommendation.targetShoppingQuantity;
    if (currentCoverage >= target - unitEngine.precisionPolicy.zeroTolerance) {
      return const ShoppingRecommendationAddResult(
        outcome: ShoppingRecommendationAddOutcome.unchanged,
      );
    }

    final additional = unitEngine.precisionPolicy.apply(
      target - currentCoverage,
      decimalPlaces:
          unitEngine.resolveUnit(recommendation.recommendedUnitId)?.decimalPlaces,
    );
    if (additional <= unitEngine.precisionPolicy.zeroTolerance) {
      return const ShoppingRecommendationAddResult(
        outcome: ShoppingRecommendationAddOutcome.unchanged,
      );
    }

    final marker =
        'shopping-recommendation::${recommendation.canonicalIngredientId}';
    late final ShoppingList updatedList;
    late final ShoppingRecommendationAddOutcome successOutcome;
    if (activeCompatible.isEmpty) {
      final item = ShoppingItemFactory(
        registry: registry,
        unitEngine: unitEngine,
      ).create(
        id:
            '$listId::recommendation::${recommendation.canonicalIngredientId}::${recommendation.recommendedUnitId}',
        canonicalIngredientId: recommendation.canonicalIngredientId,
        quantity: target,
        unit: recommendation.recommendedUnitId,
        source: ShoppingSource.pantryShortage,
        sourceReferenceId: marker,
        createdAt: createdAt,
      );
      updatedList = current?.copyWith(
            items: <ShoppingItem>[...current.items, item],
            updatedAt: createdAt,
          ) ??
          ShoppingList(
            id: listId,
            name: listName,
            items: <ShoppingItem>[item],
            createdAt: createdAt,
            updatedAt: createdAt,
          );
      successOutcome = ShoppingRecommendationAddOutcome.added;
    } else {
      final survivor = activeCompatible.first;
      final converted = unitEngine.tryConvert(
        additional,
        fromUnit: recommendation.recommendedUnitId,
        toUnit: survivor.unitId,
      );
      if (!converted.isSuccess) {
        return const ShoppingRecommendationAddResult(
          outcome: ShoppingRecommendationAddOutcome.failed,
          code: 'recommendation_unit_conversion_failed',
        );
      }
      final references = <String>{
        ...survivor.sourceReferenceIds,
        marker,
      }.toList()
        ..sort();
      final updatedItem = survivor.copyWith(
        quantity: survivor.quantity + converted.value!,
        sourceReferenceIds: references,
        updatedAt: createdAt,
      );
      updatedList = current!.copyWith(
        items: <ShoppingItem>[
          for (final item in current.items)
            if (item.id == survivor.id) updatedItem else item,
        ],
        updatedAt: createdAt,
      );
      successOutcome = ShoppingRecommendationAddOutcome.updated;
    }

    InventoryTransactionResult transactionResult;
    try {
      transactionResult = await executeMutation(
        ShoppingMutation.upsert(list: updatedList, createdAt: createdAt),
      );
    } on Object {
      return const ShoppingRecommendationAddResult(
        outcome: ShoppingRecommendationAddOutcome.failed,
        code: 'recommendation_transaction_exception',
      );
    }
    if (!transactionResult.isSuccess) {
      return ShoppingRecommendationAddResult(
        outcome: ShoppingRecommendationAddOutcome.failed,
        transactionResult: transactionResult,
        code: transactionResult.code,
      );
    }
    return ShoppingRecommendationAddResult(
      outcome: successOutcome,
      transactionResult: transactionResult,
    );
  }

  double _coverage(List<ShoppingItem> items, String targetUnitId) {
    var total = 0.0;
    for (final item in items) {
      final converted = unitEngine.tryConvert(
        item.quantity,
        fromUnit: item.unitId,
        toUnit: targetUnitId,
      );
      if (converted.isSuccess) {
        total += converted.value!;
      }
    }
    return unitEngine.precisionPolicy.apply(
      total,
      decimalPlaces: unitEngine.resolveUnit(targetUnitId)?.decimalPlaces,
    );
  }
}
