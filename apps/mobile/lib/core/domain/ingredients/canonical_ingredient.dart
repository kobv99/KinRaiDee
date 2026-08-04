import '../images/image_metadata.dart';

enum IngredientStorageType { ambient, refrigerated, frozen, pantry }

enum CanonicalIngredientNodeType { category, family, ingredient }

/// Culinary classification of a selectable ingredient, independent of
/// [CanonicalIngredientNodeType]. Only meaningful on `ingredient` nodes —
/// `family`/`category` nodes must never carry one, see the
/// [CanonicalIngredient] constructor.
enum IngredientTaxonomyType {
  generic,
  whole,
  species,
  cut,
  organ,
  form,
  product,
}

enum IngredientUnitFamily {
  liquid,
  fish,
  meat,
  egg,
  garlic,
  vegetable,
  tofu,
  canned,
  dryIngredient,
  generic,
}

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
    this.emoji = '',
    String? preferredUnitId,
    List<String>? recommendedUnitIds,
    this.unitFamily,
    this.parentId,
    this.nodeType = CanonicalIngredientNodeType.ingredient,
    this.taxonomyType,
    this.selectableAsMainIngredient = true,
    List<String> ingredientForms = const <String>[],
    List<String> textures = const <String>[],
    List<String> supportedCookingMethods = const <String>[],
    this.metadata = const IngredientMetadata(),
    this.image,
    this.defaultPantryQuantity,
  }) : localizedNames = Map<String, String>.unmodifiable(localizedNames),
       aliases = List<String>.unmodifiable(aliases),
       searchKeywords = List<String>.unmodifiable(searchKeywords),
       preferredUnitId = preferredUnitId ?? defaultPurchaseUnitId,
       recommendedUnitIds = List<String>.unmodifiable(
         recommendedUnitIds ??
             <String>[preferredUnitId ?? defaultPurchaseUnitId],
       ),
       ingredientForms = List<String>.unmodifiable(ingredientForms),
       textures = List<String>.unmodifiable(textures),
       supportedCookingMethods = List<String>.unmodifiable(
         supportedCookingMethods,
       ) {
    if (nodeType != CanonicalIngredientNodeType.ingredient &&
        taxonomyType != null) {
      throw ArgumentError.value(
        taxonomyType,
        'taxonomyType',
        'Ingredient "$id" has nodeType $nodeType and must not carry a '
            'taxonomyType — only nodeType == ingredient may.',
      );
    }
  }

  final String id;
  final String canonicalName;
  final Map<String, String> localizedNames;
  final List<String> aliases;
  final List<String> searchKeywords;
  final String category;
  final IngredientStorageType defaultStorageType;
  final String defaultPurchaseUnitId;
  final String defaultInventoryUnitId;
  final String emoji;
  final String preferredUnitId;
  final List<String> recommendedUnitIds;
  final IngredientUnitFamily? unitFamily;
  final String? parentId;
  final CanonicalIngredientNodeType nodeType;

  /// Culinary classification; null for `family`/`category` nodes and for
  /// `ingredient` nodes that have not yet been migrated to the taxonomy.
  final IngredientTaxonomyType? taxonomyType;
  final bool selectableAsMainIngredient;
  final List<String> ingredientForms;
  final List<String> textures;
  final List<String> supportedCookingMethods;
  final IngredientMetadata metadata;

  /// Suggested quantity to prefill when adding this ingredient to a pantry.
  /// Always shown and editable — never committed silently.
  final double? defaultPantryQuantity;

  /// Optional presentation image. Family and category nodes may carry one
  /// too, since they are [CanonicalIngredient] records with a different
  /// [nodeType] rather than a separate type — there is exactly one place
  /// image ownership lives. Absent or unapproved must always fall back to
  /// [emoji]; see `resolveImageCandidates`.
  final ImageMetadata? image;

  bool get canSelectAsMainIngredient =>
      selectableAsMainIngredient &&
      nodeType == CanonicalIngredientNodeType.ingredient;

  /// Suggested unit to prefill when adding this ingredient to a pantry.
  /// Computed from [defaultInventoryUnitId] — the unit pantry *quantities*
  /// are actually tracked in — rather than [preferredUnitId], which is a
  /// purchase/recommendation unit (e.g. `kilogram` for something tracked in
  /// `gram`) and would otherwise pair a gram-scale [defaultPantryQuantity]
  /// with a kilogram-scale unit, e.g. "300 kilogram".
  String get defaultPantryUnitId => defaultInventoryUnitId;

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
