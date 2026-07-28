import '../../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../../../../core/domain/units/unit_contract.dart';
import '../../../../core/models/ingredient.dart';
import '../../../recipe/domain/entities/recipe.dart';
import '../../../recipe/domain/entities/recipe_ingredient.dart';
import '../../../recipe/domain/entities/recipe_readiness.dart';
import '../../../recipe/domain/services/recipe_readiness_service.dart';
import '../entities/shopping_item.dart';
import '../entities/shopping_item_status.dart';
import '../entities/shopping_list.dart';
import '../entities/shopping_recommendation.dart';
import 'recommendation_explanation_builder.dart';
import 'recommendation_score_calculator.dart';

class ShoppingRecommendationPolicy {
  const ShoppingRecommendationPolicy({
    this.unlocksManyRecipesThreshold = 2,
    this.highRecipeFrequencyThreshold = 3,
    this.primaryIngredientThreshold = 2,
    this.nearlyReadyThreshold = 0.7,
    this.highAverageReadinessIncreaseThreshold = 0.15,
    this.topRecipeLimit = 4,
  }) : assert(unlocksManyRecipesThreshold > 0),
       assert(highRecipeFrequencyThreshold > 0),
       assert(primaryIngredientThreshold > 0),
       assert(nearlyReadyThreshold >= 0 && nearlyReadyThreshold <= 1),
       assert(
         highAverageReadinessIncreaseThreshold >= 0 &&
             highAverageReadinessIncreaseThreshold <= 1,
       ),
       assert(topRecipeLimit > 0);

  final int unlocksManyRecipesThreshold;
  final int highRecipeFrequencyThreshold;
  final int primaryIngredientThreshold;
  final double nearlyReadyThreshold;
  final double highAverageReadinessIncreaseThreshold;
  final int topRecipeLimit;
}

class ShoppingRecommendationService {
  const ShoppingRecommendationService({
    required this.readinessService,
    required this.registry,
    required this.unitEngine,
    this.policy = const ShoppingRecommendationPolicy(),
    this.scoreCalculator = const RecommendationScoreCalculator(),
    this.explanationBuilder = const RecommendationExplanationBuilder(),
  });

  final RecipeReadinessService readinessService;
  final CanonicalIngredientRegistry registry;
  final UnitConversionEngine unitEngine;
  final ShoppingRecommendationPolicy policy;
  final RecommendationScoreCalculator scoreCalculator;
  final RecommendationExplanationBuilder explanationBuilder;

  List<ShoppingRecommendation> recommend({
    required List<Recipe> recipes,
    required List<Ingredient> pantry,
    required List<ShoppingList> shoppingLists,
    required DateTime evaluatedAt,
  }) {
    final at = evaluatedAt.toUtc();
    final orderedRecipes = List<Recipe>.of(recipes)
      ..sort((first, second) => first.id.compareTo(second.id));
    final readiness = readinessService.evaluateAll(
      recipes: orderedRecipes,
      pantry: pantry,
      evaluatedAt: at,
    );
    final candidates = <_IngredientCandidate>[];

    for (final recipeReadiness in readiness) {
      final hero = recipeReadiness.recipe.heroIngredient;
      for (final ingredientReadiness in recipeReadiness.ingredients) {
        final role = ingredientReadiness.ingredient.effectiveRole(
          isHero: hero != null && hero.id == ingredientReadiness.ingredient.id,
        );
        if (role == RecipeIngredientRole.optional ||
            !ingredientReadiness.needsShopping ||
            ingredientReadiness.shortageQuantity <=
                unitEngine.precisionPolicy.zeroTolerance) {
          continue;
        }
        final canonicalId = ingredientReadiness.canonicalIngredientId;
        if (canonicalId.isEmpty || registry.byId(canonicalId) == null) {
          continue;
        }

        _IngredientCandidate? candidate;
        for (final existing in candidates) {
          if (registry.areCompatibleIds(existing.canonicalId, canonicalId)) {
            candidate = existing;
            break;
          }
        }
        candidate ??= _IngredientCandidate(canonicalId);
        if (!candidates.contains(candidate)) {
          candidates.add(candidate);
        }
        candidate.canonicalId = _preferredFamilyId(
          candidate.canonicalId,
          canonicalId,
        );
        candidate.entries.add(
          _CandidateEntry(
            readiness: recipeReadiness,
            ingredient: ingredientReadiness,
            role: role,
          ),
        );
      }
    }

    final activeItems = <ShoppingItem>[
      for (final list in shoppingLists)
        ...list.items.where((item) => item.status == ShoppingItemStatus.active),
    ];
    final recommendations = <ShoppingRecommendation>[];
    for (final candidate in candidates) {
      final recommendation = _buildRecommendation(
        candidate: candidate,
        pantry: pantry,
        activeItems: activeItems,
        evaluatedAt: at,
      );
      if (recommendation != null) {
        recommendations.add(recommendation);
      }
    }

    recommendations.sort(_compareRecommendations);
    return List<ShoppingRecommendation>.unmodifiable(recommendations);
  }

  ShoppingRecommendation? _buildRecommendation({
    required _IngredientCandidate candidate,
    required List<Ingredient> pantry,
    required List<ShoppingItem> activeItems,
    required DateTime evaluatedAt,
  }) {
    final canonical = registry.byId(candidate.canonicalId);
    if (canonical == null) {
      return null;
    }
    final purchaseUnitId = unitEngine.resolveUnitId(
      canonical.defaultPurchaseUnitId,
    );
    if (purchaseUnitId == null) {
      return null;
    }

    final recipeAggregates = <String, _RecipeCandidateAggregate>{};
    for (final entry in candidate.entries) {
      final converted = unitEngine.tryConvert(
        entry.ingredient.shortageQuantity,
        fromUnit: entry.ingredient.ingredient.unit,
        toUnit: purchaseUnitId,
      );
      if (!converted.isSuccess ||
          converted.value! <= unitEngine.precisionPolicy.zeroTolerance) {
        continue;
      }
      final aggregate = recipeAggregates.putIfAbsent(
        entry.readiness.recipe.id,
        () => _RecipeCandidateAggregate(
          readiness: entry.readiness,
          role: entry.role,
        ),
      );
      aggregate.shortageQuantity += converted.value!;
      if (entry.role == RecipeIngredientRole.primary) {
        aggregate.role = RecipeIngredientRole.primary;
      }
    }
    if (recipeAggregates.isEmpty) {
      return null;
    }

    var targetShoppingQuantity = 0.0;
    for (final aggregate in recipeAggregates.values) {
      final rounded = _round(aggregate.shortageQuantity, purchaseUnitId);
      aggregate.shortageQuantity = rounded;
      if (rounded > targetShoppingQuantity) {
        targetShoppingQuantity = rounded;
      }
    }
    if (targetShoppingQuantity <= unitEngine.precisionPolicy.zeroTolerance) {
      return null;
    }

    final existingShoppingQuantity = _activeShoppingCoverage(
      activeItems,
      canonicalId: candidate.canonicalId,
      targetUnitId: purchaseUnitId,
    );
    final recommendedQuantity = _round(
      _positive(targetShoppingQuantity - existingShoppingQuantity),
      purchaseUnitId,
    );
    if (recommendedQuantity <= unitEngine.precisionPolicy.zeroTolerance) {
      return null;
    }

    final simulatedPantry = <Ingredient>[
      ...pantry,
      Ingredient(
        id: 'shopping-recommendation-simulation::${candidate.canonicalId}',
        name: canonical.displayName(),
        category: canonical.category,
        emoji: canonical.emoji,
        quantity: targetShoppingQuantity,
        unit: purchaseUnitId,
        createdAt: evaluatedAt,
        updatedAt: evaluatedAt,
        canonicalIngredientId: candidate.canonicalId,
        canonicalUnitId: purchaseUnitId,
        canonicalMappingStatus: CanonicalMappingStatus.mapped,
      ),
    ];

    final impacts = <RecommendationRecipeImpact>[];
    for (final aggregate in recipeAggregates.values) {
      final before = aggregate.readiness;
      final after = readinessService.evaluate(
        recipe: before.recipe,
        pantry: simulatedPantry,
        servings: before.servings,
        evaluatedAt: evaluatedAt,
      );
      final increase = _positive(after.score - before.score);
      final becomesUnlocked = !before.canCook && after.canCook;
      if (!becomesUnlocked &&
          increase <= unitEngine.precisionPolicy.zeroTolerance) {
        continue;
      }
      impacts.add(
        RecommendationRecipeImpact(
          recipeId: before.recipe.id,
          recipeName: before.recipe.name,
          readinessBefore: before.score,
          readinessAfter: after.score,
          readinessIncrease: increase,
          becomesUnlocked: becomesUnlocked,
          ingredientRole: aggregate.role,
          shortageQuantity: aggregate.shortageQuantity,
          shortageUnitId: purchaseUnitId,
        ),
      );
    }
    if (impacts.isEmpty) {
      return null;
    }

    impacts.sort(_compareRecipeImpacts);
    final recipesUnlocked = impacts
        .where((impact) => impact.becomesUnlocked)
        .length;
    final totalReadinessIncrease = impacts.fold<double>(
      0,
      (total, impact) => total + impact.readinessIncrease,
    );
    final averageBefore =
        impacts.fold<double>(
          0,
          (total, impact) => total + impact.readinessBefore,
        ) /
        impacts.length;
    final averageAfter =
        impacts.fold<double>(
          0,
          (total, impact) => total + impact.readinessAfter,
        ) /
        impacts.length;
    final primaryCount = impacts
        .where(
          (impact) => impact.ingredientRole == RecipeIngredientRole.primary,
        )
        .length;
    final secondaryCount = impacts.length - primaryCount;
    final hasPartialPantry = _hasPartialPantryCoverage(
      pantry,
      canonicalId: candidate.canonicalId,
      targetUnitId: purchaseUnitId,
      evaluatedAt: evaluatedAt,
    );
    final almostReadyRecipeCount = impacts
        .where(
          (impact) =>
              impact.becomesUnlocked &&
              impact.readinessBefore >= policy.nearlyReadyThreshold,
        )
        .length;
    final reasonCodes = _reasonCodes(
      impacts: impacts,
      recipesUnlocked: recipesUnlocked,
      averageReadinessIncrease: averageAfter - averageBefore,
      primaryRecipeCount: primaryCount,
      ingredientFrequency: recipeAggregates.length,
      hasPartialPantry: hasPartialPantry,
    );
    final evidence = RecommendationEvidence(
      impactedRecipeCount: impacts.length,
      recipesUnlocked: recipesUnlocked,
      averageReadinessBefore: averageBefore,
      averageReadinessAfter: averageAfter,
      averageReadinessIncrease: averageAfter - averageBefore,
      totalReadinessIncrease: totalReadinessIncrease,
      primaryRecipeCount: primaryCount,
      secondaryRecipeCount: secondaryCount,
      ingredientFrequency: recipeAggregates.length,
      almostReadyRecipeCount: almostReadyRecipeCount,
      hasPantrySynergy: hasPartialPantry,
      reasonCodes: reasonCodes,
    );
    final explanation = explanationBuilder.build(
      ingredientName: canonical.displayName(),
      evidence: evidence,
      impacts: impacts,
    );

    return ShoppingRecommendation(
      canonicalIngredientId: candidate.canonicalId,
      displayName: canonical.displayName(),
      emoji: canonical.emoji,
      recommendedQuantity: recommendedQuantity,
      targetShoppingQuantity: targetShoppingQuantity,
      existingShoppingQuantity: existingShoppingQuantity,
      recommendedUnitId: purchaseUnitId,
      score: scoreCalculator.calculate(evidence),
      evidence: evidence,
      topRecipes: impacts.take(policy.topRecipeLimit).toList(growable: false),
      types: explanation.types,
      reason: explanation.reason,
    );
  }

  List<RecommendationReasonCode> _reasonCodes({
    required List<RecommendationRecipeImpact> impacts,
    required int recipesUnlocked,
    required double averageReadinessIncrease,
    required int primaryRecipeCount,
    required int ingredientFrequency,
    required bool hasPartialPantry,
  }) {
    final reasons = <RecommendationReasonCode>[];
    if (recipesUnlocked >= policy.unlocksManyRecipesThreshold) {
      reasons.add(RecommendationReasonCode.unlocksManyRecipes);
    }
    if (ingredientFrequency >= policy.highRecipeFrequencyThreshold) {
      reasons.add(RecommendationReasonCode.highRecipeFrequency);
    }
    if (primaryRecipeCount >= policy.primaryIngredientThreshold) {
      reasons.add(RecommendationReasonCode.primaryIngredientInManyRecipes);
    }
    if (impacts.any(
      (impact) =>
          impact.becomesUnlocked &&
          impact.readinessBefore >= policy.nearlyReadyThreshold,
    )) {
      reasons.add(RecommendationReasonCode.improvesNearlyReadyRecipes);
    }
    if (averageReadinessIncrease >=
        policy.highAverageReadinessIncreaseThreshold) {
      reasons.add(RecommendationReasonCode.highAverageReadinessIncrease);
    }
    if (hasPartialPantry) {
      reasons.add(RecommendationReasonCode.alreadyPartiallyAvailable);
    }
    return List<RecommendationReasonCode>.unmodifiable(reasons);
  }

  double _activeShoppingCoverage(
    List<ShoppingItem> activeItems, {
    required String canonicalId,
    required String targetUnitId,
  }) {
    var total = 0.0;
    for (final item in activeItems) {
      if (!registry.areCompatibleIds(item.canonicalIngredientId, canonicalId)) {
        continue;
      }
      final converted = unitEngine.tryConvert(
        item.quantity,
        fromUnit: item.unitId,
        toUnit: targetUnitId,
      );
      if (converted.isSuccess) {
        total += converted.value!;
      }
    }
    return _round(total, targetUnitId);
  }

  bool _hasPartialPantryCoverage(
    List<Ingredient> pantry, {
    required String canonicalId,
    required String targetUnitId,
    required DateTime evaluatedAt,
  }) {
    for (final item in pantry) {
      if (item.quantity <= 0 || item.isExpiredAt(evaluatedAt)) {
        continue;
      }
      final pantryId = registry.canonicalIdFor(item.canonicalIngredientId);
      if (pantryId == null ||
          !registry.areCompatibleIds(pantryId, canonicalId)) {
        continue;
      }
      final sourceUnit = item.canonicalUnitId.trim().isEmpty
          ? item.unit
          : item.canonicalUnitId;
      final converted = unitEngine.tryConvert(
        item.quantity,
        fromUnit: sourceUnit,
        toUnit: targetUnitId,
      );
      if (converted.isSuccess &&
          converted.value! > unitEngine.precisionPolicy.zeroTolerance) {
        return true;
      }
    }
    return false;
  }

  String _preferredFamilyId(String firstId, String secondId) {
    if (firstId == secondId) {
      return firstId;
    }
    if (_isAncestor(firstId, secondId)) {
      return firstId;
    }
    if (_isAncestor(secondId, firstId)) {
      return secondId;
    }
    return firstId.compareTo(secondId) <= 0 ? firstId : secondId;
  }

  bool _isAncestor(String ancestorId, String descendantId) {
    var current = registry.byId(descendantId);
    while (current?.parentId != null) {
      final parentId = registry.canonicalIdFor(current!.parentId!);
      if (parentId == null) {
        return false;
      }
      if (parentId == ancestorId) {
        return true;
      }
      current = registry.byId(parentId);
    }
    return false;
  }

  double _round(double value, String unitId) {
    return unitEngine.precisionPolicy.apply(
      value,
      decimalPlaces: unitEngine.resolveUnit(unitId)?.decimalPlaces,
    );
  }

  int _compareRecommendations(
    ShoppingRecommendation first,
    ShoppingRecommendation second,
  ) {
    final score = second.score.compareTo(first.score);
    if (score != 0) {
      return score;
    }
    final unlocked = second.evidence.recipesUnlocked.compareTo(
      first.evidence.recipesUnlocked,
    );
    if (unlocked != 0) {
      return unlocked;
    }
    final readiness = second.evidence.averageReadinessIncrease.compareTo(
      first.evidence.averageReadinessIncrease,
    );
    if (readiness != 0) {
      return readiness;
    }
    return first.canonicalIngredientId.compareTo(second.canonicalIngredientId);
  }

  int _compareRecipeImpacts(
    RecommendationRecipeImpact first,
    RecommendationRecipeImpact second,
  ) {
    if (first.becomesUnlocked != second.becomesUnlocked) {
      return first.becomesUnlocked ? -1 : 1;
    }
    final increase = second.readinessIncrease.compareTo(
      first.readinessIncrease,
    );
    if (increase != 0) {
      return increase;
    }
    return first.recipeId.compareTo(second.recipeId);
  }
}

class _IngredientCandidate {
  _IngredientCandidate(this.canonicalId);

  String canonicalId;
  final List<_CandidateEntry> entries = <_CandidateEntry>[];
}

class _CandidateEntry {
  const _CandidateEntry({
    required this.readiness,
    required this.ingredient,
    required this.role,
  });

  final RecipeReadiness readiness;
  final RecipeIngredientReadiness ingredient;
  final RecipeIngredientRole role;
}

class _RecipeCandidateAggregate {
  _RecipeCandidateAggregate({required this.readiness, required this.role});

  final RecipeReadiness readiness;
  RecipeIngredientRole role;
  double shortageQuantity = 0;
}

double _positive(double value) => value > 0 ? value : 0;
