import '../../../../core/models/ingredient.dart';
import '../../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../entities/recipe.dart';
import '../entities/recipe_ingredient.dart';
import '../entities/recipe_match.dart';
import '../entities/smart_recommendation.dart';
import 'ingredient_name_matcher.dart';

class SmartRecommendationEngine {
  const SmartRecommendationEngine({this.pageSize = 5, this.moreLimit = 8})
    : assert(pageSize > 0),
      assert(moreLimit >= 0);

  final int pageSize;
  final int moreLimit;

  SmartRecommendation build({
    required List<RecipeMatch> matches,
    required List<Ingredient> pantry,
    String? selectedHeroKey,
    HeroSelectionMode? selectionMode,
    String? selectionReason,
    int pageIndex = 0,
    int shuffleSeed = 0,
    CanonicalIngredientRegistry? registry,
  }) {
    final availablePantry = pantry
        .where((ingredient) => ingredient.quantity > 0 && !ingredient.isExpired)
        .toList(growable: false);
    final optionCandidates = _buildHeroOptions(
      matches,
      availablePantry,
      registry,
    );
    final heroOptions = optionCandidates
        .map((candidate) => candidate.option)
        .toList(growable: false);
    final selectedKey = _normalize(selectedHeroKey ?? '');
    final requestedMode =
        selectionMode ??
        (selectedKey.isEmpty
            ? HeroSelectionMode.automatic
            : HeroSelectionMode.manual);

    _HeroCandidate? requestedCandidate;
    if (requestedMode != HeroSelectionMode.automatic &&
        selectedKey.isNotEmpty) {
      for (final candidate in optionCandidates) {
        if (candidate.option.key == selectedKey) {
          requestedCandidate = candidate;
          break;
        }
      }
    }

    final requestedSelectionAvailable =
        requestedMode == HeroSelectionMode.automatic ||
        requestedCandidate != null;
    final selectedCandidate =
        requestedCandidate ??
        (optionCandidates.isEmpty ? null : optionCandidates.first);
    final resolvedMode = requestedCandidate == null
        ? HeroSelectionMode.automatic
        : requestedMode;

    if (selectedCandidate == null) {
      final fallbackMatches =
          matches
              .where((match) => match.matchedIngredients.isNotEmpty)
              .toList(growable: false)
            ..sort(_compareDisplayRank);

      return SmartRecommendation(
        heroOptions: heroOptions,
        primaryMatches: const <RecipeMatch>[],
        moreMatches: fallbackMatches.take(moreLimit).toList(growable: false),
        totalHeroRecipes: 0,
        pageIndex: 0,
        pageCount: 0,
        requestedSelectionAvailable: requestedSelectionAvailable,
      );
    }

    final heroPantryIngredient = selectedCandidate.ingredient;
    final heroPool =
        matches
            .where(
              (match) => _recipeHeroMatchesPantry(
                match.recipe,
                heroPantryIngredient,
                registry,
              ),
            )
            .toList(growable: false)
          ..sort(
            (first, second) => _comparePoolOrder(first, second, shuffleSeed),
          );

    final pageCount = heroPool.isEmpty
        ? 0
        : (heroPool.length / pageSize).ceil();
    final safePageIndex = pageCount == 0
        ? 0
        : pageIndex.clamp(0, pageCount - 1).toInt();
    final start = safePageIndex * pageSize;
    final end = (start + pageSize).clamp(0, heroPool.length).toInt();
    final primary =
        start >= heroPool.length
              ? <RecipeMatch>[]
              : heroPool.sublist(start, end)
          ..sort(_compareDisplayRank);
    final heroRecipeIds = heroPool.map((match) => match.recipe.id).toSet();
    final more =
        matches
            .where(
              (match) =>
                  !heroRecipeIds.contains(match.recipe.id) &&
                  availablePantry.any(
                    (ingredient) => _recipeHeroMatchesPantry(
                      match.recipe,
                      ingredient,
                      registry,
                    ),
                  ),
            )
            .toList(growable: false)
          ..sort(_compareDisplayRank);

    return SmartRecommendation(
      hero: selectedCandidate.option,
      heroOptions: heroOptions,
      primaryMatches: List<RecipeMatch>.unmodifiable(primary),
      moreMatches: List<RecipeMatch>.unmodifiable(more.take(moreLimit)),
      totalHeroRecipes: heroPool.length,
      pageIndex: safePageIndex,
      pageCount: pageCount,
      heroSelectionMode: resolvedMode,
      heroReason: _heroReason(
        selectedCandidate,
        resolvedMode,
        selectionReason: requestedCandidate == null ? null : selectionReason,
      ),
      requestedSelectionAvailable: requestedSelectionAvailable,
    );
  }

  List<_HeroCandidate> _buildHeroOptions(
    List<RecipeMatch> matches,
    List<Ingredient> pantry,
    CanonicalIngredientRegistry? registry,
  ) {
    final candidatesByKey = <String, _HeroCandidate>{};

    for (final pantryIngredient in pantry) {
      final matchingRecipes = matches
          .where(
            (match) => _recipeHeroMatchesPantry(
              match.recipe,
              pantryIngredient,
              registry,
            ),
          )
          .toList(growable: false);
      if (matchingRecipes.isEmpty) {
        continue;
      }

      final representativeRecipe = matchingRecipes.first.recipe;
      final canonicalId = pantryIngredient.canonicalIngredientId.isNotEmpty
          ? pantryIngredient.canonicalIngredientId
          : representativeRecipe.resolvedHeroIngredientId;
      final key = _normalize(
        canonicalId.isEmpty
            ? representativeRecipe.resolvedHeroIngredientName
            : canonicalId,
      );
      if (key.isEmpty) {
        continue;
      }

      var bestScorePercent = 0;
      var readyCount = 0;
      for (final match in matchingRecipes) {
        if (match.scorePercent > bestScorePercent) {
          bestScorePercent = match.scorePercent;
        }
        if (match.canCook) {
          readyCount++;
        }
      }

      final candidate = _HeroCandidate(
        ingredient: pantryIngredient,
        option: HeroIngredientOption(
          key: key,
          name: pantryIngredient.name,
          emoji: pantryIngredient.emoji,
          recipeCount: matchingRecipes.length,
          readyCount: readyCount,
          bestScorePercent: bestScorePercent,
          daysUntilExpiry: pantryIngredient.daysUntilExpiry,
        ),
      );
      final current = candidatesByKey[key];
      if (current == null || _compareHeroCandidates(candidate, current) < 0) {
        candidatesByKey[key] = candidate;
      }
    }

    final candidates = candidatesByKey.values.toList(growable: false)
      ..sort(_compareHeroCandidates);
    return candidates;
  }

  int _compareHeroCandidates(_HeroCandidate first, _HeroCandidate second) {
    final priorityComparison = _autoPriority(
      second,
    ).compareTo(_autoPriority(first));
    if (priorityComparison != 0) {
      return priorityComparison;
    }

    final createdComparison = second.ingredient.createdAt.compareTo(
      first.ingredient.createdAt,
    );
    if (createdComparison != 0) {
      return createdComparison;
    }

    return first.option.name.compareTo(second.option.name);
  }

  int _autoPriority(_HeroCandidate candidate) {
    final option = candidate.option;
    var priority =
        (option.readyCount * 1000) +
        (option.bestScorePercent * 10) +
        (option.recipeCount * 2);
    final days = option.daysUntilExpiry;

    if (days != null) {
      if (days <= 1) {
        priority += 100000;
      } else if (days <= 3) {
        priority += 80000;
      } else if (days <= 7) {
        priority += 50000;
      }
    }

    return priority;
  }

  String _heroReason(
    _HeroCandidate candidate,
    HeroSelectionMode selectionMode, {
    String? selectionReason,
  }) {
    final customReason = selectionReason?.trim();
    if (customReason != null && customReason.isNotEmpty) {
      return customReason;
    }

    switch (selectionMode) {
      case HeroSelectionMode.manual:
        return 'คุณเลือก ${candidate.option.name} เป็นวัตถุดิบหลักสำหรับครั้งนี้';
      case HeroSelectionMode.pinned:
        return 'คุณปักหมุด ${candidate.option.name} ไว้เป็นวัตถุดิบหลัก';
      case HeroSelectionMode.automatic:
        final days = candidate.option.daysUntilExpiry;
        if (days != null && days <= 7) {
          if (days <= 0) {
            return 'ระบบเลือกให้อัตโนมัติ เพราะควรใช้ ${candidate.option.name} วันนี้';
          }
          return 'ระบบเลือกให้อัตโนมัติ เพราะ ${candidate.option.name} จะหมดอายุใน $days วัน';
        }
        if (candidate.option.readyCount > 0) {
          return 'ระบบเลือกให้อัตโนมัติ เพราะมี ${candidate.option.readyCount} เมนูที่พร้อมทำ';
        }
        return 'ระบบเลือกให้อัตโนมัติ จากความพร้อมของวัตถุดิบและเมนูที่เกี่ยวข้อง';
    }
  }

  bool _recipeHeroMatchesPantry(
    Recipe recipe,
    Ingredient pantryIngredient,
    CanonicalIngredientRegistry? registry,
  ) {
    final hero = recipe.heroIngredient;
    return recipe.ingredients.any((ingredient) {
      final role = ingredient.effectiveRole(isHero: identical(ingredient, hero));
      return role == RecipeIngredientRole.primary &&
          _ingredientMatches(ingredient, pantryIngredient, registry);
    });
  }

  bool _ingredientMatches(
    RecipeIngredient ingredient,
    Ingredient pantryIngredient,
    CanonicalIngredientRegistry? registry,
  ) {
    return recipeIngredientMatchesPantry(
      ingredient,
      pantryIngredient,
      registry: registry,
    );
  }

  int _comparePoolOrder(RecipeMatch first, RecipeMatch second, int seed) {
    if (first.canCook != second.canCook) {
      return first.canCook ? -1 : 1;
    }

    final firstBand = (first.score * 10).floor();
    final secondBand = (second.score * 10).floor();
    final scoreBandComparison = secondBand.compareTo(firstBand);
    if (scoreBandComparison != 0) {
      return scoreBandComparison;
    }

    final missingComparison = first.missingRequiredCount.compareTo(
      second.missingRequiredCount,
    );
    if (missingComparison != 0) {
      return missingComparison;
    }

    final firstHash = _stableHash(first.recipe.id, seed);
    final secondHash = _stableHash(second.recipe.id, seed);
    final hashComparison = firstHash.compareTo(secondHash);
    if (hashComparison != 0) {
      return hashComparison;
    }

    return first.recipe.name.compareTo(second.recipe.name);
  }

  int _compareDisplayRank(RecipeMatch first, RecipeMatch second) {
    final scoreComparison = second.score.compareTo(first.score);
    if (scoreComparison != 0) {
      return scoreComparison;
    }

    if (first.canCook != second.canCook) {
      return first.canCook ? -1 : 1;
    }

    final missingComparison = first.missingRequiredCount.compareTo(
      second.missingRequiredCount,
    );
    if (missingComparison != 0) {
      return missingComparison;
    }

    final popularityComparison = second.recipe.popularity.compareTo(
      first.recipe.popularity,
    );
    if (popularityComparison != 0) {
      return popularityComparison;
    }

    final firstCookTime = first.recipe.cookTimeMinutes <= 0
        ? 1 << 30
        : first.recipe.cookTimeMinutes;
    final secondCookTime = second.recipe.cookTimeMinutes <= 0
        ? 1 << 30
        : second.recipe.cookTimeMinutes;
    final cookTimeComparison = firstCookTime.compareTo(secondCookTime);
    if (cookTimeComparison != 0) {
      return cookTimeComparison;
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
