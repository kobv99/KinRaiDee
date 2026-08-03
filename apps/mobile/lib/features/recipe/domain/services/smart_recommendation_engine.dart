import '../../../../core/models/ingredient.dart';
import '../../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../entities/recipe.dart';
import '../entities/recipe_compatibility.dart';
import '../entities/recipe_ingredient.dart';
import '../entities/recipe_match.dart';
import '../entities/smart_recommendation.dart';
import 'ingredient_name_matcher.dart';
import 'main_ingredient_compatibility_service.dart';

class SmartRecommendationEngine {
  const SmartRecommendationEngine({
    this.pageSize = 5,
    this.moreLimit = 8,
    this.compatibilityService = const MainIngredientCompatibilityService(),
  }) : assert(pageSize > 0),
       assert(moreLimit >= 0);

  final int pageSize;
  final int moreLimit;
  final MainIngredientCompatibilityService compatibilityService;

  SmartRecommendation build({
    required List<RecipeMatch> matches,
    required List<Ingredient> pantry,
    List<RecipeMatch>? allRecipeMatches,
    String? selectedHeroKey,
    HeroSelectionMode? selectionMode,
    String? selectionReason,
    int pageIndex = 0,
    int shuffleSeed = 0,
    CanonicalIngredientRegistry? registry,
    MainIngredientSelection? selectedIngredient,
    Set<String> recentHeroKeys = const <String>{},
  }) {
    final recommendationSource = allRecipeMatches ?? matches;
    final availablePantry = pantry
        .where((ingredient) => ingredient.quantity > 0 && !ingredient.isExpired)
        .toList(growable: false);
    final normalizedRecentKeys = recentHeroKeys.map(_normalize).toSet();
    final automaticCandidates = _buildHeroOptions(
      recommendationSource,
      availablePantry,
      registry,
      normalizedRecentKeys,
    );
    final optionCandidates = <_HeroCandidate>[...automaticCandidates];
    if (registry != null) {
      _appendSupportedOptions(
        candidates: optionCandidates,
        matches: recommendationSource,
        registry: registry,
        recentKeys: normalizedRecentKeys,
      );
    }
    final selectedKey = _normalize(
      selectedIngredient?.canonicalIngredientId ?? selectedHeroKey ?? '',
    );
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
      if (requestedCandidate == null) {
        final requestedSelection =
            selectedIngredient ?? _selectionForKey(selectedKey, registry);
        requestedCandidate = _buildCandidateForSelection(
          recommendationSource,
          requestedSelection,
          isInPantry: false,
          categoryLabel:
              registry
                  ?.byId(requestedSelection.canonicalIngredientId)
                  ?.category ??
              '',
          searchTerms:
              registry
                  ?.byId(requestedSelection.canonicalIngredientId)
                  ?.searchableNames
                  .toList(growable: false) ??
              const <String>[],
          isRecent: normalizedRecentKeys.contains(selectedKey),
        );
        if (requestedCandidate != null) {
          optionCandidates.add(requestedCandidate);
        }
      }
    }

    optionCandidates.sort(_comparePickerCandidates);
    final heroOptions = optionCandidates
        .map((candidate) => candidate.option)
        .toList(growable: false);

    final requestedSelectionAvailable =
        requestedMode == HeroSelectionMode.automatic ||
        requestedCandidate != null;
    final selectedCandidate =
        requestedCandidate ??
        (automaticCandidates.isEmpty ? null : automaticCandidates.first);
    final resolvedMode = requestedCandidate == null
        ? HeroSelectionMode.automatic
        : requestedMode;

    if (selectedCandidate == null) {
      final fallbackMatches =
          matches
              .map(
                (match) =>
                    _bestPantryCompatibility(match, availablePantry, registry),
              )
              .whereType<RecipeMatch>()
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

    final evaluatedForHero = recommendationSource
        .map((match) => _withCompatibility(match, selectedCandidate.selection))
        .whereType<RecipeMatch>()
        .toList(growable: false);
    final heroPool =
        evaluatedForHero
            .where(
              (match) =>
                  match.mainIngredientMatchTier !=
                  MainIngredientMatchTier.family,
            )
            .toList(growable: false)
          ..sort(
            (first, second) => _comparePoolOrder(first, second, shuffleSeed),
          );
    final adaptable =
        evaluatedForHero
            .where(
              (match) =>
                  match.mainIngredientMatchTier ==
                  MainIngredientMatchTier.family,
            )
            .toList(growable: false)
          ..sort(_compareDisplayRank);

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
    final heroRecipeIds = evaluatedForHero
        .map((match) => match.recipe.id)
        .toSet();
    final more =
        matches
            .where((match) => !heroRecipeIds.contains(match.recipe.id))
            .map(
              (match) =>
                  _bestPantryCompatibility(match, availablePantry, registry),
            )
            .whereType<RecipeMatch>()
            .toList(growable: false)
          ..sort(_compareDisplayRank);

    return SmartRecommendation(
      hero: selectedCandidate.option,
      heroOptions: heroOptions,
      primaryMatches: List<RecipeMatch>.unmodifiable(primary),
      adaptableMatches: List<RecipeMatch>.unmodifiable(
        adaptable.take(moreLimit),
      ),
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
    Set<String> recentKeys,
  ) {
    final candidatesByKey = <String, _HeroCandidate>{};

    for (final pantryIngredient in pantry) {
      final matchingByKey = <String, List<RecipeMatch>>{};
      final selectionByKey = <String, MainIngredientSelection>{};
      for (final match in matches) {
        final selection = _selectionForPantry(
          pantryIngredient,
          match.recipe,
          registry,
        );
        final evaluated = _withCompatibility(match, selection);
        if (evaluated == null) {
          continue;
        }
        final key = _normalize(selection.canonicalIngredientId);
        if (key.isEmpty) {
          continue;
        }
        final canonical = registry?.byId(key);
        if (registry != null &&
            (canonical == null || !canonical.canSelectAsMainIngredient)) {
          continue;
        }
        selectionByKey[key] = selection;
        matchingByKey.putIfAbsent(key, () => <RecipeMatch>[]).add(evaluated);
      }

      for (final entry in matchingByKey.entries) {
        final key = entry.key;
        final matchingRecipes = entry.value;
        var bestScorePercent = 0;
        var readyCount = 0;
        MainIngredientMatchTier? bestMatchTier;
        for (final match in matchingRecipes) {
          if (match.scorePercent > bestScorePercent) {
            bestScorePercent = match.scorePercent;
          }
          if (match.canCook) {
            readyCount++;
          }
          final tier = match.mainIngredientMatchTier;
          if (tier != null &&
              (bestMatchTier == null ||
                  tier.priority > bestMatchTier.priority)) {
            bestMatchTier = tier;
          }
        }
        final canonical = registry?.byId(key);

        final candidate = _HeroCandidate(
          ingredient: pantryIngredient,
          selection: selectionByKey[key]!,
          option: HeroIngredientOption(
            key: key,
            name: pantryIngredient.name,
            emoji: pantryIngredient.emoji,
            recipeCount: matchingRecipes.length,
            readyCount: readyCount,
            bestScorePercent: bestScorePercent,
            daysUntilExpiry: pantryIngredient.daysUntilExpiry,
            isInPantry: true,
            categoryLabel: canonical?.category ?? pantryIngredient.category,
            searchTerms:
                canonical?.searchableNames.toList(growable: false) ??
                <String>[pantryIngredient.name],
            isRecent: recentKeys.contains(key),
            bestMatchTier: bestMatchTier,
          ),
        );
        final current = candidatesByKey[key];
        if (current == null || _compareHeroCandidates(candidate, current) < 0) {
          candidatesByKey[key] = candidate;
        }
      }
    }

    final candidates = candidatesByKey.values.toList(growable: false)
      ..sort(_compareHeroCandidates);
    return candidates;
  }

  void _appendSupportedOptions({
    required List<_HeroCandidate> candidates,
    required List<RecipeMatch> matches,
    required CanonicalIngredientRegistry registry,
    required Set<String> recentKeys,
  }) {
    final existingKeys = candidates
        .map((candidate) => candidate.option.key)
        .toSet();
    for (final canonical in registry.ingredients) {
      if (!canonical.canSelectAsMainIngredient ||
          existingKeys.contains(canonical.id)) {
        continue;
      }
      final candidate = _buildCandidateForSelection(
        matches,
        _selectionForKey(canonical.id, registry),
        isInPantry: false,
        categoryLabel: canonical.category,
        searchTerms: canonical.searchableNames.toList(growable: false),
        isRecent: recentKeys.contains(canonical.id),
      );
      if (candidate != null) {
        candidates.add(candidate);
        existingKeys.add(canonical.id);
      }
    }
  }

  int _comparePickerCandidates(_HeroCandidate first, _HeroCandidate second) {
    if (first.option.isInPantry != second.option.isInPantry) {
      return first.option.isInPantry ? -1 : 1;
    }
    if (first.option.isRecent != second.option.isRecent) {
      return first.option.isRecent ? -1 : 1;
    }
    if (first.option.isInPantry) {
      final automaticRank = _compareHeroCandidates(first, second);
      if (automaticRank != 0) {
        return automaticRank;
      }
    }
    return first.option.name.compareTo(second.option.name);
  }

  int _compareHeroCandidates(_HeroCandidate first, _HeroCandidate second) {
    final priorityComparison = _autoPriority(
      second,
    ).compareTo(_autoPriority(first));
    if (priorityComparison != 0) {
      return priorityComparison;
    }

    final firstCreated = first.ingredient?.createdAt;
    final secondCreated = second.ingredient?.createdAt;
    final createdComparison = secondCreated == null
        ? (firstCreated == null ? 0 : 1)
        : firstCreated == null
        ? -1
        : secondCreated.compareTo(firstCreated);
    if (createdComparison != 0) {
      return createdComparison;
    }

    return first.option.name.compareTo(second.option.name);
  }

  int _autoPriority(_HeroCandidate candidate) {
    final option = candidate.option;
    var priority =
        ((option.bestMatchTier?.priority ?? 0) * 1000000) +
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

  MainIngredientSelection _selectionForKey(
    String key,
    CanonicalIngredientRegistry? registry,
  ) {
    final canonical = registry?.byId(key);
    return compatibilityService.enrichSelection(
      MainIngredientSelection(
        canonicalIngredientId: canonical?.id ?? key,
        displayName: canonical?.displayName() ?? key,
        emoji: canonical?.emoji ?? '🍳',
      ),
    );
  }

  MainIngredientSelection _selectionForPantry(
    Ingredient pantryIngredient,
    Recipe recipe,
    CanonicalIngredientRegistry? registry,
  ) {
    var canonicalId = pantryIngredient.canonicalIngredientId.trim();
    if (canonicalId.isNotEmpty) {
      canonicalId = registry?.canonicalIdFor(canonicalId) ?? canonicalId;
    } else {
      final resolved = registry?.resolve(pantryIngredient.name).ingredient;
      if (resolved != null) {
        canonicalId = resolved.id;
      } else if (registry == null) {
        final hero = recipe.heroIngredient;
        for (final ingredient in recipe.ingredients) {
          final role = ingredient.effectiveRole(
            isHero: identical(ingredient, hero),
          );
          if (role == RecipeIngredientRole.primary &&
              recipeIngredientMatchesPantryName(
                ingredient,
                pantryIngredient.name,
              )) {
            canonicalId = ingredient.id;
            break;
          }
        }
      }
    }

    return compatibilityService.enrichSelection(
      MainIngredientSelection(
        canonicalIngredientId: canonicalId,
        displayName: pantryIngredient.name,
        emoji: pantryIngredient.emoji,
      ),
    );
  }

  _HeroCandidate? _buildCandidateForSelection(
    List<RecipeMatch> matches,
    MainIngredientSelection selection, {
    required bool isInPantry,
    String categoryLabel = '',
    List<String> searchTerms = const <String>[],
    bool isRecent = false,
  }) {
    final enriched = compatibilityService.enrichSelection(selection);
    final key = _normalize(enriched.canonicalIngredientId);
    if (key.isEmpty) {
      return null;
    }
    final matchingRecipes = matches
        .map((match) => _withCompatibility(match, enriched))
        .whereType<RecipeMatch>()
        .toList(growable: false);
    if (matchingRecipes.isEmpty) {
      return null;
    }

    var bestScorePercent = 0;
    var readyCount = 0;
    MainIngredientMatchTier? bestMatchTier;
    for (final match in matchingRecipes) {
      if (match.scorePercent > bestScorePercent) {
        bestScorePercent = match.scorePercent;
      }
      if (match.canCook) {
        readyCount++;
      }
      final tier = match.mainIngredientMatchTier;
      if (tier != null &&
          (bestMatchTier == null || tier.priority > bestMatchTier.priority)) {
        bestMatchTier = tier;
      }
    }
    return _HeroCandidate(
      selection: enriched,
      option: HeroIngredientOption(
        key: key,
        name: enriched.displayName,
        emoji: enriched.emoji,
        recipeCount: matchingRecipes.length,
        readyCount: readyCount,
        bestScorePercent: bestScorePercent,
        isInPantry: isInPantry,
        categoryLabel: categoryLabel,
        searchTerms: searchTerms,
        isRecent: isRecent,
        bestMatchTier: bestMatchTier,
      ),
    );
  }

  RecipeMatch? _withCompatibility(
    RecipeMatch match,
    MainIngredientSelection selection,
  ) {
    final result = compatibilityService.evaluate(
      recipe: match.recipe,
      selection: selection,
    );
    return result.isEligible
        ? match.withMainIngredientCompatibility(result)
        : null;
  }

  RecipeMatch? _bestPantryCompatibility(
    RecipeMatch match,
    List<Ingredient> pantry,
    CanonicalIngredientRegistry? registry,
  ) {
    RecipeMatch? best;
    for (final ingredient in pantry) {
      final evaluated = _withCompatibility(
        match,
        _selectionForPantry(ingredient, match.recipe, registry),
      );
      if (evaluated == null) {
        continue;
      }
      if (best == null || _compareCompatibility(evaluated, best) < 0) {
        best = evaluated;
      }
    }
    return best;
  }

  int _compareCompatibility(RecipeMatch first, RecipeMatch second) {
    return (second.mainIngredientCompatibility?.tierPriority ?? 0).compareTo(
      first.mainIngredientCompatibility?.tierPriority ?? 0,
    );
  }

  int _comparePoolOrder(RecipeMatch first, RecipeMatch second, int seed) {
    final compatibilityComparison = _compareCompatibility(first, second);
    if (compatibilityComparison != 0) {
      return compatibilityComparison;
    }

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
    final compatibilityComparison = _compareCompatibility(first, second);
    if (compatibilityComparison != 0) {
      return compatibilityComparison;
    }

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
    return normalizeCompatibilityToken(value);
  }
}

class _HeroCandidate {
  const _HeroCandidate({
    required this.selection,
    required this.option,
    this.ingredient,
  });

  final Ingredient? ingredient;
  final MainIngredientSelection selection;
  final HeroIngredientOption option;
}
