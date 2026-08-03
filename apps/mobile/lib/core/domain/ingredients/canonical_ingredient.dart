import '../images/image_metadata.dart';

enum IngredientStorageType { ambient, refrigerated, frozen, pantry }

enum CanonicalIngredientNodeType { category, family, ingredient }

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
    this.selectableAsMainIngredient = true,
    List<String> ingredientForms = const <String>[],
    List<String> textures = const <String>[],
    List<String> supportedCookingMethods = const <String>[],
    this.metadata = const IngredientMetadata(),
    this.image,
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
       );

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
  final bool selectableAsMainIngredient;
  final List<String> ingredientForms;
  final List<String> textures;
  final List<String> supportedCookingMethods;
  final IngredientMetadata metadata;

  /// Optional presentation image. Family and category nodes may carry one
  /// too, since they are [CanonicalIngredient] records with a different
  /// [nodeType] rather than a separate type — there is exactly one place
  /// image ownership lives. Absent or unapproved must always fall back to
  /// [emoji]; see `resolveImageCandidates`.
  final ImageMetadata? image;

  bool get canSelectAsMainIngredient =>
      selectableAsMainIngredient &&
      nodeType == CanonicalIngredientNodeType.ingredient;

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
