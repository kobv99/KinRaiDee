import '../../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../../../../core/domain/units/unit_contract.dart';
import '../../../../core/models/ingredient.dart' as pantry_model;
import '../entities/recipe.dart';
import '../entities/recipe_ingredient.dart';
import '../entities/recipe_readiness.dart';

class RecipeReadinessWeightPolicy {
  const RecipeReadinessWeightPolicy({
    this.mainWeight = 5,
    this.requiredWeight = 2,
    this.optionalWeight = 0.5,
    this.garnishWeight = 0.25,
  }) : assert(mainWeight > 0),
       assert(requiredWeight > 0),
       assert(optionalWeight > 0),
       assert(garnishWeight > 0);

  final double mainWeight;
  final double requiredWeight;
  final double optionalWeight;
  final double garnishWeight;

  double weightFor({
    required Recipe recipe,
    required RecipeIngredient ingredient,
    required String? canonicalIngredientId,
    required String? heroCanonicalIngredientId,
  }) {
    final explicit = ingredient.readinessWeight;
    if (explicit != null) {
      return explicit;
    }
    switch (ingredient.importance) {
      case RecipeIngredientImportance.main:
        return mainWeight;
      case RecipeIngredientImportance.supporting:
        return requiredWeight;
      case RecipeIngredientImportance.garnish:
        return garnishWeight;
      case null:
        break;
    }
    if (canonicalIngredientId != null &&
        canonicalIngredientId == heroCanonicalIngredientId) {
      return mainWeight;
    }
    return ingredient.required ? requiredWeight : optionalWeight;
  }
}

class RecipeReadinessService {
  const RecipeReadinessService({
    required this.registry,
    required this.unitEngine,
    this.weightPolicy = const RecipeReadinessWeightPolicy(),
  });

  final CanonicalIngredientRegistry registry;
  final UnitConversionEngine unitEngine;
  final RecipeReadinessWeightPolicy weightPolicy;

  RecipeReadiness evaluate({
    required Recipe recipe,
    required List<pantry_model.Ingredient> pantry,
    required int servings,
    required DateTime evaluatedAt,
  }) {
    if (servings <= 0) {
      throw ArgumentError.value(servings, 'servings', 'must be greater than 0');
    }
    final baseServings = recipe.servings > 0 ? recipe.servings : 1;
    final scale = servings / baseServings;
    final heroCanonicalId = _resolveHeroCanonicalId(recipe);
    final availablePantry = pantry
        .where(
          (item) => item.quantity > 0 && !item.isExpiredAt(evaluatedAt),
        )
        .toList(growable: false);
    final evaluations = <RecipeIngredientReadiness>[];
    var earnedWeight = 0.0;
    var totalWeight = 0.0;

    for (final ingredient in recipe.ingredients) {
      final canonicalId = _resolveRecipeCanonicalId(ingredient);
      final weight = weightPolicy.weightFor(
        recipe: recipe,
        ingredient: ingredient,
        canonicalIngredientId: canonicalId,
        heroCanonicalIngredientId: heroCanonicalId,
      );
      final evaluation = _evaluateIngredient(
        ingredient: ingredient,
        canonicalId: canonicalId,
        requiredQuantity: ingredient.quantity * scale,
        pantry: availablePantry,
        weight: weight,
      );
      evaluations.add(evaluation);
      totalWeight += weight;
      earnedWeight += weight * evaluation.availabilityRatio;
    }

    final score = totalWeight == 0 ? 1.0 : earnedWeight / totalWeight;
    return RecipeReadiness(
      recipe: recipe,
      servings: servings,
      score: score.clamp(0, 1).toDouble(),
      ingredients: List<RecipeIngredientReadiness>.unmodifiable(evaluations),
    );
  }

  List<RecipeReadiness> evaluateAll({
    required List<Recipe> recipes,
    required List<pantry_model.Ingredient> pantry,
    required DateTime evaluatedAt,
  }) {
    return List<RecipeReadiness>.unmodifiable(
      recipes.map(
        (recipe) => evaluate(
          recipe: recipe,
          pantry: pantry,
          servings: recipe.servings > 0 ? recipe.servings : 1,
          evaluatedAt: evaluatedAt,
        ),
      ),
    );
  }

  RecipeIngredientReadiness _evaluateIngredient({
    required RecipeIngredient ingredient,
    required String? canonicalId,
    required double requiredQuantity,
    required List<pantry_model.Ingredient> pantry,
    required double weight,
  }) {
    if (!requiredQuantity.isFinite || requiredQuantity < 0) {
      return _result(
        ingredient: ingredient,
        canonicalId: canonicalId ?? '',
        requiredQuantity: requiredQuantity,
        availableQuantity: 0,
        ratio: 0,
        weight: weight,
        status: RecipeIngredientReadinessStatus.invalidQuantity,
      );
    }
    if (canonicalId == null) {
      return _result(
        ingredient: ingredient,
        canonicalId: '',
        requiredQuantity: requiredQuantity,
        availableQuantity: 0,
        ratio: 0,
        weight: weight,
        status: RecipeIngredientReadinessStatus.unresolvedIngredient,
      );
    }
    if (requiredQuantity <= unitEngine.precisionPolicy.zeroTolerance) {
      return _result(
        ingredient: ingredient,
        canonicalId: canonicalId,
        requiredQuantity: requiredQuantity,
        availableQuantity: 0,
        ratio: 1,
        weight: weight,
        status: RecipeIngredientReadinessStatus.available,
      );
    }

    final targetUnitId = unitEngine.resolveUnitId(ingredient.unit);
    final matching = pantry
        .where((item) => _pantryMatchesCanonical(item, canonicalId))
        .toList(growable: false);
    if (matching.isEmpty) {
      return _result(
        ingredient: ingredient,
        canonicalId: canonicalId,
        requiredQuantity: requiredQuantity,
        availableQuantity: 0,
        ratio: 0,
        weight: weight,
        status: RecipeIngredientReadinessStatus.missing,
      );
    }
    if (targetUnitId == null) {
      return _result(
        ingredient: ingredient,
        canonicalId: canonicalId,
        requiredQuantity: requiredQuantity,
        availableQuantity: 0,
        ratio: 0,
        weight: weight,
        status: RecipeIngredientReadinessStatus.incompatibleUnit,
      );
    }

    var availableQuantity = 0.0;
    var hasCompatibleQuantity = false;
    for (final item in matching) {
      final sourceUnitId = unitEngine.resolveUnitId(
        item.canonicalUnitId.trim().isEmpty
            ? item.unit
            : item.canonicalUnitId,
      );
      if (sourceUnitId == null) {
        continue;
      }
      final converted = unitEngine.tryConvert(
        item.quantity,
        fromUnit: sourceUnitId,
        toUnit: targetUnitId,
      );
      if (!converted.isSuccess) {
        continue;
      }
      availableQuantity += converted.value!;
      hasCompatibleQuantity = true;
    }
    if (!hasCompatibleQuantity) {
      return _result(
        ingredient: ingredient,
        canonicalId: canonicalId,
        requiredQuantity: requiredQuantity,
        availableQuantity: 0,
        ratio: 0,
        weight: weight,
        status: RecipeIngredientReadinessStatus.incompatibleUnit,
      );
    }

    final ratio = (availableQuantity / requiredQuantity).clamp(0, 1).toDouble();
    final status = ratio >= 1 - unitEngine.precisionPolicy.zeroTolerance
        ? RecipeIngredientReadinessStatus.available
        : availableQuantity > unitEngine.precisionPolicy.zeroTolerance
        ? RecipeIngredientReadinessStatus.insufficient
        : RecipeIngredientReadinessStatus.missing;
    return _result(
      ingredient: ingredient,
      canonicalId: canonicalId,
      requiredQuantity: requiredQuantity,
      availableQuantity: availableQuantity,
      ratio: ratio,
      weight: weight,
      status: status,
    );
  }

  RecipeIngredientReadiness _result({
    required RecipeIngredient ingredient,
    required String canonicalId,
    required double requiredQuantity,
    required double availableQuantity,
    required double ratio,
    required double weight,
    required RecipeIngredientReadinessStatus status,
  }) {
    final shortage = requiredQuantity.isFinite
        ? requiredQuantity - availableQuantity
        : 0.0;
    return RecipeIngredientReadiness(
      ingredient: ingredient,
      canonicalIngredientId: canonicalId,
      requiredQuantity: requiredQuantity,
      availableQuantity: availableQuantity,
      shortageQuantity: shortage > 0 ? shortage : 0,
      availabilityRatio: ratio,
      weight: weight,
      status: status,
    );
  }

  String? _resolveHeroCanonicalId(Recipe recipe) {
    final hero = recipe.heroIngredient;
    return hero == null ? null : _resolveRecipeCanonicalId(hero);
  }

  String? _resolveRecipeCanonicalId(RecipeIngredient ingredient) {
    final direct = registry.canonicalIdFor(ingredient.canonicalIngredientId);
    if (direct != null) {
      return direct;
    }
    final byIdOrKey = registry
        .resolve(
          ingredient.canonicalIngredientId,
          preferredId: ingredient.canonicalIngredientId,
        )
        .ingredient
        ?.id;
    if (byIdOrKey != null) {
      return byIdOrKey;
    }
    final byName = registry.resolve(ingredient.name).ingredient?.id;
    if (byName != null) {
      return byName;
    }
    for (final alias in ingredient.aliases) {
      final resolved = registry.resolve(alias).ingredient?.id;
      if (resolved != null) {
        return resolved;
      }
    }
    return null;
  }

  bool _pantryMatchesCanonical(
    pantry_model.Ingredient item,
    String recipeCanonicalId,
  ) {
    final rawId = item.canonicalIngredientId.trim();
    final pantryCanonicalId = rawId.isNotEmpty
        ? registry.canonicalIdFor(rawId)
        : registry.resolve(item.name).ingredient?.id;
    return pantryCanonicalId != null &&
        registry.areCompatibleIds(pantryCanonicalId, recipeCanonicalId);
  }
}
