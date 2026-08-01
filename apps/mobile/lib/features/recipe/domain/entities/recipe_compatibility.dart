/// Data-owned culinary constraints for matching a selected main ingredient to
/// a Recipe. Canonical hierarchy is deliberately not treated as substitution.
class RecipeCompatibilityMetadata {
  const RecipeCompatibilityMetadata({
    this.exactIngredientIds = const <String>[],
    this.preferredIngredientIds = const <String>[],
    this.compatibleIngredientIds = const <String>[],
    this.substituteIngredientIds = const <String>[],
    this.excludedIngredientIds = const <String>[],
    this.ingredientFamilyIds = const <String>[],
    this.requiredIngredientForms = const <String>[],
    this.allowedIngredientForms = const <String>[],
    this.excludedIngredientForms = const <String>[],
    this.requiredTexture,
    this.cookingMethods = const <String>[],
    this.suitabilityNotes = '',
  });

  final List<String> exactIngredientIds;
  final List<String> preferredIngredientIds;
  final List<String> compatibleIngredientIds;
  final List<String> substituteIngredientIds;
  final List<String> excludedIngredientIds;
  final List<String> ingredientFamilyIds;

  /// JSON accepts either `requiredIngredientForm` or
  /// `requiredIngredientForms`, as a scalar or a list.
  final List<String> requiredIngredientForms;
  final List<String> allowedIngredientForms;
  final List<String> excludedIngredientForms;
  final String? requiredTexture;
  final List<String> cookingMethods;
  final String suitabilityNotes;

  bool get isEmpty =>
      exactIngredientIds.isEmpty &&
      preferredIngredientIds.isEmpty &&
      compatibleIngredientIds.isEmpty &&
      substituteIngredientIds.isEmpty &&
      excludedIngredientIds.isEmpty &&
      ingredientFamilyIds.isEmpty &&
      requiredIngredientForms.isEmpty &&
      allowedIngredientForms.isEmpty &&
      excludedIngredientForms.isEmpty &&
      (requiredTexture == null || requiredTexture!.trim().isEmpty) &&
      cookingMethods.isEmpty &&
      suitabilityNotes.trim().isEmpty;

  factory RecipeCompatibilityMetadata.fromJson(Map<String, dynamic> json) {
    return RecipeCompatibilityMetadata(
      exactIngredientIds: _stringList(json['exactIngredientIds']),
      preferredIngredientIds: _stringList(json['preferredIngredientIds']),
      compatibleIngredientIds: _stringList(json['compatibleIngredientIds']),
      substituteIngredientIds: _stringList(json['substituteIngredientIds']),
      excludedIngredientIds: _stringList(json['excludedIngredientIds']),
      ingredientFamilyIds: _stringList(json['ingredientFamilyIds']),
      requiredIngredientForms: _stringList(
        json['requiredIngredientForms'] ?? json['requiredIngredientForm'],
      ),
      allowedIngredientForms: _stringList(json['allowedIngredientForms']),
      excludedIngredientForms: _stringList(json['excludedIngredientForms']),
      requiredTexture: _nonEmptyString(json['requiredTexture']),
      cookingMethods: _stringList(json['cookingMethods']),
      suitabilityNotes: _nonEmptyString(json['suitabilityNotes']) ?? '',
    );
  }
}

/// Culinary characteristics of the selected ingredient, supplied by data or
/// by a Pantry lot. Unknown characteristics stay unknown; they are not guessed
/// from a canonical parent category.
class IngredientCompatibilityProfile {
  const IngredientCompatibilityProfile({
    this.forms = const <String>[],
    this.texture,
    this.textures = const <String>[],
    this.cookingMethods = const <String>[],
    this.familyIds = const <String>[],
  });

  final List<String> forms;
  final String? texture;
  final List<String> textures;
  final List<String> cookingMethods;
  final List<String> familyIds;
}

class MainIngredientSelection {
  const MainIngredientSelection({
    required this.canonicalIngredientId,
    required this.displayName,
    this.emoji = '🍳',
    this.forms = const <String>[],
    this.texture,
    this.textures = const <String>[],
    this.cookingMethods = const <String>[],
    this.familyIds = const <String>[],
  });

  final String canonicalIngredientId;
  final String displayName;
  final String emoji;
  final List<String> forms;
  final String? texture;
  final List<String> textures;
  final List<String> cookingMethods;
  final List<String> familyIds;

  MainIngredientSelection withProfile(IngredientCompatibilityProfile profile) {
    return MainIngredientSelection(
      canonicalIngredientId: canonicalIngredientId,
      displayName: displayName,
      emoji: emoji,
      forms: forms.isEmpty ? profile.forms : forms,
      texture: texture?.trim().isNotEmpty == true ? texture : profile.texture,
      textures: textures.isEmpty ? profile.textures : textures,
      cookingMethods: cookingMethods.isEmpty
          ? profile.cookingMethods
          : cookingMethods,
      familyIds: familyIds.isEmpty ? profile.familyIds : familyIds,
    );
  }
}

enum MainIngredientMatchTier {
  exact(6),
  preferred(5),
  compatible(4),
  substitute(3),
  family(2);

  const MainIngredientMatchTier(this.priority);

  final int priority;
}

enum MainIngredientExclusionReason {
  explicitlyExcluded,
  incompatibleForm,
  incompatibleTexture,
  incompatibleCookingMethod,
  unverifiedFamily,
  noMatch,
}

class MainIngredientCompatibilityResult {
  const MainIngredientCompatibilityResult._({
    required this.isEligible,
    this.tier,
    this.reason = '',
    this.suitabilityNotes = '',
    this.exclusionReason,
  });

  const MainIngredientCompatibilityResult.eligible({
    required MainIngredientMatchTier tier,
    required String reason,
    String suitabilityNotes = '',
  }) : this._(
         isEligible: true,
         tier: tier,
         reason: reason,
         suitabilityNotes: suitabilityNotes,
       );

  const MainIngredientCompatibilityResult.excluded(
    MainIngredientExclusionReason exclusionReason,
  ) : this._(isEligible: false, exclusionReason: exclusionReason);

  final bool isEligible;
  final MainIngredientMatchTier? tier;

  /// Localized, user-facing explanation. It never exposes enum names or data
  /// keys to presentation code.
  final String reason;
  final String suitabilityNotes;
  final MainIngredientExclusionReason? exclusionReason;

  int get tierPriority => tier?.priority ?? 0;
}

String normalizeCompatibilityToken(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

List<String> _stringList(Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? const <String>[] : <String>[trimmed];
  }
  if (value is! Iterable) {
    return const <String>[];
  }
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _nonEmptyString(Object? value) {
  final trimmed = value?.toString().trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
