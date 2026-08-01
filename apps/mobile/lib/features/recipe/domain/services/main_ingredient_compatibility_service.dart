import '../entities/recipe.dart';
import '../entities/recipe_compatibility.dart';
import '../entities/recipe_ingredient.dart';

class MainIngredientCompatibilityConfig {
  const MainIngredientCompatibilityConfig({
    this.profiles = const <String, IngredientCompatibilityProfile>{},
  });

  final Map<String, IngredientCompatibilityProfile> profiles;

  IngredientCompatibilityProfile? profileFor(String canonicalIngredientId) {
    final key = normalizeCompatibilityToken(canonicalIngredientId);
    for (final entry in profiles.entries) {
      if (normalizeCompatibilityToken(entry.key) == key) {
        return entry.value;
      }
    }
    return null;
  }
}

/// Evaluates culinary suitability independently from Pantry readiness.
///
/// Canonical parent/child relationships are intentionally absent here. A
/// family match is eligible only when Recipe metadata and the selected
/// ingredient profile explicitly name the same family.
class MainIngredientCompatibilityService {
  const MainIngredientCompatibilityService({
    this.config = const MainIngredientCompatibilityConfig(),
  });

  final MainIngredientCompatibilityConfig config;

  MainIngredientSelection enrichSelection(MainIngredientSelection selection) {
    final profile = config.profileFor(selection.canonicalIngredientId);
    return profile == null ? selection : selection.withProfile(profile);
  }

  MainIngredientCompatibilityResult evaluate({
    required Recipe recipe,
    required MainIngredientSelection selection,
  }) {
    final selected = enrichSelection(selection);
    final selectedId = normalizeCompatibilityToken(
      selected.canonicalIngredientId,
    );
    if (selectedId.isEmpty) {
      return const MainIngredientCompatibilityResult.excluded(
        MainIngredientExclusionReason.noMatch,
      );
    }

    final metadata = recipe.compatibility;
    if (_tokens(metadata.excludedIngredientIds).contains(selectedId)) {
      return const MainIngredientCompatibilityResult.excluded(
        MainIngredientExclusionReason.explicitlyExcluded,
      );
    }

    final selectedForms = _tokens(selected.forms);
    final excludedForms = _tokens(metadata.excludedIngredientForms);
    if (selectedForms.intersection(excludedForms).isNotEmpty) {
      return const MainIngredientCompatibilityResult.excluded(
        MainIngredientExclusionReason.incompatibleForm,
      );
    }

    final requiredForms = _tokens(metadata.requiredIngredientForms);
    if (requiredForms.isNotEmpty &&
        selectedForms.intersection(requiredForms).isEmpty) {
      return const MainIngredientCompatibilityResult.excluded(
        MainIngredientExclusionReason.incompatibleForm,
      );
    }

    final allowedForms = _tokens(metadata.allowedIngredientForms);
    if (allowedForms.isNotEmpty &&
        selectedForms.intersection(allowedForms).isEmpty) {
      return const MainIngredientCompatibilityResult.excluded(
        MainIngredientExclusionReason.incompatibleForm,
      );
    }

    final requiredTexture = normalizeCompatibilityToken(
      metadata.requiredTexture ?? '',
    );
    final selectedTextures = _tokens(<String>[
      ...selected.textures,
      if (selected.texture != null) selected.texture!,
    ]);
    if (requiredTexture.isNotEmpty &&
        !selectedTextures.contains(requiredTexture)) {
      return const MainIngredientCompatibilityResult.excluded(
        MainIngredientExclusionReason.incompatibleTexture,
      );
    }

    final tier = _resolveTier(
      recipe: recipe,
      selectedId: selectedId,
      selectionFamilyIds: _tokens(selected.familyIds),
    );
    if (tier == null) {
      return MainIngredientCompatibilityResult.excluded(
        metadata.ingredientFamilyIds.isEmpty
            ? MainIngredientExclusionReason.noMatch
            : MainIngredientExclusionReason.unverifiedFamily,
      );
    }

    // An exact recipe is itself the authoritative statement that its own
    // cooking method works for the named canonical ingredient. Method-profile
    // checks remain a hard gate for preferred, compatible, substitute, and
    // family matches, where suitability is being extended beyond the recipe's
    // exact hero ingredient.
    if (tier != MainIngredientMatchTier.exact) {
      final recipeMethods = _tokens(
        metadata.cookingMethods.isEmpty
            ? recipe.cookingMethods
            : metadata.cookingMethods,
      );
      final ingredientMethods = _tokens(selected.cookingMethods);
      if (recipeMethods.isNotEmpty &&
          ingredientMethods.isNotEmpty &&
          recipeMethods.intersection(ingredientMethods).isEmpty) {
        return const MainIngredientCompatibilityResult.excluded(
          MainIngredientExclusionReason.incompatibleCookingMethod,
        );
      }
    }

    return MainIngredientCompatibilityResult.eligible(
      tier: tier,
      reason: _localizedReason(tier, selected.displayName),
      suitabilityNotes: metadata.suitabilityNotes.trim(),
    );
  }

  MainIngredientMatchTier? _resolveTier({
    required Recipe recipe,
    required String selectedId,
    required Set<String> selectionFamilyIds,
  }) {
    final metadata = recipe.compatibility;
    final exactIds = <String>{
      ..._implicitExactIngredientIds(recipe),
      ..._tokens(metadata.exactIngredientIds),
    };
    if (exactIds.contains(selectedId)) {
      return MainIngredientMatchTier.exact;
    }
    if (_tokens(metadata.preferredIngredientIds).contains(selectedId)) {
      return MainIngredientMatchTier.preferred;
    }
    if (_tokens(metadata.compatibleIngredientIds).contains(selectedId)) {
      return MainIngredientMatchTier.compatible;
    }
    if (_tokens(metadata.substituteIngredientIds).contains(selectedId)) {
      return MainIngredientMatchTier.substitute;
    }

    final supportedFamilies = _tokens(metadata.ingredientFamilyIds);
    if (supportedFamilies.contains(selectedId) ||
        supportedFamilies.intersection(selectionFamilyIds).isNotEmpty) {
      return MainIngredientMatchTier.family;
    }
    return null;
  }

  Set<String> _implicitExactIngredientIds(Recipe recipe) {
    final hero = recipe.heroIngredient;
    final primaryIds = <String>{};
    for (final ingredient in recipe.ingredients) {
      final role = ingredient.effectiveRole(
        isHero: identical(ingredient, hero),
      );
      if (role == RecipeIngredientRole.primary) {
        final id = normalizeCompatibilityToken(ingredient.id);
        if (id.isNotEmpty) {
          primaryIds.add(id);
        }
      }
    }
    final explicitHeroId = normalizeCompatibilityToken(
      recipe.resolvedHeroIngredientId,
    );
    if (explicitHeroId.isNotEmpty) {
      primaryIds.add(explicitHeroId);
    }
    return primaryIds;
  }

  Set<String> _tokens(Iterable<String> values) {
    return values
        .map(normalizeCompatibilityToken)
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  String _localizedReason(MainIngredientMatchTier tier, String displayName) {
    final name = displayName.trim();
    return switch (tier) {
      MainIngredientMatchTier.exact =>
        name.isEmpty ? 'ตรงกับวัตถุดิบหลักโดยตรง' : 'ตรงกับ$nameโดยตรง',
      MainIngredientMatchTier.preferred =>
        name.isEmpty
            ? 'เหมาะเป็นพิเศษกับวัตถุดิบหลักนี้'
            : 'เหมาะเป็นพิเศษกับ$name',
      MainIngredientMatchTier.compatible =>
        name.isEmpty ? 'รองรับวัตถุดิบหลักนี้' : 'รองรับ$name',
      MainIngredientMatchTier.substitute =>
        name.isEmpty ? 'ใช้แทนวัตถุดิบหลักได้' : 'ใช้$nameแทนได้',
      MainIngredientMatchTier.family => 'อยู่ในกลุ่มวัตถุดิบที่สูตรรองรับ',
    };
  }
}
