import '../../../../core/models/ingredient.dart';
import '../../../pantry/domain/models/cooking_history_entry.dart';
import '../entities/recipe_match.dart';
import '../entities/recipe_recommendation.dart';

class RecommendationWeights {
  const RecommendationWeights({
    this.recipeMatch = 0.55,
    this.fewMissing = 0.15,
    this.expiringIngredients = 0.12,
    this.quickMeal = 0.08,
    this.lowComplexity = 0.05,
    this.favorite = 0.03,
    this.notRecentlyCooked = 0.02,
  }) : assert(recipeMatch >= 0),
       assert(fewMissing >= 0),
       assert(expiringIngredients >= 0),
       assert(quickMeal >= 0),
       assert(lowComplexity >= 0),
       assert(favorite >= 0),
       assert(notRecentlyCooked >= 0);

  final double recipeMatch;
  final double fewMissing;
  final double expiringIngredients;
  final double quickMeal;
  final double lowComplexity;
  final double favorite;
  final double notRecentlyCooked;

  double get total =>
      recipeMatch +
      fewMissing +
      expiringIngredients +
      quickMeal +
      lowComplexity +
      favorite +
      notRecentlyCooked;
}

class RecommendationConfiguration {
  const RecommendationConfiguration({
    this.weights = const RecommendationWeights(),
    this.expiringWithinDays = 3,
    this.quickMealMinutes = 30,
    this.complexRecipeIngredientCount = 12,
    this.recentlyCookedWithinDays = 7,
    this.pantryFriendlyMatchPercent = 75,
    this.fewMissingThreshold = 2,
    this.healthyTags = const <String>{'healthy', 'สุขภาพ'},
  });

  final RecommendationWeights weights;
  final int expiringWithinDays;
  final int quickMealMinutes;
  final int complexRecipeIngredientCount;
  final int recentlyCookedWithinDays;
  final int pantryFriendlyMatchPercent;
  final int fewMissingThreshold;
  final Set<String> healthyTags;
}

class RecipeRecommendationEngine {
  const RecipeRecommendationEngine({
    this.configuration = const RecommendationConfiguration(),
  });

  final RecommendationConfiguration configuration;

  List<RecipeRecommendation> evaluateAll({
    required List<RecipeMatch> matches,
    required List<Ingredient> pantry,
    required DateTime evaluatedAt,
    List<CookingHistoryEntry> cookingHistory = const <CookingHistoryEntry>[],
    Set<String> favoriteRecipeIds = const <String>{},
    Map<String, Map<String, String>> availableSubstitutions =
        const <String, Map<String, String>>{},
    RecommendationFilter filter = const RecommendationFilter(),
    RecommendationSort sort = RecommendationSort.highestScore,
  }) {
    final pantryByCanonicalId = <String, List<Ingredient>>{};
    for (final item in pantry) {
      final id = item.canonicalIngredientId.trim();
      if (id.isNotEmpty &&
          item.quantity > 0 &&
          !item.isExpiredAt(evaluatedAt)) {
        pantryByCanonicalId.putIfAbsent(id, () => <Ingredient>[]).add(item);
      }
    }
    final recentRecipeIds = cookingHistory
        .where(
          (entry) =>
              !entry.isCancelled &&
              evaluatedAt.difference(entry.createdAt).inDays <=
                  configuration.recentlyCookedWithinDays,
        )
        .map((entry) => entry.recipeId)
        .toSet();

    final results = matches
        .map(
          (match) => evaluate(
            match: match,
            pantryByCanonicalId: pantryByCanonicalId,
            evaluatedAt: evaluatedAt,
            isFavorite: favoriteRecipeIds.contains(match.recipe.id),
            wasRecentlyCooked: recentRecipeIds.contains(match.recipe.id),
            availableSubstitutions:
                availableSubstitutions[match.recipe.id] ??
                const <String, String>{},
          ),
        )
        .where((item) => _matchesFilter(item, filter))
        .toList(growable: false);
    results.sort((first, second) => _compare(first, second, sort));
    return List<RecipeRecommendation>.unmodifiable(results);
  }

  RecipeRecommendation evaluate({
    required RecipeMatch match,
    required Map<String, List<Ingredient>> pantryByCanonicalId,
    required DateTime evaluatedAt,
    bool isFavorite = false,
    bool wasRecentlyCooked = false,
    Map<String, String> availableSubstitutions = const <String, String>{},
  }) {
    final recipe = match.recipe;
    final expiringIds = match.matchedIngredients
        .map((item) => item.canonicalIngredientId)
        .where(
          (id) =>
              pantryByCanonicalId[id]?.any((item) {
                final days = item.daysUntilExpiryAt(evaluatedAt);
                return days != null &&
                    days >= 0 &&
                    days <= configuration.expiringWithinDays;
              }) ==
              true,
        )
        .toSet();
    final pantryIds = pantryByCanonicalId.keys.toSet();
    final usedPantryIds = match.matchedIngredients
        .map((item) => item.canonicalIngredientId)
        .where(pantryIds.contains)
        .toSet();
    final missingFactor = recipe.ingredients.isEmpty
        ? 1.0
        : 1 -
              (match.missingRequiredCount /
                  recipe.ingredients
                      .where((item) => item.required)
                      .length
                      .clamp(1, recipe.ingredients.length));
    final expiryFactor = expiringIds.isEmpty
        ? 0.0
        : (expiringIds.length / match.matchedIngredients.length.clamp(1, 999))
              .clamp(0, 1)
              .toDouble();
    final quickFactor = recipe.cookTimeMinutes <= 0
        ? 0.5
        : (1 - recipe.cookTimeMinutes / (configuration.quickMealMinutes * 2))
              .clamp(0, 1)
              .toDouble();
    final complexityFactor =
        (1 -
                recipe.ingredients.length /
                    configuration.complexRecipeIngredientCount)
            .clamp(0, 1)
            .toDouble();

    final factors = <(String, double, double, String)>[
      (
        'recipe_match',
        match.score,
        configuration.weights.recipeMatch,
        'มีวัตถุดิบตรงกับสูตร ${match.scorePercent}%',
      ),
      (
        'few_missing',
        missingFactor,
        configuration.weights.fewMissing,
        match.missingRequiredCount == 0
            ? 'มีวัตถุดิบจำเป็นครบ'
            : 'ขาดวัตถุดิบจำเป็น ${match.missingRequiredCount} รายการ',
      ),
      (
        'expiring',
        expiryFactor,
        configuration.weights.expiringIngredients,
        expiringIds.isEmpty
            ? 'ไม่พบวัตถุดิบใกล้หมดอายุในสูตร'
            : 'ช่วยใช้วัตถุดิบใกล้หมดอายุ ${expiringIds.length} รายการ',
      ),
      (
        'quick_meal',
        quickFactor,
        configuration.weights.quickMeal,
        recipe.cookTimeMinutes > 0
            ? 'ใช้เวลาประมาณ ${recipe.cookTimeMinutes} นาที'
            : 'ยังไม่มีข้อมูลเวลาปรุง',
      ),
      (
        'complexity',
        complexityFactor,
        configuration.weights.lowComplexity,
        'สูตรใช้วัตถุดิบ ${recipe.ingredients.length} รายการ',
      ),
      (
        'favorite',
        isFavorite ? 1 : 0,
        configuration.weights.favorite,
        isFavorite ? 'เป็นเมนูโปรดของคุณ' : 'ไม่ได้เพิ่มเป็นเมนูโปรด',
      ),
      (
        'recent',
        wasRecentlyCooked ? 0 : 1,
        configuration.weights.notRecentlyCooked,
        wasRecentlyCooked
            ? 'เพิ่งทำเมนูนี้ไม่นาน'
            : 'ไม่ได้ทำเมนูนี้เมื่อเร็ว ๆ นี้',
      ),
    ];
    final weightTotal = configuration.weights.total;
    final components = factors
        .map((factor) {
          final points = weightTotal == 0
              ? 0.0
              : factor.$2 * factor.$3 / weightTotal * 100;
          return RecommendationScoreComponent(
            id: factor.$1,
            rawValue: factor.$2,
            weight: factor.$3,
            points: points,
            explanation: factor.$4,
          );
        })
        .toList(growable: false);
    final score = components.fold<double>(0, (sum, item) => sum + item.points);
    final badges = <RecommendationBadge>[
      if (match.scorePercent == 100) RecommendationBadge.perfectMatch,
      if (match.scorePercent >= configuration.pantryFriendlyMatchPercent)
        RecommendationBadge.pantryFriendly,
      if (recipe.cookTimeMinutes > 0 &&
          recipe.cookTimeMinutes <= configuration.quickMealMinutes)
        RecommendationBadge.quickMeal,
      if (match.missingRequiredCount > 0 &&
          match.missingRequiredCount <= configuration.fewMissingThreshold)
        RecommendationBadge.fewMissing,
      if (expiringIds.isNotEmpty) RecommendationBadge.usesExpiringIngredients,
      if (recipe.tags.any(configuration.healthyTags.contains))
        RecommendationBadge.healthyChoice,
    ];
    final reasons = components
        .where((item) => item.rawValue > 0)
        .map((item) => item.explanation)
        .toList(growable: false);
    return RecipeRecommendation(
      match: match,
      score: score,
      components: List<RecommendationScoreComponent>.unmodifiable(components),
      reasons: List<String>.unmodifiable(reasons),
      badges: List<RecommendationBadge>.unmodifiable(badges),
      expiringIngredientIds: List<String>.unmodifiable(expiringIds),
      availableSubstitutions: Map<String, String>.unmodifiable(
        availableSubstitutions,
      ),
      pantryIngredientCount: pantryIds.length,
      usedPantryIngredientCount: usedPantryIds.length,
    );
  }

  bool _matchesFilter(RecipeRecommendation item, RecommendationFilter filter) {
    final recipe = item.match.recipe;
    return (filter.minimumMatchPercent == null ||
            item.recipeMatchPercent >= filter.minimumMatchPercent!) &&
        (filter.maximumCookTimeMinutes == null ||
            (recipe.cookTimeMinutes > 0 &&
                recipe.cookTimeMinutes <= filter.maximumCookTimeMinutes!)) &&
        (filter.difficulty == null || recipe.difficulty == filter.difficulty) &&
        (filter.cuisine == null || recipe.category == filter.cuisine) &&
        (filter.mainIngredientId == null ||
            recipe.resolvedHeroIngredientId == filter.mainIngredientId) &&
        (filter.mealType == null || recipe.tags.contains(filter.mealType)) &&
        (filter.maximumMissingIngredients == null ||
            item.missingIngredientCount <= filter.maximumMissingIngredients!) &&
        (!filter.pantryFriendlyOnly ||
            item.badges.contains(RecommendationBadge.pantryFriendly)) &&
        (!filter.healthyOnly ||
            item.badges.contains(RecommendationBadge.healthyChoice));
  }

  int _compare(
    RecipeRecommendation first,
    RecipeRecommendation second,
    RecommendationSort sort,
  ) {
    final primary = switch (sort) {
      RecommendationSort.bestMatch => second.recipeMatchPercent.compareTo(
        first.recipeMatchPercent,
      ),
      RecommendationSort.highestScore => second.score.compareTo(first.score),
      RecommendationSort.fastest => _knownCookTime(
        first,
      ).compareTo(_knownCookTime(second)),
      RecommendationSort.leastMissing => first.missingIngredientCount.compareTo(
        second.missingIngredientCount,
      ),
      RecommendationSort.mostPantryUsed =>
        second.usedPantryIngredientCount.compareTo(
          first.usedPantryIngredientCount,
        ),
      RecommendationSort.newest => second.match.recipe.version.compareTo(
        first.match.recipe.version,
      ),
    };
    if (primary != 0) {
      return primary;
    }
    final score = second.score.compareTo(first.score);
    if (score != 0) {
      return score;
    }
    return first.match.recipe.id.compareTo(second.match.recipe.id);
  }

  int _knownCookTime(RecipeRecommendation item) {
    final minutes = item.match.recipe.cookTimeMinutes;
    return minutes <= 0 ? 1 << 30 : minutes;
  }
}
