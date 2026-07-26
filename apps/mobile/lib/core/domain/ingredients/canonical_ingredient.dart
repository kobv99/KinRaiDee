enum IngredientStorageType { ambient, refrigerated, frozen, pantry }

class IngredientMetadata {
  const IngredientMetadata({
    this.schemaVersion = 1,
    this.revision = 1,
    this.source = 'kinraidee',
  });

  final int schemaVersion;
  final int revision;
  final String source;
}

class CanonicalIngredient {
  CanonicalIngredient({
    required this.id,
    required this.canonicalName,
    required Map<String, String> localizedNames,
    required List<String> aliases,
    required List<String> searchKeywords,
    required this.category,
    required this.defaultStorageType,
    required this.defaultPurchaseUnitId,
    required this.defaultInventoryUnitId,
    this.parentId,
    this.metadata = const IngredientMetadata(),
  }) : localizedNames = Map<String, String>.unmodifiable(localizedNames),
       aliases = List<String>.unmodifiable(aliases),
       searchKeywords = List<String>.unmodifiable(searchKeywords);

  final String id;
  final String canonicalName;
  final Map<String, String> localizedNames;
  final List<String> aliases;
  final List<String> searchKeywords;
  final String category;
  final IngredientStorageType defaultStorageType;
  final String defaultPurchaseUnitId;
  final String defaultInventoryUnitId;
  final String? parentId;
  final IngredientMetadata metadata;

  Iterable<String> get searchableNames sync* {
    yield canonicalName;
    yield* localizedNames.values;
    yield* aliases;
    yield* searchKeywords;
  }

  String displayName([String locale = 'th']) {
    return localizedNames[locale] ?? canonicalName;
  }
}
