import '../../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../entities/recipe.dart';
import '../entities/recipe_ingredient.dart';

class RecipeDiscoveryCriteria {
  const RecipeDiscoveryCriteria({
    this.query = '',
    this.mainIngredientId,
    this.maxCookTimeMinutes,
    this.difficulty,
    this.cookingMethod,
    this.category,
  });

  final String query;
  final String? mainIngredientId;
  final int? maxCookTimeMinutes;
  final String? difficulty;
  final String? cookingMethod;
  final String? category;

  bool get hasActiveCriteria {
    return query.trim().isNotEmpty ||
        _hasValue(mainIngredientId) ||
        maxCookTimeMinutes != null ||
        _hasValue(difficulty) ||
        _hasValue(cookingMethod) ||
        _hasValue(category);
  }
}

class RecipeDiscoveryMainIngredient {
  const RecipeDiscoveryMainIngredient({
    required this.id,
    required this.name,
    required this.emoji,
    required this.recipeCount,
  });

  final String id;
  final String name;
  final String emoji;
  final int recipeCount;
}

enum RecipeDiscoveryMatchType {
  exactTitle,
  exactHeroIngredient,
  exactIngredient,
  titlePrefix,
  titleContains,
  ingredientPrefix,
  ingredientContains,
  metadata,
  filterOnly,
}

class RecipeDiscoveryResult {
  const RecipeDiscoveryResult({
    required this.recipe,
    required this.matchType,
    required this.searchScore,
  });

  final Recipe recipe;
  final RecipeDiscoveryMatchType matchType;
  final int searchScore;
}

class RecipeDiscoveryService {
  const RecipeDiscoveryService();

  List<RecipeDiscoveryResult> discover({
    required Iterable<Recipe> recipes,
    required RecipeDiscoveryCriteria criteria,
    CanonicalIngredientRegistry? registry,
  }) {
    if (!criteria.hasActiveCriteria) {
      return const <RecipeDiscoveryResult>[];
    }

    final query = _normalize(criteria.query);
    final results = <RecipeDiscoveryResult>[];
    for (final recipe in recipes) {
      if (!_passesFilters(recipe, criteria, registry)) {
        continue;
      }

      final searchMatch = query.isEmpty
          ? const _SearchMatch(RecipeDiscoveryMatchType.filterOnly, 0)
          : _matchQuery(recipe, query);
      if (searchMatch == null) {
        continue;
      }

      results.add(
        RecipeDiscoveryResult(
          recipe: recipe,
          matchType: searchMatch.type,
          searchScore: searchMatch.score,
        ),
      );
    }

    results.sort(_compareResults);
    return List<RecipeDiscoveryResult>.unmodifiable(results);
  }

  List<RecipeDiscoveryMainIngredient> mainIngredients(
    Iterable<Recipe> recipes, {
    CanonicalIngredientRegistry? registry,
  }) {
    final candidates = <String, _MainIngredientCandidate>{};
    for (final recipe in recipes) {
      final hero = recipe.heroIngredient;
      if (hero == null) {
        continue;
      }
      final id = _canonicalHeroId(recipe, registry);
      if (id.isEmpty) {
        continue;
      }
      final canonical = registry?.byId(id);
      if (canonical != null && !canonical.canSelectAsMainIngredient) {
        continue;
      }

      final fallbackName = recipe.resolvedHeroIngredientName.trim().isEmpty
          ? hero.name.trim()
          : recipe.resolvedHeroIngredientName.trim();
      final name = canonical?.displayName('th').trim().isNotEmpty == true
          ? canonical!.displayName('th').trim()
          : fallbackName;
      if (name.isEmpty) {
        continue;
      }
      final emoji = canonical?.emoji.trim().isNotEmpty == true
          ? canonical!.emoji.trim()
          : recipe.emoji;
      final current = candidates[id];
      candidates[id] = _MainIngredientCandidate(
        id: id,
        name: current?.name ?? name,
        emoji: current?.emoji ?? emoji,
        recipeCount: (current?.recipeCount ?? 0) + 1,
      );
    }

    final sorted = candidates.values.toList(growable: false)
      ..sort((first, second) {
        final nameComparison = first.name.compareTo(second.name);
        return nameComparison != 0
            ? nameComparison
            : first.id.compareTo(second.id);
      });
    return List<RecipeDiscoveryMainIngredient>.unmodifiable(
      sorted.map(
        (candidate) => RecipeDiscoveryMainIngredient(
          id: candidate.id,
          name: candidate.name,
          emoji: candidate.emoji,
          recipeCount: candidate.recipeCount,
        ),
      ),
    );
  }

  List<String> categories(Iterable<Recipe> recipes) {
    return _rankFacetValues(recipes.map((recipe) => recipe.category));
  }

  List<String> difficulties(Iterable<Recipe> recipes) {
    return _rankFacetValues(recipes.map((recipe) => recipe.difficulty));
  }

  List<String> cookingMethods(Iterable<Recipe> recipes) {
    return _rankFacetValues(recipes.expand((recipe) => recipe.cookingMethods));
  }

  bool _passesFilters(
    Recipe recipe,
    RecipeDiscoveryCriteria criteria,
    CanonicalIngredientRegistry? registry,
  ) {
    final selectedMainIngredientId = criteria.mainIngredientId;
    if (_hasValue(selectedMainIngredientId) &&
        _canonicalHeroId(recipe, registry) !=
            _canonicalId(selectedMainIngredientId!, registry)) {
      return false;
    }
    final maxMinutes = criteria.maxCookTimeMinutes;
    if (maxMinutes != null &&
        (recipe.cookTimeMinutes <= 0 || recipe.cookTimeMinutes > maxMinutes)) {
      return false;
    }
    if (!_equalsOptional(recipe.difficulty, criteria.difficulty)) {
      return false;
    }
    if (_hasValue(criteria.cookingMethod) &&
        !recipe.cookingMethods.any(
          (method) => _normalize(method) == _normalize(criteria.cookingMethod!),
        )) {
      return false;
    }
    return _equalsOptional(recipe.category, criteria.category);
  }

  String _canonicalHeroId(
    Recipe recipe,
    CanonicalIngredientRegistry? registry,
  ) {
    return _canonicalId(recipe.resolvedHeroIngredientId, registry);
  }

  String _canonicalId(String value, CanonicalIngredientRegistry? registry) {
    final canonical = registry?.canonicalIdFor(value);
    return canonical ?? normalizeCanonicalIngredientId(value);
  }

  _SearchMatch? _matchQuery(Recipe recipe, String query) {
    final title = _normalize(recipe.name);
    if (title == query) {
      return const _SearchMatch(RecipeDiscoveryMatchType.exactTitle, 1000);
    }

    final hero = recipe.heroIngredient;
    if (hero != null && _ingredientKeys(hero).contains(query)) {
      return const _SearchMatch(
        RecipeDiscoveryMatchType.exactHeroIngredient,
        950,
      );
    }

    final ingredientKeys = recipe.ingredients
        .expand(_ingredientKeys)
        .where((value) => value.isNotEmpty)
        .toSet();
    if (ingredientKeys.contains(query)) {
      return const _SearchMatch(RecipeDiscoveryMatchType.exactIngredient, 900);
    }
    if (title.startsWith(query)) {
      return const _SearchMatch(RecipeDiscoveryMatchType.titlePrefix, 800);
    }
    if (title.contains(query)) {
      return const _SearchMatch(RecipeDiscoveryMatchType.titleContains, 750);
    }
    if (ingredientKeys.any((value) => value.startsWith(query))) {
      return const _SearchMatch(RecipeDiscoveryMatchType.ingredientPrefix, 700);
    }
    if (ingredientKeys.any((value) => value.contains(query))) {
      return const _SearchMatch(
        RecipeDiscoveryMatchType.ingredientContains,
        650,
      );
    }

    final metadata = <String>{
      recipe.category,
      ...recipe.tags,
      ...recipe.cookingMethods,
    }.map(_normalize);
    if (metadata.any((value) => value.contains(query))) {
      return const _SearchMatch(RecipeDiscoveryMatchType.metadata, 500);
    }
    return null;
  }

  Iterable<String> _ingredientKeys(RecipeIngredient ingredient) sync* {
    yield _normalize(ingredient.id);
    yield _normalize(ingredient.name);
    for (final alias in ingredient.aliases) {
      yield _normalize(alias);
    }
  }

  int _compareResults(
    RecipeDiscoveryResult first,
    RecipeDiscoveryResult second,
  ) {
    final searchComparison = second.searchScore.compareTo(first.searchScore);
    if (searchComparison != 0) {
      return searchComparison;
    }
    final popularityComparison = second.recipe.popularity.compareTo(
      first.recipe.popularity,
    );
    if (popularityComparison != 0) {
      return popularityComparison;
    }
    final firstTime = first.recipe.cookTimeMinutes <= 0
        ? 1 << 30
        : first.recipe.cookTimeMinutes;
    final secondTime = second.recipe.cookTimeMinutes <= 0
        ? 1 << 30
        : second.recipe.cookTimeMinutes;
    final timeComparison = firstTime.compareTo(secondTime);
    if (timeComparison != 0) {
      return timeComparison;
    }
    return first.recipe.name.compareTo(second.recipe.name);
  }

  List<String> _rankFacetValues(Iterable<String> values) {
    final counts = <String, int>{};
    final labels = <String, String>{};
    for (final raw in values) {
      final label = raw.trim();
      final key = _normalize(label);
      if (key.isEmpty) {
        continue;
      }
      labels.putIfAbsent(key, () => label);
      counts.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    final keys = counts.keys.toList(growable: false)
      ..sort((first, second) {
        final countComparison = counts[second]!.compareTo(counts[first]!);
        if (countComparison != 0) {
          return countComparison;
        }
        return labels[first]!.compareTo(labels[second]!);
      });
    return List<String>.unmodifiable(keys.map((key) => labels[key]!));
  }
}

class _SearchMatch {
  const _SearchMatch(this.type, this.score);

  final RecipeDiscoveryMatchType type;
  final int score;
}

class _MainIngredientCandidate {
  const _MainIngredientCandidate({
    required this.id,
    required this.name,
    required this.emoji,
    required this.recipeCount,
  });

  final String id;
  final String name;
  final String emoji;
  final int recipeCount;
}

bool _hasValue(String? value) => value?.trim().isNotEmpty == true;

bool _equalsOptional(String source, String? expected) {
  return !_hasValue(expected) || _normalize(source) == _normalize(expected!);
}

String _normalize(String value) {
  return normalizeIngredientKey(value).replaceAll(' ', '');
}
