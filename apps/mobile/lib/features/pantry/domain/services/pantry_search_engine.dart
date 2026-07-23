import '../../../../core/models/ingredient.dart';
import '../models/food_category.dart';

enum PantrySearchMatchType {
  exactName,
  prefixName,
  exactAlias,
  prefixAlias,
  containsName,
  containsAlias,
  category,
  fuzzyName,
  fuzzyAlias,
  none,
}

class PantrySearchMatch {
  const PantrySearchMatch({
    required this.score,
    required this.type,
    this.matchedAlias,
  });

  const PantrySearchMatch.none()
    : score = 0,
      type = PantrySearchMatchType.none,
      matchedAlias = null;

  final int score;
  final PantrySearchMatchType type;
  final String? matchedAlias;

  bool get isMatch => score > 0;

  bool get matchedThroughAlias {
    return type == PantrySearchMatchType.exactAlias ||
        type == PantrySearchMatchType.prefixAlias ||
        type == PantrySearchMatchType.containsAlias ||
        type == PantrySearchMatchType.fuzzyAlias;
  }
}

abstract final class PantrySearchEngine {
  static final Map<String, FoodCatalogItem> _catalogByName = {
    for (final entry in allFoodCatalogItems) normalize(entry.item.name): entry,
  };

  static String normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[\s\-_.\/]+'), '');
  }

  static PantrySearchMatch matchCatalogItem(
    FoodCatalogItem entry,
    String query,
  ) {
    return _match(
      name: entry.item.name,
      aliases: entry.item.aliases,
      category: entry.category,
      query: query,
    );
  }

  static PantrySearchMatch matchIngredient(
    Ingredient ingredient,
    String query,
  ) {
    final catalogEntry = _catalogByName[normalize(ingredient.name)];

    return _match(
      name: ingredient.name,
      aliases: catalogEntry?.item.aliases ?? const <String>[],
      category: ingredient.category,
      query: query,
    );
  }

  static List<FoodCatalogItem> rankCatalogItems(
    Iterable<FoodCatalogItem> entries,
    String query,
  ) {
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) {
      return const <FoodCatalogItem>[];
    }

    final scoredItems = <_ScoredCatalogItem>[];

    for (final entry in entries) {
      final match = matchCatalogItem(entry, normalizedQuery);
      if (match.isMatch) {
        scoredItems.add(_ScoredCatalogItem(entry: entry, match: match));
      }
    }

    scoredItems.sort((first, second) {
      final scoreComparison = second.match.score.compareTo(first.match.score);
      if (scoreComparison != 0) {
        return scoreComparison;
      }

      final lengthComparison = first.entry.item.name.length.compareTo(
        second.entry.item.name.length,
      );
      if (lengthComparison != 0) {
        return lengthComparison;
      }

      return first.entry.item.name.compareTo(second.entry.item.name);
    });

    return List<FoodCatalogItem>.unmodifiable(
      scoredItems.map((scoredItem) => scoredItem.entry),
    );
  }

  static PantrySearchMatch _match({
    required String name,
    required List<String> aliases,
    required String category,
    required String query,
  }) {
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) {
      return const PantrySearchMatch.none();
    }

    final normalizedName = normalize(name);
    final normalizedCategory = normalize(category);
    final normalizedAliases = <({String original, String normalized})>[
      for (final alias in aliases)
        (original: alias, normalized: normalize(alias)),
    ];

    if (normalizedName == normalizedQuery) {
      return const PantrySearchMatch(
        score: 1000,
        type: PantrySearchMatchType.exactName,
      );
    }

    if (normalizedName.startsWith(normalizedQuery)) {
      return PantrySearchMatch(
        score: 900 - _lengthPenalty(normalizedName, normalizedQuery),
        type: PantrySearchMatchType.prefixName,
      );
    }

    for (final alias in normalizedAliases) {
      if (alias.normalized == normalizedQuery) {
        return PantrySearchMatch(
          score: 850,
          type: PantrySearchMatchType.exactAlias,
          matchedAlias: alias.original,
        );
      }
    }

    for (final alias in normalizedAliases) {
      if (alias.normalized.startsWith(normalizedQuery)) {
        return PantrySearchMatch(
          score: 800 - _lengthPenalty(alias.normalized, normalizedQuery),
          type: PantrySearchMatchType.prefixAlias,
          matchedAlias: alias.original,
        );
      }
    }

    final nameIndex = normalizedName.indexOf(normalizedQuery);
    if (nameIndex >= 0) {
      return PantrySearchMatch(
        score: 700 - nameIndex,
        type: PantrySearchMatchType.containsName,
      );
    }

    for (final alias in normalizedAliases) {
      final aliasIndex = alias.normalized.indexOf(normalizedQuery);
      if (aliasIndex >= 0) {
        return PantrySearchMatch(
          score: 650 - aliasIndex,
          type: PantrySearchMatchType.containsAlias,
          matchedAlias: alias.original,
        );
      }
    }

    if (normalizedCategory == normalizedQuery) {
      return const PantrySearchMatch(
        score: 600,
        type: PantrySearchMatchType.category,
      );
    }

    if (normalizedCategory.startsWith(normalizedQuery)) {
      return PantrySearchMatch(
        score: 560 - _lengthPenalty(normalizedCategory, normalizedQuery),
        type: PantrySearchMatchType.category,
      );
    }

    if (normalizedCategory.contains(normalizedQuery)) {
      return PantrySearchMatch(
        score: 520 - normalizedCategory.indexOf(normalizedQuery),
        type: PantrySearchMatchType.category,
      );
    }

    final fuzzyNameDistance = _fuzzyDistance(
      candidate: normalizedName,
      query: normalizedQuery,
    );
    if (fuzzyNameDistance != null) {
      return PantrySearchMatch(
        score: 450 - (fuzzyNameDistance * 30),
        type: PantrySearchMatchType.fuzzyName,
      );
    }

    PantrySearchMatch? bestAliasMatch;
    for (final alias in normalizedAliases) {
      final distance = _fuzzyDistance(
        candidate: alias.normalized,
        query: normalizedQuery,
      );
      if (distance == null) {
        continue;
      }

      final currentMatch = PantrySearchMatch(
        score: 420 - (distance * 30),
        type: PantrySearchMatchType.fuzzyAlias,
        matchedAlias: alias.original,
      );

      if (bestAliasMatch == null || currentMatch.score > bestAliasMatch.score) {
        bestAliasMatch = currentMatch;
      }
    }

    return bestAliasMatch ?? const PantrySearchMatch.none();
  }

  static int _lengthPenalty(String candidate, String query) {
    final difference = candidate.runes.length - query.runes.length;
    return difference.clamp(0, 25).toInt();
  }

  static int? _fuzzyDistance({
    required String candidate,
    required String query,
  }) {
    final queryRunes = query.runes.toList(growable: false);
    if (queryRunes.length < 3) {
      return null;
    }

    final candidateRunes = candidate.runes.toList(growable: false);
    final maximumDistance = switch (queryRunes.length) {
      <= 4 => 1,
      <= 8 => 2,
      _ => 3,
    };

    var bestDistance = _levenshteinDistance(candidateRunes, queryRunes);

    if (candidateRunes.length > queryRunes.length) {
      final windowLength = queryRunes.length;
      for (
        var start = 0;
        start <= candidateRunes.length - windowLength;
        start++
      ) {
        final window = candidateRunes.sublist(start, start + windowLength);
        final distance = _levenshteinDistance(window, queryRunes);
        if (distance < bestDistance) {
          bestDistance = distance;
        }
      }
    }

    return bestDistance <= maximumDistance ? bestDistance : null;
  }

  static int _levenshteinDistance(List<int> first, List<int> second) {
    if (first.isEmpty) {
      return second.length;
    }
    if (second.isEmpty) {
      return first.length;
    }

    var previous = List<int>.generate(second.length + 1, (index) => index);

    for (var firstIndex = 0; firstIndex < first.length; firstIndex++) {
      final current = List<int>.filled(second.length + 1, 0);
      current[0] = firstIndex + 1;

      for (var secondIndex = 0; secondIndex < second.length; secondIndex++) {
        final substitutionCost = first[firstIndex] == second[secondIndex]
            ? 0
            : 1;
        final deletion = previous[secondIndex + 1] + 1;
        final insertion = current[secondIndex] + 1;
        final substitution = previous[secondIndex] + substitutionCost;

        current[secondIndex + 1] = _minimum(deletion, insertion, substitution);
      }

      previous = current;
    }

    return previous.last;
  }

  static int _minimum(int first, int second, int third) {
    var minimum = first;
    if (second < minimum) {
      minimum = second;
    }
    if (third < minimum) {
      minimum = third;
    }
    return minimum;
  }
}

class _ScoredCatalogItem {
  const _ScoredCatalogItem({required this.entry, required this.match});

  final FoodCatalogItem entry;
  final PantrySearchMatch match;
}
