import '../../../../core/models/ingredient.dart';
import '../entities/recipe.dart';
import '../entities/recipe_ingredient.dart';
import '../entities/recipe_match.dart';
import '../entities/smart_recommendation.dart';
import 'ingredient_name_matcher.dart';

class SmartRecommendationEngine {
  const SmartRecommendationEngine({
    this.pageSize = 5,
    this.moreLimit = 8,
  }) : assert(pageSize > 0),
       assert(moreLimit >= 0);

  final int pageSize;
  final int moreLimit;

  SmartRecommendation build({
    required List<RecipeMatch> matches,
    required List<Ingredient> pantry,
    String? selectedHeroKey,
    int pageIndex = 0,
    int shuffleSeed = 0,
  }) {
    final availablePantry = pantry
        .where((ingredient) => ingredient.quantity > 0 && !ingredient.isExpired)
        .toList(growable: false);
    final optionCandidates = _buildHeroOptions(matches, availablePantry);
    final heroOptions = optionCandidates
        .map((candidate) => candidate.option)
        .toList(growable: false);
    final selectedKey = _normalize(selectedHeroKey ?? '');
    _HeroCandidate? selectedCandidate;
    for (final candidate in optionCandidates) {
      if (candidate.option.key == selectedKey) {
        selectedCandidate = candidate;
        break;
      }
    }
    if (selectedCandidate == null && optionCandidates.isNotEmpty) {
      selectedCandidate = optionCandidates.first;
    }

    if (selectedCandidate == null) {
      final fallbackMatches = matches
          .where((match) => match.matchedIngredients.isNotEmpty)
          .toList(growable: false)
        ..sort((first, second) => _compareQuality(first, second, shuffleSeed));

      return SmartRecommendation(
        heroOptions: heroOptions,
        primaryMatches: const <RecipeMatch>[],
        moreMatches: fallbackMatches.take(moreLimit).toList(growable: false),
        totalHeroRecipes: 0,
        pageIndex: 0,
        pageCount: 0,
      );
    }

    final heroPantryIngredient = selectedCandidate.ingredient;
    final heroPool = matches
        .where(
          (match) => _recipeHeroMatchesPantry(
            match.recipe,
            heroPantryIngredient.name,
          ),
        )
        .toList(growable: false)
      ..sort((first, second) => _compareQuality(first, second, shuffleSeed));

    final pageCount = heroPool.isEmpty ? 0 : (heroPool.length / pageSize).ceil();
    final safePageIndex = pageCount == 0
        ? 0
        : pageIndex.clamp(0, pageCount - 1).toInt();
    final start = safePageIndex * pageSize;
    final end = (start + pageSize).clamp(0, heroPool.length).toInt();
    final primary = start >= heroPool.length
        ? const <RecipeMatch>[]
        : heroPool.sublist(start, end);
    final heroRecipeIds = heroPool.map((match) => match.recipe.id).toSet();
    final more = matches
        .where(
          (match) =>
              !heroRecipeIds.contains(match.recipe.id) &&
              availablePantry.any(
                (ingredient) => _recipeHeroMatchesPantry(
                  match.recipe,
                  ingredient.name,
                ),
              ),
        )
        .toList(growable: false)
      ..sort((first, second) => _compareQuality(first, second, shuffleSeed));

    return SmartRecommendation(
      hero: selectedCandidate.option,
      heroOptions: heroOptions,
      primaryMatches: List<RecipeMatch>.unmodifiable(primary),
      moreMatches: List<RecipeMatch>.unmodifiable(more.take(moreLimit)),
      totalHeroRecipes: heroPool.length,
      pageIndex: safePageIndex,
      pageCount: pageCount,
    );
  }

  List<_HeroCandidate> _buildHeroOptions(
    List<RecipeMatch> matches,
    List<Ingredient> pantry,
  ) {
    final candidatesByKey = <String, _HeroCandidate>{};

    for (final pantryIngredient in pantry) {
      final matchingRecipes = matches
          .where(
            (match) => _recipeHeroMatchesPantry(
              match.recipe,
              pantryIngredient.name,
            ),
          )
          .toList(growable: false);
      if (matchingRecipes.isEmpty) {
        continue;
      }

      final representativeRecipe = matchingRecipes.first.recipe;
      final canonicalId = representativeRecipe.resolvedHeroIngredientId;
      final key = _normalize(
        canonicalId.isEmpty
            ? representativeRecipe.resolvedHeroIngredientName
            : canonicalId,
      );
      if (key.isEmpty) {
        continue;
      }

      final candidate = _HeroCandidate(
        ingredient: pantryIngredient,
        option: HeroIngredientOption(
          key: key,
          name: pantryIngredient.name,
          emoji: pantryIngredient.emoji,
          recipeCount: matchingRecipes.length,
        ),
      );
      final current = candidatesByKey[key];
      if (current == null ||
          pantryIngredient.createdAt.isAfter(current.ingredient.createdAt)) {
        candidatesByKey[key] = candidate;
      }
    }

    final candidates = candidatesByKey.values.toList(growable: false);
    candidates.sort((first, second) {
      final createdComparison = second.ingredient.createdAt.compareTo(
        first.ingredient.createdAt,
      );
      if (createdComparison != 0) {
        return createdComparison;
      }

      final countComparison = second.option.recipeCount.compareTo(
        first.option.recipeCount,
      );
      if (countComparison != 0) {
        return countComparison;
      }

      return first.option.name.compareTo(second.option.name);
    });
    return candidates;
  }

  bool _recipeHeroMatchesPantry(Recipe recipe, String pantryName) {
    final hero = recipe.heroIngredient;
    if (hero == null) {
      return false;
    }

    return _ingredientMatches(hero, pantryName);
  }

  bool _ingredientMatches(RecipeIngredient ingredient, String pantryName) {
    return recipeIngredientMatchesPantryName(ingredient, pantryName);
  }

  int _compareQuality(RecipeMatch first, RecipeMatch second, int seed) {
    if (first.canCook != second.canCook) {
      return first.canCook ? -1 : 1;
    }

    final missingComparison = first.missingRequiredCount.compareTo(
      second.missingRequiredCount,
    );
    if (missingComparison != 0) {
      return missingComparison;
    }

    final firstBand = (first.score * 10).floor();
    final secondBand = (second.score * 10).floor();
    final scoreBandComparison = secondBand.compareTo(firstBand);
    if (scoreBandComparison != 0) {
      return scoreBandComparison;
    }

    final firstPopularityBand = first.recipe.popularity ~/ 10;
    final secondPopularityBand = second.recipe.popularity ~/ 10;
    final popularityBandComparison = secondPopularityBand.compareTo(
      firstPopularityBand,
    );
    if (popularityBandComparison != 0) {
      return popularityBandComparison;
    }

    final firstHash = _stableHash(first.recipe.id, seed);
    final secondHash = _stableHash(second.recipe.id, seed);
    final hashComparison = firstHash.compareTo(secondHash);
    if (hashComparison != 0) {
      return hashComparison;
    }

    final popularityComparison = second.recipe.popularity.compareTo(
      first.recipe.popularity,
    );
    if (popularityComparison != 0) {
      return popularityComparison;
    }

    return first.recipe.name.compareTo(second.recipe.name);
  }

  int _stableHash(String value, int seed) {
    var hash = 0x811c9dc5 ^ seed;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  String _normalize(String value) {
    return normalizeRecipeIngredientName(value);
  }
}

class _HeroCandidate {
  const _HeroCandidate({required this.ingredient, required this.option});

  final Ingredient ingredient;
  final HeroIngredientOption option;
}
