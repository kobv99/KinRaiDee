import 'canonical_ingredient.dart';

enum CanonicalMatchType {
  canonicalId,
  canonicalName,
  localizedName,
  alias,
  keyword,
  redirectedId,
  unknown,
  ambiguous,
}

class CanonicalIngredientResolution {
  const CanonicalIngredientResolution({
    required this.input,
    required this.normalizedInput,
    required this.matchType,
    this.ingredient,
    this.candidateIds = const <String>[],
  });

  final String input;
  final String normalizedInput;
  final CanonicalMatchType matchType;
  final CanonicalIngredient? ingredient;
  final List<String> candidateIds;

  bool get isResolved => ingredient != null;
}

class CanonicalRegistryException implements Exception {
  const CanonicalRegistryException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'CanonicalRegistryException($code): $message';
}

class CanonicalIngredientRegistry {
  CanonicalIngredientRegistry({
    required Iterable<CanonicalIngredient> ingredients,
    Map<String, String> redirects = const <String, String>{},
    Map<String, List<String>> supplementalAliases =
        defaultSupplementalIngredientAliases,
    this.version = 1,
  }) {
    for (final ingredient in ingredients) {
      _register(ingredient);
    }
    _registerRedirects(redirects);
    _validateParents();
    _buildSearchIndex(supplementalAliases);
  }

  final int version;
  final Map<String, CanonicalIngredient> _byId =
      <String, CanonicalIngredient>{};
  final Map<String, String> _redirects = <String, String>{};
  final Map<String, Set<String>> _canonicalNames = <String, Set<String>>{};
  final Map<String, Set<String>> _localizedNames = <String, Set<String>>{};
  final Map<String, Set<String>> _aliases = <String, Set<String>>{};
  final Map<String, Set<String>> _keywords = <String, Set<String>>{};

  List<CanonicalIngredient> get ingredients {
    final redirected = _redirects.keys.toSet();
    final values =
        _byId.values
            .where((ingredient) => !redirected.contains(ingredient.id))
            .toList()
          ..sort((first, second) => first.id.compareTo(second.id));
    return List<CanonicalIngredient>.unmodifiable(values);
  }

  CanonicalIngredient? byId(String id) {
    final canonicalId = canonicalIdFor(id);
    return canonicalId == null ? null : _byId[canonicalId];
  }

  String? canonicalIdFor(String id) {
    final normalized = normalizeCanonicalIngredientId(id);
    if (!_byId.containsKey(normalized)) {
      return null;
    }
    var current = normalized;
    final visited = <String>{};
    while (_redirects.containsKey(current)) {
      if (!visited.add(current)) {
        throw CanonicalRegistryException(
          'circular_ingredient_redirect',
          'Circular ingredient redirect at $current.',
        );
      }
      current = _redirects[current]!;
    }
    return current;
  }

  CanonicalIngredientResolution resolve(String value, {String? preferredId}) {
    final normalized = normalizeIngredientKey(value);
    final preferredCanonicalId = preferredId == null
        ? null
        : canonicalIdFor(preferredId);
    if (preferredCanonicalId != null) {
      final direct = _byId[preferredCanonicalId]!;
      return CanonicalIngredientResolution(
        input: value,
        normalizedInput: normalized,
        matchType: preferredId == preferredCanonicalId
            ? CanonicalMatchType.canonicalId
            : CanonicalMatchType.redirectedId,
        ingredient: direct,
      );
    }

    final directId = canonicalIdFor(normalized);
    if (directId != null) {
      return CanonicalIngredientResolution(
        input: value,
        normalizedInput: normalized,
        matchType: directId == normalized
            ? CanonicalMatchType.canonicalId
            : CanonicalMatchType.redirectedId,
        ingredient: _byId[directId],
      );
    }

    final indexes = <(Map<String, Set<String>>, CanonicalMatchType)>[
      (_canonicalNames, CanonicalMatchType.canonicalName),
      (_localizedNames, CanonicalMatchType.localizedName),
      (_aliases, CanonicalMatchType.alias),
      (_keywords, CanonicalMatchType.keyword),
    ];
    for (final (index, matchType) in indexes) {
      final matches = index[normalized];
      if (matches == null || matches.isEmpty) {
        continue;
      }
      final canonicalMatches =
          matches.map(canonicalIdFor).whereType<String>().toSet().toList()
            ..sort();
      if (canonicalMatches.length == 1) {
        return CanonicalIngredientResolution(
          input: value,
          normalizedInput: normalized,
          matchType: matchType,
          ingredient: _byId[canonicalMatches.single],
        );
      }
      return CanonicalIngredientResolution(
        input: value,
        normalizedInput: normalized,
        matchType: CanonicalMatchType.ambiguous,
        candidateIds: List<String>.unmodifiable(canonicalMatches),
      );
    }

    return CanonicalIngredientResolution(
      input: value,
      normalizedInput: normalized,
      matchType: CanonicalMatchType.unknown,
    );
  }

  bool areCompatibleIds(String firstId, String secondId) {
    final first = canonicalIdFor(firstId);
    final second = canonicalIdFor(secondId);
    if (first == null || second == null) {
      return false;
    }
    if (first == second) {
      return true;
    }
    return _ancestorIds(first).contains(second) ||
        _ancestorIds(second).contains(first);
  }

  /// Returns the canonical hierarchy path above [id] without implying that
  /// every ancestor is a valid culinary substitute. Recommendation matching
  /// may use these IDs only when a recipe explicitly opts in to a family.
  Set<String> ancestorIdsFor(String id) {
    final canonicalId = canonicalIdFor(id);
    if (canonicalId == null) {
      return const <String>{};
    }
    return Set<String>.unmodifiable(_ancestorIds(canonicalId));
  }

  List<String> missingMappings(Iterable<String> values) {
    return values
        .where((value) => !resolve(value).isResolved)
        .toSet()
        .toList(growable: false)
      ..sort();
  }

  String unmappedIdFor(String value) {
    final normalized = normalizeIngredientKey(value);
    final hash = _fnv1a64(normalized);
    return 'unmapped_${hash.toRadixString(16).padLeft(16, '0')}';
  }

  void _register(CanonicalIngredient ingredient) {
    final id = normalizeCanonicalIngredientId(ingredient.id);
    if (id.isEmpty || id != ingredient.id) {
      throw CanonicalRegistryException(
        'invalid_ingredient_id',
        'Ingredient ID "${ingredient.id}" must already be normalized.',
      );
    }
    if (_byId.containsKey(id)) {
      throw CanonicalRegistryException(
        'duplicate_ingredient_id',
        'Duplicate ingredient ID: $id',
      );
    }
    if (ingredient.canonicalName.trim().isEmpty ||
        ingredient.category.trim().isEmpty ||
        ingredient.defaultPurchaseUnitId.trim().isEmpty ||
        ingredient.defaultInventoryUnitId.trim().isEmpty ||
        ingredient.preferredUnitId.trim().isEmpty ||
        ingredient.recommendedUnitIds.isEmpty ||
        ingredient.recommendedUnitIds.any((unitId) => unitId.trim().isEmpty) ||
        ingredient.recommendedUnitIds.toSet().length !=
            ingredient.recommendedUnitIds.length ||
        !ingredient.recommendedUnitIds.contains(ingredient.preferredUnitId) ||
        ingredient.metadata.schemaVersion < 1 ||
        ingredient.metadata.revision < 1) {
      throw CanonicalRegistryException(
        'invalid_ingredient_definition',
        'Ingredient $id is missing required canonical metadata.',
      );
    }
    _byId[id] = ingredient;
  }

  void _registerRedirects(Map<String, String> redirects) {
    for (final entry in redirects.entries) {
      final source = normalizeCanonicalIngredientId(entry.key);
      final target = normalizeCanonicalIngredientId(entry.value);
      if (!_byId.containsKey(source) || !_byId.containsKey(target)) {
        throw CanonicalRegistryException(
          'invalid_ingredient_redirect',
          'Redirect $source -> $target references an unknown ID.',
        );
      }
      _redirects[source] = target;
      canonicalIdFor(source);
    }
  }

  void _validateParents() {
    for (final ingredient in _byId.values) {
      final parent = ingredient.parentId;
      if (parent != null && canonicalIdFor(parent) == null) {
        throw CanonicalRegistryException(
          'missing_parent_ingredient',
          'Ingredient ${ingredient.id} references missing parent $parent.',
        );
      }
    }
  }

  void _buildSearchIndex(Map<String, List<String>> supplementalAliases) {
    for (final ingredient in _byId.values) {
      _add(_canonicalNames, ingredient.canonicalName, ingredient.id);
      for (final value in ingredient.localizedNames.values) {
        _add(_localizedNames, value, ingredient.id);
      }
      for (final value in ingredient.aliases) {
        _add(_aliases, value, ingredient.id);
      }
      for (final value in ingredient.searchKeywords) {
        _add(_keywords, value, ingredient.id);
      }
      for (final value in supplementalAliases[ingredient.id] ?? const []) {
        _add(_aliases, value, ingredient.id);
      }
    }
  }

  Set<String> _ancestorIds(String id) {
    final result = <String>{};
    var current = _byId[id];
    while (current?.parentId != null) {
      final parentId = canonicalIdFor(current!.parentId!);
      if (parentId == null || !result.add(parentId)) {
        break;
      }
      current = _byId[parentId];
    }
    return result;
  }

  void _add(Map<String, Set<String>> index, String value, String id) {
    final normalized = normalizeIngredientKey(value);
    if (normalized.isNotEmpty) {
      index.putIfAbsent(normalized, () => <String>{}).add(id);
    }
  }
}

String normalizeIngredientKey(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String normalizeCanonicalIngredientId(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s-]+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_]+'), '')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

BigInt _fnv1a64(String value) {
  final offset = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = (BigInt.one << 64) - BigInt.one;
  var hash = offset;
  for (final codeUnit in value.codeUnits) {
    hash ^= BigInt.from(codeUnit);
    hash = (hash * prime) & mask;
  }
  return hash;
}

const Map<String, List<String>> defaultSupplementalIngredientAliases =
    <String, List<String>>{
      'chicken': <String>['Chicken'],
      'chicken_breast': <String>[
        'Chicken Breast',
        'Chicken breast',
        'Boneless Chicken Breast',
        'อกไก่',
      ],
    };

const Map<String, String> defaultCanonicalIngredientRedirects =
    <String, String>{};
