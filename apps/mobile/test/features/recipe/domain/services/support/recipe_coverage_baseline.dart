// Test-only support library for the Phase 2 Recipe Coverage Baseline audit.
//
// This file contains no test assertions itself — it is pure data-building
// and rendering logic, exercised entirely through real production services
// (MainIngredientCompatibilityService, RecipeCandidateService.
// evaluateAllRecipes — itself built on RecipeReadinessService) supplied by
// the caller. It never re-implements compatibility/tier/placement decisions
// itself; it only aggregates, classifies, and renders results those
// services produce. SmartRecommendationEngine placement is cross-checked
// separately, against a small deterministic sample, by the test file — not
// by this library — to avoid an O(ingredients^2 x recipes) full sweep.
import 'dart:convert';

import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/models/ingredient.dart' as pantry_model;
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_compatibility.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/services/main_ingredient_compatibility_service.dart';
import 'package:mobile/features/recipe/domain/services/recipe_candidate_service.dart';

/// All exclusion reasons tracked and reported as a separate diagnostic
/// overlay — never as a primary coverage classification (see
/// [CoverageClassification]).
const List<MainIngredientExclusionReason> allExclusionReasons = [
  MainIngredientExclusionReason.explicitlyExcluded,
  MainIngredientExclusionReason.incompatibleForm,
  MainIngredientExclusionReason.incompatibleTexture,
  MainIngredientExclusionReason.incompatibleCookingMethod,
  MainIngredientExclusionReason.unverifiedFamily,
  MainIngredientExclusionReason.noMatch,
];

/// The three profile dimensions a `incompatible*` exclusion reason can be
/// routed against, to distinguish a genuine authored constraint mismatch
/// from an incidental "the canonical ingredient has no data on this
/// dimension" default. Keys used throughout the constraint-mismatch /
/// profile-incomplete maps below.
const List<String> profileDimensions = ['form', 'texture', 'cookingMethod'];

/// A recipe/ingredient pair is EXPLICIT_ID_BLOCK only when
/// [MainIngredientCompatibilityService.evaluate] returns
/// [MainIngredientExclusionReason.explicitlyExcluded] — the ingredient's id
/// literally appears in that recipe's `excludedIngredientIds`. This is the
/// one exclusion reason that is unambiguous by construction: it is always
/// an ingredient-specific, deliberately authored decision, independent of
/// any canonical profile data.
///
/// A pair is CONSTRAINT_MISMATCH when the reason is incompatibleForm /
/// incompatibleTexture / incompatibleCookingMethod *and* the canonical
/// ingredient's corresponding profile field (ingredientForms / textures /
/// supportedCookingMethods) is non-empty — profile data exists and
/// genuinely conflicts with the recipe's stated constraint.
///
/// A pair is PROFILE_INCOMPLETE when the same three reasons fire *and* the
/// corresponding profile field is empty — production correctly excluded
/// the pair under its strict "no data means no match" policy, but this
/// audit cannot infer a deliberate authoring decision, because there was
/// no data to conflict with in the first place.
///
/// Production's own exclusion-reason enum cannot distinguish
/// CONSTRAINT_MISMATCH from PROFILE_INCOMPLETE — both surface as the same
/// `incompatibleForm`/`incompatibleTexture`/`incompatibleCookingMethod`
/// value regardless of cause (see
/// lib/features/recipe/domain/services/main_ingredient_compatibility_service.dart).
/// This overlay draws the distinction using canonical profile fields the
/// builder already has direct access to; it never changes production
/// behavior and never changes [CoverageClassification].
enum ExclusionOverlayCategory {
  explicitIdBlock,
  constraintMismatch,
  profileIncomplete,
}

/// Normalizes every value (via the same `normalizeCompatibilityToken`
/// production uses), drops empties, de-duplicates, and sorts — the shared
/// shape every recipe-metadata id/token list in this report is rendered in.
List<String> _normSortedUnique(Iterable<String> raw) {
  final unique = raw
      .map(normalizeCompatibilityToken)
      .where((value) => value.isNotEmpty)
      .toSet();
  return unique.toList()..sort();
}

/// Primary coverage classification — based **only** on eligible tiers
/// (exact/preferred/compatible/substitute/family). Exclusion reasons
/// (including `unverifiedFamily` and `noMatch`) are a separate diagnostic
/// overlay (see [IngredientCoverageRow.exclusionReasonCounts] and the
/// [ExclusionOverlayCategory] EXPLICIT_ID_BLOCK / CONSTRAINT_MISMATCH /
/// PROFILE_INCOMPLETE split) and never change which of these three buckets
/// an ingredient falls into.
enum CoverageClassification { directCoverage, adaptableOnly, noCoverage }

String classificationLabel(CoverageClassification value) => switch (value) {
  CoverageClassification.directCoverage => 'DIRECT_COVERAGE',
  CoverageClassification.adaptableOnly => 'ADAPTABLE_ONLY',
  CoverageClassification.noCoverage => 'NO_COVERAGE',
};

class IngredientCoverageRow {
  IngredientCoverageRow({
    required this.canonicalId,
    required this.displayName,
    required this.category,
    required this.taxonomyType,
    required this.parentId,
    required this.rootId,
    required this.exact,
    required this.preferred,
    required this.compatible,
    required this.substitute,
    required this.family,
    required this.exclusionReasonCounts,
    required this.ingredientForms,
    required this.textures,
    required this.supportedCookingMethods,
    required this.explicitIdBlockPairCount,
    required this.constraintMismatchPairCounts,
    required this.profileIncompletePairCounts,
    required this.sampleDirectRecipeIds,
    required this.sampleAdaptableRecipeIds,
    required this.classification,
  });

  final String canonicalId;
  final String displayName;
  final String category;
  final String taxonomyType;
  final String parentId;
  final String rootId;
  final int exact;
  final int preferred;
  final int compatible;
  final int substitute;
  final int family;

  /// Counts for all six [MainIngredientExclusionReason] values, keyed by
  /// `.name` — diagnostic only, never used to derive [classification].
  final Map<String, int> exclusionReasonCounts;

  /// This ingredient's own canonical profile, as supplied to
  /// [MainIngredientCompatibilityConfig] — rendered for report readers so
  /// the CONSTRAINT_MISMATCH / PROFILE_INCOMPLETE split below is visibly
  /// explainable without reading source code.
  final List<String> ingredientForms;
  final List<String> textures;
  final List<String> supportedCookingMethods;

  /// Pairs where the reason was explicitlyExcluded — always
  /// ingredient-specific and deliberate; see [ExclusionOverlayCategory].
  final int explicitIdBlockPairCount;

  /// Pairs where an incompatible* reason fired *and* the corresponding
  /// profile field (keyed by [profileDimensions]: 'form'/'texture'/
  /// 'cookingMethod') was non-empty — a genuine authored conflict.
  final Map<String, int> constraintMismatchPairCounts;

  /// Pairs where an incompatible* reason fired *and* the corresponding
  /// profile field was empty — production's strict default, not a
  /// deliberate rejection of this ingredient.
  final Map<String, int> profileIncompletePairCounts;

  final List<String> sampleDirectRecipeIds;
  final List<String> sampleAdaptableRecipeIds;
  final CoverageClassification classification;

  int get directRecipeCount => exact + preferred + compatible + substitute;

  int get adaptableRecipeCount => family;

  int get constraintMismatchTotal =>
      constraintMismatchPairCounts.values.fold(0, (a, b) => a + b);

  int get profileIncompleteTotal =>
      profileIncompletePairCounts.values.fold(0, (a, b) => a + b);

  bool get hasExplicitIdBlock => explicitIdBlockPairCount > 0;

  bool get hasConstraintMismatch => constraintMismatchTotal > 0;

  bool get hasProfileIncomplete => profileIncompleteTotal > 0;
}

class RecipeMetadataRow {
  const RecipeMetadataRow({
    required this.recipeId,
    required this.name,
    required this.pack,
    required this.heroIngredientId,
    required this.implicitExactIds,
    required this.explicitExactIds,
    required this.preferredIds,
    required this.compatibleIds,
    required this.substituteIds,
    required this.familyIds,
    required this.excludedIds,
    required this.requiredForms,
    required this.allowedForms,
    required this.excludedForms,
    required this.requiredTexture,
    required this.cookingMethods,
    required this.hasSuitabilityNotes,
  });

  final String recipeId;
  final String name;
  final String pack;
  final String heroIngredientId;
  final List<String> implicitExactIds;
  final List<String> explicitExactIds;
  final List<String> preferredIds;
  final List<String> compatibleIds;
  final List<String> substituteIds;
  final List<String> familyIds;
  final List<String> excludedIds;
  final List<String> requiredForms;
  final List<String> allowedForms;
  final List<String> excludedForms;
  final String requiredTexture;
  final List<String> cookingMethods;
  final bool hasSuitabilityNotes;
}

class IntegrityIssue {
  const IntegrityIssue({
    required this.code,
    required this.recipeId,
    required this.field,
    required this.value,
    required this.detail,
  });

  final String code;
  final String recipeId;
  final String field;
  final String value;
  final String detail;

  Map<String, dynamic> toJson() => {
    'code': code,
    'recipeId': recipeId,
    'field': field,
    'value': value,
    'detail': detail,
  };
}

class AsymmetryRow {
  const AsymmetryRow({
    required this.canonicalId,
    required this.displayName,
    required this.taxonomyType,
    required this.parentId,
    required this.rootId,
    required this.relationship,
    required this.counterpartId,
    required this.counterpartDisplayName,
    required this.counterpartDirectTierCounts,
    required this.childDirectTierCounts,
    required this.childFamilyCount,
    required this.sampleCounterpartRecipeIds,
  });

  final String canonicalId;
  final String displayName;
  final String taxonomyType;
  final String parentId;
  final String rootId;

  /// 'true_ancestor' (found via registry.ancestorIdsFor and is itself a
  /// selectable ingredient) or 'generic_sibling' (shares this ingredient's
  /// immediate parentId and has taxonomyType == generic). The taxonomy in
  /// this registry parents specific cuts/species directly under a *_family
  /// node, as siblings of the generic — not under the generic itself — so
  /// 'generic_sibling' is expected to be the common case; see the
  /// methodology note in the rendered report.
  final String relationship;
  final String counterpartId;
  final String counterpartDisplayName;
  final Map<String, int> counterpartDirectTierCounts;
  final Map<String, int> childDirectTierCounts;
  final int childFamilyCount;
  final List<String> sampleCounterpartRecipeIds;
}

class DatasetSummary {
  const DatasetSummary({
    required this.totalRegistryNodes,
    required this.selectableMainIngredientCount,
    required this.familyOrCategoryNodeCount,
    required this.totalRecipeCount,
    required this.recipeCountByPack,
    required this.recipeCountByHeroCanonicalId,
  });

  final int totalRegistryNodes;
  final int selectableMainIngredientCount;
  final int familyOrCategoryNodeCount;
  final int totalRecipeCount;
  final Map<String, int> recipeCountByPack;
  final Map<String, int> recipeCountByHeroCanonicalId;
}

/// Primary coverage counts — [directCoverageCount] + [adaptableOnlyCount] +
/// [noCoverageCount] always equals the total selectable-ingredient count.
/// No exclusion reason (including `unverifiedFamily`) participates here.
class CoverageSummary {
  const CoverageSummary({
    required this.directCoverageCount,
    required this.adaptableOnlyCount,
    required this.noCoverageCount,
    required this.ingredientsWithExact,
    required this.ingredientsWithPreferred,
    required this.ingredientsWithCompatible,
    required this.ingredientsWithSubstitute,
    required this.ingredientsWithFamily,
    required this.totalExactPairs,
    required this.totalPreferredPairs,
    required this.totalCompatiblePairs,
    required this.totalSubstitutePairs,
    required this.totalFamilyPairs,
  });

  final int directCoverageCount;
  final int adaptableOnlyCount;
  final int noCoverageCount;
  final int ingredientsWithExact;
  final int ingredientsWithPreferred;
  final int ingredientsWithCompatible;
  final int ingredientsWithSubstitute;
  final int ingredientsWithFamily;
  final int totalExactPairs;
  final int totalPreferredPairs;
  final int totalCompatiblePairs;
  final int totalSubstitutePairs;
  final int totalFamilyPairs;
}

/// Exclusion-reason overlay — reported for awareness alongside
/// [CoverageSummary], never folded into it. `unverifiedFamily` and
/// `noMatch` are tracked in [ingredientCountByReason]/[totalPairsByReason]
/// exactly like the other four reasons; they simply never route into
/// [explicitIdBlockPairCount], [constraintMismatchPairCountByDimension], or
/// [profileIncompletePairCountByDimension].
class ExclusionDiagnostics {
  const ExclusionDiagnostics({
    required this.ingredientCountByReason,
    required this.totalPairsByReason,
    required this.explicitIdBlockIngredientCount,
    required this.explicitIdBlockPairCount,
    required this.constraintMismatchIngredientCount,
    required this.constraintMismatchPairCountByDimension,
    required this.profileIncompleteIngredientCount,
    required this.profileIncompletePairCountByDimension,
  });

  /// Per reason name: number of distinct ingredients with at least one
  /// recipe evaluating to that reason. Raw, un-split — still includes
  /// unverifiedFamily/noMatch, which have no overlay category.
  final Map<String, int> ingredientCountByReason;

  /// Per reason name: total ingredient-recipe pairs evaluating to that
  /// reason, summed across every selectable ingredient.
  final Map<String, int> totalPairsByReason;

  /// Dataset-wide EXPLICIT_ID_BLOCK totals (== the explicitlyExcluded row
  /// of [ingredientCountByReason]/[totalPairsByReason]; kept separately for
  /// clarity since it is a named overlay category, not just a raw reason).
  final int explicitIdBlockIngredientCount;
  final int explicitIdBlockPairCount;

  /// Dataset-wide CONSTRAINT_MISMATCH totals: ingredients with >=1
  /// constraint-mismatch pair on any dimension, and pair counts broken
  /// down by [profileDimensions] ('form'/'texture'/'cookingMethod').
  final int constraintMismatchIngredientCount;
  final Map<String, int> constraintMismatchPairCountByDimension;

  /// Dataset-wide PROFILE_INCOMPLETE totals, same shape.
  final int profileIncompleteIngredientCount;
  final Map<String, int> profileIncompletePairCountByDimension;
}

/// Optional, informational grouping of integrity issues that share the same
/// (code, field, value) and whose affected recipes all belong to a single
/// recipe pack — a strong signal (though not a proof, since
/// [RecipePackParser] flattens pack-level defaults into each parsed
/// [Recipe] before this builder ever sees them, so no literal provenance
/// survives) that one shared pack-level default is the true root cause,
/// and that a content fix likely needs to happen once, not once per
/// affected recipe. Never used to suppress or weaken the underlying
/// per-recipe [IntegrityIssue] entries — those remain complete and
/// unchanged.
class IntegrityIssueGroup {
  const IntegrityIssueGroup({
    required this.code,
    required this.field,
    required this.value,
    required this.manifestationCount,
    required this.affectedRecipeIds,
    required this.sourceScope,
    required this.probableSourceFile,
  });

  final String code;
  final String field;
  final String value;
  final int manifestationCount;
  final List<String> affectedRecipeIds;

  /// 'pack_default_likely' when every affected recipe belongs to the same
  /// pack (see class doc for why this is "likely", not certain);
  /// 'mixed_or_unknown' otherwise.
  final String sourceScope;

  /// Populated only when [sourceScope] == 'pack_default_likely'.
  final String? probableSourceFile;
}

class ReviewItem {
  const ReviewItem({
    required this.priority,
    required this.canonicalId,
    required this.summary,
  });

  final String priority;
  final String canonicalId;
  final String summary;
}

class RecipeCoverageBaselineDataset {
  const RecipeCoverageBaselineDataset({
    required this.dataset,
    required this.coverage,
    required this.exclusionDiagnostics,
    required this.ingredientRows,
    required this.recipeRows,
    required this.integrityIssues,
    required this.integrityIssueGroups,
    required this.asymmetryRows,
    required this.reviewQueue,
    required this.unknownFormTokens,
    required this.unknownCookingMethodTokens,
    required this.orphanCanonicalCookingMethodTokens,
  });

  final DatasetSummary dataset;
  final CoverageSummary coverage;
  final ExclusionDiagnostics exclusionDiagnostics;
  final List<IngredientCoverageRow> ingredientRows;
  final List<RecipeMetadataRow> recipeRows;
  final List<IntegrityIssue> integrityIssues;
  final List<IntegrityIssueGroup> integrityIssueGroups;
  final List<AsymmetryRow> asymmetryRows;
  final List<ReviewItem> reviewQueue;
  final List<String> unknownFormTokens;
  final List<String> unknownCookingMethodTokens;
  final List<String> orphanCanonicalCookingMethodTokens;
}

/// Builds the full baseline dataset using only the real production services
/// supplied by the caller. Every (selectable ingredient x recipe) pair is
/// evaluated exactly once through
/// [MainIngredientCompatibilityService.evaluate] — the exact method
/// production uses — built with a [MainIngredientCompatibilityConfig] the
/// caller must construct exactly as `recipe_provider.dart` does
/// (forms/textures/cookingMethods from the ingredient definition, familyIds
/// from `registry.ancestorIdsFor`). This is the single authoritative
/// selectable-ingredient x recipe matrix; it is O(ingredients x recipes),
/// not O(ingredients^2 x recipes).
///
/// `SmartRecommendationEngine` placement is deliberately **not** exercised
/// here — a full per-ingredient `build()` call is itself
/// O(ingredients x recipes) internally (it re-evaluates every other
/// selectable ingredient's candidacy to build hero options), so calling it
/// once per ingredient here would reintroduce an O(ingredients^2 x recipes)
/// cost. The engine is cross-checked separately, against a small
/// deterministic sample, by the test file.
RecipeCoverageBaselineDataset buildRecipeCoverageBaselineDataset({
  required CanonicalIngredientRegistry registry,
  required List<Recipe> recipes,
  required Map<String, String> recipePackByRecipeId,
  required MainIngredientCompatibilityService compatibilityService,
  required RecipeCandidateService candidateService,
}) {
  final sortedRecipes = [...recipes]..sort((a, b) => a.id.compareTo(b.id));
  final allNodes = registry.ingredients;
  final selectable = allNodes.where((i) => i.canSelectAsMainIngredient).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  final familyOrCategoryCount = allNodes
      .where(
        (i) =>
            i.nodeType == CanonicalIngredientNodeType.family ||
            i.nodeType == CanonicalIngredientNodeType.category,
      )
      .length;

  // Precompute per-ingredient roots once (dynamic, never hardcoded).
  final rootIdByCanonicalId = <String, String>{};
  for (final ingredient in allNodes) {
    final chain = registry.ancestorChainFor(ingredient.id);
    rootIdByCanonicalId[ingredient.id] = chain.isEmpty ? '' : chain.first;
  }

  // ---- Recipe metadata rows + hero-reference / metadata integrity ----
  final recipeRows = <RecipeMetadataRow>[];
  final integrityIssues = <IntegrityIssue>[];
  final recipeIdCounts = <String, int>{};
  final recipeCountByHero = <String, int>{};
  final formVocabularyFromIngredients = <String>{
    for (final i in allNodes) ...i.ingredientForms,
  };
  final cookingMethodVocabularyFromIngredients = <String>{
    for (final i in allNodes) ...i.supportedCookingMethods,
  };
  final cookingMethodVocabularyFromRecipes = <String>{};
  final formTokensSeenInRecipes = <String>{};

  for (final recipe in sortedRecipes) {
    recipeIdCounts.update(recipe.id, (v) => v + 1, ifAbsent: () => 1);
    final pack = recipePackByRecipeId[recipe.id] ?? '';
    final metadata = recipe.compatibility;

    final hero = recipe.heroIngredient;
    final implicitExact = <String>{};
    for (final ingredient in recipe.ingredients) {
      final role = ingredient.effectiveRole(
        isHero: identical(ingredient, hero),
      );
      if (role == RecipeIngredientRole.primary) {
        final id = normalizeCompatibilityToken(ingredient.id);
        if (id.isNotEmpty) implicitExact.add(id);
      }
    }
    final heroId = normalizeCompatibilityToken(recipe.resolvedHeroIngredientId);
    if (heroId.isNotEmpty) implicitExact.add(heroId);

    if (heroId.isEmpty) {
      integrityIssues.add(
        IntegrityIssue(
          code: 'invalid_hero_reference',
          recipeId: recipe.id,
          field: 'heroIngredientId',
          value: heroId,
          detail: 'Recipe has no resolvable hero/primary ingredient.',
        ),
      );
    } else if (registry.canonicalIdFor(heroId) == null) {
      integrityIssues.add(
        IntegrityIssue(
          code: 'invalid_hero_reference',
          recipeId: recipe.id,
          field: 'heroIngredientId',
          value: heroId,
          detail: 'Hero ingredient id does not resolve to any canonical node.',
        ),
      );
    }
    recipeCountByHero.update(heroId, (v) => v + 1, ifAbsent: () => 1);

    // One shared checker for both "must resolve to a selectable ingredient"
    // fields and the "must resolve to a family node" field: same duplicate
    // detection, same missing-id handling, different validity predicate.
    void checkRefs(
      String field,
      List<String> rawIds, {
      required bool Function(CanonicalIngredient) isValid,
      required String invalidCode,
      required String Function(CanonicalIngredient) invalidDetail,
    }) {
      final seen = <String>{};
      for (final raw in rawIds) {
        final id = normalizeCompatibilityToken(raw);
        if (id.isEmpty) continue;
        if (!seen.add(id)) {
          integrityIssues.add(
            IntegrityIssue(
              code: 'duplicate_metadata_reference',
              recipeId: recipe.id,
              field: field,
              value: id,
              detail: 'Duplicate normalized id within $field.',
            ),
          );
          continue;
        }
        final resolved = registry.byId(id);
        if (resolved == null || !isValid(resolved)) {
          integrityIssues.add(
            IntegrityIssue(
              code: invalidCode,
              recipeId: recipe.id,
              field: field,
              value: id,
              detail: resolved == null
                  ? 'Id does not resolve to any canonical node.'
                  : invalidDetail(resolved),
            ),
          );
        }
      }
    }

    bool isSelectable(CanonicalIngredient i) => i.canSelectAsMainIngredient;
    String nonSelectableDetail(CanonicalIngredient i) =>
        'Id resolves to a non-selectable node (nodeType=${i.nodeType.name}).';
    for (final entry in <String, List<String>>{
      'exactIngredientIds': metadata.exactIngredientIds,
      'preferredIngredientIds': metadata.preferredIngredientIds,
      'compatibleIngredientIds': metadata.compatibleIngredientIds,
      'substituteIngredientIds': metadata.substituteIngredientIds,
      'excludedIngredientIds': metadata.excludedIngredientIds,
    }.entries) {
      checkRefs(
        entry.key,
        entry.value,
        isValid: isSelectable,
        invalidCode: 'invalid_canonical_reference',
        invalidDetail: nonSelectableDetail,
      );
    }
    checkRefs(
      'ingredientFamilyIds',
      metadata.ingredientFamilyIds,
      isValid: (i) => i.nodeType == CanonicalIngredientNodeType.family,
      invalidCode: 'invalid_family_reference',
      invalidDetail: (i) =>
          'Id resolves to a non-family node (nodeType=${i.nodeType.name}).',
    );

    // Conflicting metadata: same normalized id claimed by more than one of
    // the five eligibility/exclusion fields on the same recipe.
    final fieldsForConflictCheck = <String, List<String>>{
      'exactIngredientIds': metadata.exactIngredientIds,
      'preferredIngredientIds': metadata.preferredIngredientIds,
      'compatibleIngredientIds': metadata.compatibleIngredientIds,
      'substituteIngredientIds': metadata.substituteIngredientIds,
      'excludedIngredientIds': metadata.excludedIngredientIds,
    };
    final idToFields = <String, Set<String>>{};
    for (final entry in fieldsForConflictCheck.entries) {
      for (final raw in entry.value) {
        final id = normalizeCompatibilityToken(raw);
        if (id.isEmpty) continue;
        idToFields.putIfAbsent(id, () => <String>{}).add(entry.key);
      }
    }
    for (final entry in idToFields.entries) {
      if (entry.value.length > 1) {
        final fields = entry.value.toList()..sort();
        integrityIssues.add(
          IntegrityIssue(
            code: 'conflicting_metadata',
            recipeId: recipe.id,
            field: fields.join('+'),
            value: entry.key,
            detail:
                'Id appears in more than one eligibility/exclusion field: '
                '${fields.join(', ')}.',
          ),
        );
      }
    }

    final requiredForms = _normSortedUnique(metadata.requiredIngredientForms);
    final allowedForms = _normSortedUnique(metadata.allowedIngredientForms);
    final excludedForms = _normSortedUnique(metadata.excludedIngredientForms);
    formTokensSeenInRecipes
      ..addAll(requiredForms)
      ..addAll(allowedForms)
      ..addAll(excludedForms);

    final recipeMethods = _normSortedUnique([
      ...recipe.cookingMethods,
      ...metadata.cookingMethods,
    ]);
    cookingMethodVocabularyFromRecipes.addAll(recipeMethods);

    recipeRows.add(
      RecipeMetadataRow(
        recipeId: recipe.id,
        name: recipe.name,
        pack: pack,
        heroIngredientId: heroId,
        implicitExactIds: implicitExact.toList()..sort(),
        explicitExactIds: _normSortedUnique(metadata.exactIngredientIds),
        preferredIds: _normSortedUnique(metadata.preferredIngredientIds),
        compatibleIds: _normSortedUnique(metadata.compatibleIngredientIds),
        substituteIds: _normSortedUnique(metadata.substituteIngredientIds),
        familyIds: _normSortedUnique(metadata.ingredientFamilyIds),
        excludedIds: _normSortedUnique(metadata.excludedIngredientIds),
        requiredForms: requiredForms,
        allowedForms: allowedForms,
        excludedForms: excludedForms,
        cookingMethods: recipeMethods,
        requiredTexture: normalizeCompatibilityToken(
          metadata.requiredTexture ?? '',
        ),
        hasSuitabilityNotes: metadata.suitabilityNotes.trim().isNotEmpty,
      ),
    );
  }

  final duplicateRecipeIds =
      recipeIdCounts.entries
          .where((e) => e.value > 1)
          .map((e) => e.key)
          .toList()
        ..sort();
  for (final id in duplicateRecipeIds) {
    integrityIssues.add(
      IntegrityIssue(
        code: 'duplicate_recipe_id',
        recipeId: id,
        field: 'id',
        value: id,
        detail: 'Recipe id appears more than once in the loaded dataset.',
      ),
    );
  }

  final unknownFormTokens =
      formTokensSeenInRecipes
          .where(
            (t) => t.isNotEmpty && !formVocabularyFromIngredients.contains(t),
          )
          .toList()
        ..sort();
  final unknownCookingMethodTokens =
      cookingMethodVocabularyFromRecipes
          .where((t) => !cookingMethodVocabularyFromIngredients.contains(t))
          .toList()
        ..sort();
  final orphanCanonicalCookingMethodTokens =
      cookingMethodVocabularyFromIngredients
          .where((t) => !cookingMethodVocabularyFromRecipes.contains(t))
          .toList()
        ..sort();

  // ---- Per-ingredient coverage classification ----
  final ingredientRows = <IngredientCoverageRow>[];
  final evaluatedAt = DateTime.utc(2026, 8, 6);
  final emptyPantry = const <pantry_model.Ingredient>[];
  final allReadiness = candidateService.evaluateAllRecipes(
    recipes: sortedRecipes,
    pantry: emptyPantry,
    evaluatedAt: evaluatedAt,
  );

  for (final ingredient in selectable) {
    final selection = compatibilityService.enrichSelection(
      MainIngredientSelection(
        canonicalIngredientId: ingredient.id,
        displayName: ingredient.displayName(),
        emoji: ingredient.emoji,
      ),
    );

    var exact = 0, preferred = 0, compatible = 0, substitute = 0, family = 0;
    final exclusionCounts = <String, int>{};
    final directRecipeIds = <String>[];
    final adaptableRecipeIds = <String>[];

    // Profile completeness is a property of the ingredient itself, not of
    // any individual recipe, so it is computed once per ingredient and
    // used to route every incompatible* exclusion this ingredient receives
    // for that dimension — never re-derived production tier/exclusion
    // logic, only a classification of production's own output using data
    // the builder already has (ingredient.ingredientForms/textures/
    // supportedCookingMethods).
    final hasFormsProfile = ingredient.ingredientForms.isNotEmpty;
    final hasTexturesProfile = ingredient.textures.isNotEmpty;
    final hasMethodsProfile = ingredient.supportedCookingMethods.isNotEmpty;
    var explicitIdBlockPairs = 0;
    final constraintMismatchPairs = <String, int>{
      for (final d in profileDimensions) d: 0,
    };
    final profileIncompletePairs = <String, int>{
      for (final d in profileDimensions) d: 0,
    };

    void routeIncompatible(String dimension, bool hasProfile) {
      final target = hasProfile
          ? constraintMismatchPairs
          : profileIncompletePairs;
      target[dimension] = (target[dimension] ?? 0) + 1;
    }

    for (final recipe in sortedRecipes) {
      final result = compatibilityService.evaluate(
        recipe: recipe,
        selection: selection,
      );
      if (result.isEligible) {
        switch (result.tier!) {
          case MainIngredientMatchTier.exact:
            exact++;
            directRecipeIds.add(recipe.id);
          case MainIngredientMatchTier.preferred:
            preferred++;
            directRecipeIds.add(recipe.id);
          case MainIngredientMatchTier.compatible:
            compatible++;
            directRecipeIds.add(recipe.id);
          case MainIngredientMatchTier.substitute:
            substitute++;
            directRecipeIds.add(recipe.id);
          case MainIngredientMatchTier.family:
            family++;
            adaptableRecipeIds.add(recipe.id);
        }
      } else {
        final reason = result.exclusionReason!;
        exclusionCounts.update(reason.name, (v) => v + 1, ifAbsent: () => 1);
        switch (reason) {
          case MainIngredientExclusionReason.explicitlyExcluded:
            explicitIdBlockPairs++;
          case MainIngredientExclusionReason.incompatibleForm:
            routeIncompatible('form', hasFormsProfile);
          case MainIngredientExclusionReason.incompatibleTexture:
            routeIncompatible('texture', hasTexturesProfile);
          case MainIngredientExclusionReason.incompatibleCookingMethod:
            routeIncompatible('cookingMethod', hasMethodsProfile);
          case MainIngredientExclusionReason.unverifiedFamily:
          case MainIngredientExclusionReason.noMatch:
            break; // no overlay category — see allExclusionReasons.
        }
      }
    }

    final directCount = exact + preferred + compatible + substitute;
    // Primary classification depends only on eligible tiers. Exclusion
    // reasons (including unverifiedFamily and noMatch, both extremely
    // common — most recipes simply don't mention most ingredients) are
    // reported separately as a diagnostic overlay and never change this.
    // The EXPLICIT_ID_BLOCK / CONSTRAINT_MISMATCH / PROFILE_INCOMPLETE
    // overlay computed above is likewise purely diagnostic and never
    // participates in this decision.
    final classification = directCount > 0
        ? CoverageClassification.directCoverage
        : family > 0
        ? CoverageClassification.adaptableOnly
        : CoverageClassification.noCoverage;

    ingredientRows.add(
      IngredientCoverageRow(
        canonicalId: ingredient.id,
        displayName: ingredient.displayName(),
        category: ingredient.category,
        taxonomyType: ingredient.taxonomyType?.name ?? '',
        parentId: ingredient.parentId ?? '',
        rootId: rootIdByCanonicalId[ingredient.id] ?? '',
        exact: exact,
        preferred: preferred,
        compatible: compatible,
        substitute: substitute,
        family: family,
        exclusionReasonCounts: exclusionCounts,
        ingredientForms: List<String>.of(ingredient.ingredientForms)..sort(),
        textures: List<String>.of(ingredient.textures)..sort(),
        supportedCookingMethods: List<String>.of(
          ingredient.supportedCookingMethods,
        )..sort(),
        explicitIdBlockPairCount: explicitIdBlockPairs,
        constraintMismatchPairCounts: constraintMismatchPairs,
        profileIncompletePairCounts: profileIncompletePairs,
        sampleDirectRecipeIds: (directRecipeIds..sort()).take(5).toList(),
        sampleAdaptableRecipeIds: (adaptableRecipeIds..sort()).take(5).toList(),
        classification: classification,
      ),
    );
  }

  // Requirement: "every DIRECT_COVERAGE recipe ID exists in the loaded
  // recipe set", proven through the real RecipeReadinessService /
  // RecipeCandidateService.evaluateAllRecipes production path — reusing the
  // single O(recipes) `allReadiness` pass computed once above, independent
  // of ingredient count.
  final readinessRecipeIds = allReadiness
      .map((match) => match.recipe.id)
      .toSet();
  for (final row in ingredientRows) {
    for (final recipeId in [
      ...row.sampleDirectRecipeIds,
      ...row.sampleAdaptableRecipeIds,
    ]) {
      if (!readinessRecipeIds.contains(recipeId)) {
        integrityIssues.add(
          IntegrityIssue(
            code: 'recipe_id_missing_from_readiness_set',
            recipeId: recipeId,
            field: row.canonicalId,
            value: recipeId,
            detail:
                'Recipe id appears in compatibility evaluation for '
                '${row.canonicalId} but not in the '
                'RecipeCandidateService.evaluateAllRecipes result set.',
          ),
        );
      }
    }
  }

  // ---- Coverage summary (primary classification — eligible tiers only) ----
  final coverage = CoverageSummary(
    directCoverageCount: ingredientRows
        .where((r) => r.classification == CoverageClassification.directCoverage)
        .length,
    adaptableOnlyCount: ingredientRows
        .where((r) => r.classification == CoverageClassification.adaptableOnly)
        .length,
    noCoverageCount: ingredientRows
        .where((r) => r.classification == CoverageClassification.noCoverage)
        .length,
    ingredientsWithExact: ingredientRows.where((r) => r.exact > 0).length,
    ingredientsWithPreferred: ingredientRows
        .where((r) => r.preferred > 0)
        .length,
    ingredientsWithCompatible: ingredientRows
        .where((r) => r.compatible > 0)
        .length,
    ingredientsWithSubstitute: ingredientRows
        .where((r) => r.substitute > 0)
        .length,
    ingredientsWithFamily: ingredientRows.where((r) => r.family > 0).length,
    totalExactPairs: ingredientRows.fold(0, (s, r) => s + r.exact),
    totalPreferredPairs: ingredientRows.fold(0, (s, r) => s + r.preferred),
    totalCompatiblePairs: ingredientRows.fold(0, (s, r) => s + r.compatible),
    totalSubstitutePairs: ingredientRows.fold(0, (s, r) => s + r.substitute),
    totalFamilyPairs: ingredientRows.fold(0, (s, r) => s + r.family),
  );

  // ---- Exclusion diagnostics (separate overlay, never folded into
  // coverage) ----
  final exclusionDiagnostics = ExclusionDiagnostics(
    ingredientCountByReason: {
      for (final reason in allExclusionReasons)
        reason.name: ingredientRows
            .where((r) => (r.exclusionReasonCounts[reason.name] ?? 0) > 0)
            .length,
    },
    totalPairsByReason: {
      for (final reason in allExclusionReasons)
        reason.name: ingredientRows.fold<int>(
          0,
          (sum, r) => sum + (r.exclusionReasonCounts[reason.name] ?? 0),
        ),
    },
    explicitIdBlockIngredientCount: ingredientRows
        .where((r) => r.hasExplicitIdBlock)
        .length,
    explicitIdBlockPairCount: ingredientRows.fold(
      0,
      (sum, r) => sum + r.explicitIdBlockPairCount,
    ),
    constraintMismatchIngredientCount: ingredientRows
        .where((r) => r.hasConstraintMismatch)
        .length,
    constraintMismatchPairCountByDimension: {
      for (final d in profileDimensions)
        d: ingredientRows.fold<int>(
          0,
          (sum, r) => sum + (r.constraintMismatchPairCounts[d] ?? 0),
        ),
    },
    profileIncompleteIngredientCount: ingredientRows
        .where((r) => r.hasProfileIncomplete)
        .length,
    profileIncompletePairCountByDimension: {
      for (final d in profileDimensions)
        d: ingredientRows.fold<int>(
          0,
          (sum, r) => sum + (r.profileIncompletePairCounts[d] ?? 0),
        ),
    },
  );

  // ---- Dataset summary ----
  final recipeCountByPack = <String, int>{};
  for (final recipe in sortedRecipes) {
    final pack = recipePackByRecipeId[recipe.id] ?? '';
    recipeCountByPack.update(pack, (v) => v + 1, ifAbsent: () => 1);
  }
  final datasetSummary = DatasetSummary(
    totalRegistryNodes: allNodes.length,
    selectableMainIngredientCount: selectable.length,
    familyOrCategoryNodeCount: familyOrCategoryCount,
    totalRecipeCount: sortedRecipes.length,
    recipeCountByPack: Map.fromEntries(
      recipeCountByPack.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    ),
    recipeCountByHeroCanonicalId: Map.fromEntries(
      recipeCountByHero.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    ),
  );

  // ---- Generic-to-specific asymmetry ----
  final byId = {for (final i in allNodes) i.id: i};
  final byParent = <String, List<CanonicalIngredient>>{};
  for (final i in allNodes) {
    final parent = i.parentId;
    if (parent != null) {
      byParent.putIfAbsent(parent, () => []).add(i);
    }
  }
  final rowById = {for (final r in ingredientRows) r.canonicalId: r};
  final asymmetryRows = <AsymmetryRow>[];
  for (final row in ingredientRows) {
    if (row.classification == CoverageClassification.directCoverage) {
      continue;
    }
    final ingredient = byId[row.canonicalId]!;
    if (ingredient.taxonomyType == IngredientTaxonomyType.generic) {
      continue; // only descendants are candidates for this asymmetry.
    }

    // (a) true taxonomy ancestors that are themselves selectable.
    CanonicalIngredient? counterpart;
    var relationship = '';
    for (final ancestorId in registry.ancestorIdsFor(ingredient.id)) {
      final ancestor = byId[ancestorId];
      if (ancestor == null || !ancestor.canSelectAsMainIngredient) continue;
      final ancestorRow = rowById[ancestorId];
      if (ancestorRow?.classification ==
          CoverageClassification.directCoverage) {
        counterpart = ancestor;
        relationship = 'true_ancestor';
        break;
      }
    }

    // (b) generic sibling under the same immediate parent — this registry
    // models "pork" and "pork_piece" as siblings under pork_family, not as
    // parent/child, so this is the common real-world case.
    if (counterpart == null) {
      final parentId = ingredient.parentId;
      if (parentId != null) {
        final siblings = byParent[parentId] ?? const [];
        final generics =
            siblings
                .where(
                  (s) =>
                      s.id != ingredient.id &&
                      s.taxonomyType == IngredientTaxonomyType.generic &&
                      rowById[s.id]?.classification ==
                          CoverageClassification.directCoverage,
                )
                .toList()
              ..sort((a, b) => a.id.compareTo(b.id));
        if (generics.isNotEmpty) {
          counterpart = generics.first;
          relationship = 'generic_sibling';
        }
      }
    }

    if (counterpart == null) continue;
    final counterpartRow = rowById[counterpart.id]!;
    asymmetryRows.add(
      AsymmetryRow(
        canonicalId: ingredient.id,
        displayName: ingredient.displayName(),
        taxonomyType: ingredient.taxonomyType?.name ?? '',
        parentId: ingredient.parentId ?? '',
        rootId: rootIdByCanonicalId[ingredient.id] ?? '',
        relationship: relationship,
        counterpartId: counterpart.id,
        counterpartDisplayName: counterpart.displayName(),
        counterpartDirectTierCounts: {
          'exact': counterpartRow.exact,
          'preferred': counterpartRow.preferred,
          'compatible': counterpartRow.compatible,
          'substitute': counterpartRow.substitute,
        },
        childDirectTierCounts: {
          'exact': row.exact,
          'preferred': row.preferred,
          'compatible': row.compatible,
          'substitute': row.substitute,
        },
        childFamilyCount: row.family,
        sampleCounterpartRecipeIds: counterpartRow.sampleDirectRecipeIds,
      ),
    );
  }
  asymmetryRows.sort((a, b) => a.canonicalId.compareTo(b.canonicalId));

  // ---- Review queue ----
  final reviewQueue = <ReviewItem>[];
  for (final issue in integrityIssues) {
    if (issue.code == 'invalid_hero_reference' ||
        issue.code == 'invalid_canonical_reference' ||
        issue.code == 'invalid_family_reference' ||
        issue.code == 'duplicate_recipe_id') {
      reviewQueue.add(
        ReviewItem(
          priority: 'P0_INVALID_REFERENCE',
          canonicalId: issue.recipeId,
          summary: '${issue.code} in ${issue.field}="${issue.value}"',
        ),
      );
    } else if (issue.code == 'conflicting_metadata') {
      reviewQueue.add(
        ReviewItem(
          priority: 'P1_CONFLICTING_METADATA',
          canonicalId: issue.recipeId,
          summary: issue.detail,
        ),
      );
    }
  }
  for (final row in asymmetryRows) {
    reviewQueue.add(
      ReviewItem(
        priority: 'P2_GENERIC_SPECIFIC_ASYMMETRY',
        canonicalId: row.canonicalId,
        summary:
            '${row.canonicalId} has no direct coverage while '
            '${row.counterpartId} (${row.relationship}) does.',
      ),
    );
  }
  for (final row in ingredientRows) {
    if (row.classification == CoverageClassification.adaptableOnly) {
      reviewQueue.add(
        ReviewItem(
          priority: 'P3_ADAPTABLE_ONLY_REVIEW',
          canonicalId: row.canonicalId,
          summary:
              '${row.canonicalId} has ${row.family} family-tier recipe(s) '
              'and zero direct-tier recipes.',
        ),
      );
    }
  }
  for (final row in ingredientRows) {
    if (row.classification == CoverageClassification.noCoverage) {
      final tags = <String>[
        if (row.hasExplicitIdBlock) 'explicit id block',
        if (row.hasConstraintMismatch) 'constraint mismatch',
        if (row.hasProfileIncomplete) 'profile incomplete',
      ];
      reviewQueue.add(
        ReviewItem(
          priority: 'P4_ZERO_COVERAGE_CONTENT_DECISION',
          canonicalId: row.canonicalId,
          summary:
              '${row.canonicalId} classification=NO_COVERAGE'
              '${tags.isEmpty ? '' : ' (${tags.join(', ')})'}.',
        ),
      );
      // Optional, additive entries below, mutually non-exclusive: an
      // ingredient can simultaneously have an explicit id block on one
      // recipe, a genuine constraint mismatch on another, and a
      // profile-incompleteness gap on a third. Each is reported as its own
      // review-queue entry with a distinct action implied by its priority.
      // PROFILE_INCOMPLETE is never described as deliberate/explicit
      // blocking — see IngredientCoverageRow.hasProfileIncomplete and the
      // ExclusionOverlayCategory doc comment.
      if (row.hasExplicitIdBlock) {
        reviewQueue.add(
          ReviewItem(
            priority: 'P1_EXPLICIT_ID_BLOCK',
            canonicalId: row.canonicalId,
            summary:
                '${row.canonicalId} has ${row.explicitIdBlockPairCount} '
                'recipe(s) that explicitly list it in excludedIngredientIds '
                '— verify this authored exclusion is still intentional.',
          ),
        );
      }
      if (row.hasConstraintMismatch) {
        reviewQueue.add(
          ReviewItem(
            priority: 'P2_CONSTRAINT_MISMATCH_REVIEW',
            canonicalId: row.canonicalId,
            summary:
                '${row.canonicalId} has ${row.constraintMismatchTotal} '
                'recipe(s) whose required form/texture/cooking-method '
                'genuinely conflicts with its declared profile — verify the '
                'conflict is correct, not an authoring error on either side.',
          ),
        );
      }
      if (row.hasProfileIncomplete) {
        reviewQueue.add(
          ReviewItem(
            priority: 'P2_PROFILE_COMPLETENESS',
            canonicalId: row.canonicalId,
            summary:
                '${row.canonicalId} lacks profile data '
                '(ingredientForms/textures/supportedCookingMethods) needed '
                'for confident compatibility evaluation on '
                '${row.profileIncompleteTotal} recipe(s) — a data-'
                'completeness gap, not evidence of a deliberate rejection.',
          ),
        );
      }
    }
  }
  reviewQueue.sort((a, b) {
    final p = a.priority.compareTo(b.priority);
    if (p != 0) return p;
    return a.canonicalId.compareTo(b.canonicalId);
  });

  // ---- Integrity issue groups (informational, pack-level root cause) ----
  final integrityIssueGroups = <IntegrityIssueGroup>[];
  final groupedIssues = <String, List<IntegrityIssue>>{};
  for (final issue in integrityIssues) {
    final key = '${issue.code} ${issue.field} ${issue.value}';
    groupedIssues.putIfAbsent(key, () => []).add(issue);
  }
  for (final entry in groupedIssues.entries) {
    final group = entry.value;
    if (group.length < 2) continue; // only worth grouping when repeated.
    final packs = group
        .map((i) => recipePackByRecipeId[i.recipeId] ?? '')
        .toSet();
    final sameSinglePack = packs.length == 1 && packs.first.isNotEmpty;
    integrityIssueGroups.add(
      IntegrityIssueGroup(
        code: group.first.code,
        field: group.first.field,
        value: group.first.value,
        manifestationCount: group.length,
        affectedRecipeIds: (group.map((i) => i.recipeId).toList()..sort()),
        sourceScope: sameSinglePack
            ? 'pack_default_likely'
            : 'mixed_or_unknown',
        probableSourceFile: sameSinglePack
            ? 'assets/recipes/${packs.first}.json'
            : null,
      ),
    );
  }
  integrityIssueGroups.sort((a, b) {
    final c = a.code.compareTo(b.code);
    if (c != 0) return c;
    final f = a.field.compareTo(b.field);
    if (f != 0) return f;
    return a.value.compareTo(b.value);
  });

  return RecipeCoverageBaselineDataset(
    dataset: datasetSummary,
    coverage: coverage,
    exclusionDiagnostics: exclusionDiagnostics,
    ingredientRows: ingredientRows,
    recipeRows: recipeRows,
    integrityIssues: integrityIssues,
    integrityIssueGroups: integrityIssueGroups,
    asymmetryRows: asymmetryRows,
    reviewQueue: reviewQueue,
    unknownFormTokens: unknownFormTokens,
    unknownCookingMethodTokens: unknownCookingMethodTokens,
    orphanCanonicalCookingMethodTokens: orphanCanonicalCookingMethodTokens,
  );
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

class AuditIdentity {
  const AuditIdentity({
    required this.branch,
    required this.baseSha,
    required this.generatedDate,
  });

  final String branch;
  final String baseSha;
  final String generatedDate;
}

Map<String, dynamic> _tierMap(Map<String, int> m) {
  final out = <String, dynamic>{};
  for (final key in (m.keys.toList()..sort())) {
    out[key] = m[key];
  }
  return out;
}

Map<String, dynamic> recipeCoverageBaselineToJson(
  RecipeCoverageBaselineDataset data,
  AuditIdentity identity,
) {
  final ingredients = [...data.ingredientRows]
    ..sort((a, b) => a.canonicalId.compareTo(b.canonicalId));
  final recipes = [...data.recipeRows]
    ..sort((a, b) => a.recipeId.compareTo(b.recipeId));
  final asymmetries = [...data.asymmetryRows]
    ..sort((a, b) => a.canonicalId.compareTo(b.canonicalId));
  final integrity = [...data.integrityIssues]
    ..sort((a, b) {
      final c = a.code.compareTo(b.code);
      if (c != 0) return c;
      final r = a.recipeId.compareTo(b.recipeId);
      if (r != 0) return r;
      return a.field.compareTo(b.field);
    });

  return {
    'audit': {
      'branch': identity.branch,
      'baseSha': identity.baseSha,
      'generatedDate': identity.generatedDate,
      'registrySource': 'IngredientCatalog().loadRegistry()',
      'recipeSource': 'LocalRecipeDataSource().loadRecipes()',
      'productionServicesExercised': [
        'MainIngredientCompatibilityService',
        'RecipeReadinessService',
        'RecipeCandidateService.evaluateAllRecipes',
        'SmartRecommendationEngine',
      ],
    },
    'dataset': {
      'totalRegistryNodes': data.dataset.totalRegistryNodes,
      'selectableMainIngredientCount':
          data.dataset.selectableMainIngredientCount,
      'familyOrCategoryNodeCount': data.dataset.familyOrCategoryNodeCount,
      'totalRecipeCount': data.dataset.totalRecipeCount,
      'recipeCountByPack': data.dataset.recipeCountByPack,
      'recipeCountByHeroCanonicalId': data.dataset.recipeCountByHeroCanonicalId,
    },
    'integrity': {
      'duplicateRecipeIdCount': integrity
          .where((i) => i.code == 'duplicate_recipe_id')
          .length,
      'invalidHeroReferenceCount': integrity
          .where((i) => i.code == 'invalid_hero_reference')
          .length,
      'invalidCanonicalReferenceCount': integrity
          .where((i) => i.code == 'invalid_canonical_reference')
          .length,
      'invalidFamilyReferenceCount': integrity
          .where((i) => i.code == 'invalid_family_reference')
          .length,
      'duplicateMetadataReferenceCount': integrity
          .where((i) => i.code == 'duplicate_metadata_reference')
          .length,
      'conflictingMetadataCount': integrity
          .where((i) => i.code == 'conflicting_metadata')
          .length,
      'unknownFormTokens': data.unknownFormTokens,
      'unknownCookingMethodTokens': data.unknownCookingMethodTokens,
      'orphanCanonicalCookingMethodTokens':
          data.orphanCanonicalCookingMethodTokens,
      'issues': [for (final i in integrity) i.toJson()],
      // Informational only: groups repeated (code, field, value) findings
      // that all trace to recipes in a single pack, since that is a strong
      // signal (not proof — pack-level defaults are flattened into each
      // parsed Recipe before this builder sees them) that one shared
      // pack-level authoring mistake is the true root cause. Never
      // suppresses or replaces the per-recipe entries in 'issues' above.
      'issueGroups': [
        for (final g
            in [...data.integrityIssueGroups]..sort(
              (a, b) => a.code != b.code
                  ? a.code.compareTo(b.code)
                  : a.field != b.field
                  ? a.field.compareTo(b.field)
                  : a.value.compareTo(b.value),
            ))
          {
            'code': g.code,
            'field': g.field,
            'value': g.value,
            'manifestationCount': g.manifestationCount,
            'affectedRecipeIds': g.affectedRecipeIds,
            'sourceScope': g.sourceScope,
            'probableSourceFile': g.probableSourceFile,
          },
      ],
    },
    // Primary coverage classification — eligible tiers only. No exclusion
    // reason (including unverifiedFamily) appears here or affects these
    // three counts; see 'exclusionDiagnostics' below for that overlay.
    'coverageSummary': {
      'DIRECT_COVERAGE': data.coverage.directCoverageCount,
      'ADAPTABLE_ONLY': data.coverage.adaptableOnlyCount,
      'NO_COVERAGE': data.coverage.noCoverageCount,
      'ingredientsWithExact': data.coverage.ingredientsWithExact,
      'ingredientsWithPreferred': data.coverage.ingredientsWithPreferred,
      'ingredientsWithCompatible': data.coverage.ingredientsWithCompatible,
      'ingredientsWithSubstitute': data.coverage.ingredientsWithSubstitute,
      'ingredientsWithFamily': data.coverage.ingredientsWithFamily,
      'totalExactPairs': data.coverage.totalExactPairs,
      'totalPreferredPairs': data.coverage.totalPreferredPairs,
      'totalCompatiblePairs': data.coverage.totalCompatiblePairs,
      'totalSubstitutePairs': data.coverage.totalSubstitutePairs,
      'totalFamilyPairs': data.coverage.totalFamilyPairs,
    },
    // Separate diagnostic overlay: every recipe/ingredient pair that did
    // NOT reach an eligible tier, broken down by exact reason. Never folds
    // back into 'coverageSummary' — an unverifiedFamily or noMatch result
    // never changes an ingredient's primary classification.
    'exclusionDiagnostics': {
      'ingredientCountByReason': _tierMap(
        data.exclusionDiagnostics.ingredientCountByReason,
      ),
      'totalPairsByReason': _tierMap(
        data.exclusionDiagnostics.totalPairsByReason,
      ),
      // Three-way overlay: distinguishes an unambiguous, ingredient-
      // specific authored exclusion (EXPLICIT_ID_BLOCK) from a genuine
      // authored form/texture/method conflict where the ingredient DOES
      // have declared profile data (CONSTRAINT_MISMATCH), from production's
      // strict "no data means no match" default where the ingredient has
      // NO declared profile data on that dimension (PROFILE_INCOMPLETE —
      // a content-completeness gap, never evidence of deliberate intent).
      'EXPLICIT_ID_BLOCK': {
        'ingredientCount':
            data.exclusionDiagnostics.explicitIdBlockIngredientCount,
        'pairCount': data.exclusionDiagnostics.explicitIdBlockPairCount,
      },
      'CONSTRAINT_MISMATCH': {
        'ingredientCount':
            data.exclusionDiagnostics.constraintMismatchIngredientCount,
        'pairCountByDimension': _tierMap(
          data.exclusionDiagnostics.constraintMismatchPairCountByDimension,
        ),
      },
      'PROFILE_INCOMPLETE': {
        'ingredientCount':
            data.exclusionDiagnostics.profileIncompleteIngredientCount,
        'pairCountByDimension': _tierMap(
          data.exclusionDiagnostics.profileIncompletePairCountByDimension,
        ),
      },
    },
    'ingredients': [
      for (final row in ingredients)
        {
          'canonicalId': row.canonicalId,
          'displayName': row.displayName,
          'category': row.category,
          'taxonomyType': row.taxonomyType,
          'parentId': row.parentId,
          'rootId': row.rootId,
          'exact': row.exact,
          'preferred': row.preferred,
          'compatible': row.compatible,
          'substitute': row.substitute,
          'family': row.family,
          'exclusionReasonCounts': _tierMap(row.exclusionReasonCounts),
          // Full canonical profile arrays — the data this row's
          // CONSTRAINT_MISMATCH vs. PROFILE_INCOMPLETE split is computed
          // from, made directly visible rather than requiring a source
          // read.
          'ingredientForms': row.ingredientForms,
          'textures': row.textures,
          'supportedCookingMethods': row.supportedCookingMethods,
          'explicitIdBlockPairCount': row.explicitIdBlockPairCount,
          'constraintMismatchPairCounts': _tierMap(
            row.constraintMismatchPairCounts,
          ),
          'constraintMismatchTotal': row.constraintMismatchTotal,
          'profileIncompletePairCounts': _tierMap(
            row.profileIncompletePairCounts,
          ),
          'profileIncompleteTotal': row.profileIncompleteTotal,
          'directRecipeCount': row.directRecipeCount,
          'adaptableRecipeCount': row.adaptableRecipeCount,
          'classification': classificationLabel(row.classification),
          'sampleDirectRecipeIds': row.sampleDirectRecipeIds,
          'sampleAdaptableRecipeIds': row.sampleAdaptableRecipeIds,
        },
    ],
    'recipes': [
      for (final row in recipes)
        {
          'recipeId': row.recipeId,
          'name': row.name,
          'pack': row.pack,
          'heroIngredientId': row.heroIngredientId,
          'implicitExactIds': row.implicitExactIds,
          'explicitExactIds': row.explicitExactIds,
          'preferredIds': row.preferredIds,
          'compatibleIds': row.compatibleIds,
          'substituteIds': row.substituteIds,
          'familyIds': row.familyIds,
          'excludedIds': row.excludedIds,
          'requiredForms': row.requiredForms,
          'allowedForms': row.allowedForms,
          'excludedForms': row.excludedForms,
          'requiredTexture': row.requiredTexture,
          'cookingMethods': row.cookingMethods,
          'hasSuitabilityNotes': row.hasSuitabilityNotes,
        },
    ],
    'asymmetries': [
      for (final row in asymmetries)
        {
          'canonicalId': row.canonicalId,
          'displayName': row.displayName,
          'taxonomyType': row.taxonomyType,
          'parentId': row.parentId,
          'rootId': row.rootId,
          'relationship': row.relationship,
          'counterpartId': row.counterpartId,
          'counterpartDisplayName': row.counterpartDisplayName,
          'counterpartDirectTierCounts': _tierMap(
            row.counterpartDirectTierCounts,
          ),
          'childDirectTierCounts': _tierMap(row.childDirectTierCounts),
          'childFamilyCount': row.childFamilyCount,
          'sampleCounterpartRecipeIds': row.sampleCounterpartRecipeIds,
        },
    ],
    'reviewQueue': [
      for (final item in data.reviewQueue)
        {
          'priority': item.priority,
          'canonicalId': item.canonicalId,
          'summary': item.summary,
        },
    ],
  };
}

String recipeCoverageBaselineToJsonString(
  RecipeCoverageBaselineDataset data,
  AuditIdentity identity,
) {
  final map = recipeCoverageBaselineToJson(data, identity);
  return '${const JsonEncoder.withIndent('  ').convert(map)}\n';
}

String _mdEscape(String value) => value.replaceAll('|', r'\|');

String _row(List<String> cells) => '| ${cells.map(_mdEscape).join(' | ')} |';

String _list(List<String> values) =>
    values.isEmpty ? '_(none)_' : values.join(', ');

String renderRecipeCoverageBaselineMarkdown(
  RecipeCoverageBaselineDataset data,
  AuditIdentity identity,
) {
  final buffer = StringBuffer();
  buffer.writeln('# Recipe Coverage Baseline Audit');
  buffer.writeln();
  buffer.writeln(
    '> Phase 2 audit-only baseline. No recipe content, compatibility '
    'metadata, recommendation behavior, Pantry behavior, or taxonomy data '
    'was modified to produce this report.',
  );
  buffer.writeln();

  buffer.writeln('## 1. Audit identity');
  buffer.writeln();
  buffer.writeln('- Branch: `${identity.branch}`');
  buffer.writeln('- Base SHA: `${identity.baseSha}`');
  buffer.writeln('- Generation date: `${identity.generatedDate}`');
  buffer.writeln('- Registry source: `IngredientCatalog().loadRegistry()`');
  buffer.writeln(
    '- Recipe source: `LocalRecipeDataSource().loadRecipes()` (all current '
    'default asset packs)',
  );
  buffer.writeln(
    '- Production services exercised: `MainIngredientCompatibilityService`, '
    '`RecipeReadinessService`, `RecipeCandidateService.evaluateAllRecipes`, '
    '`SmartRecommendationEngine`',
  );
  buffer.writeln();

  buffer.writeln('## 2. Dataset summary');
  buffer.writeln();
  buffer.writeln('| Metric | Value |');
  buffer.writeln('|---|---|');
  buffer.writeln(
    _row(['Total registry nodes', '${data.dataset.totalRegistryNodes}']),
  );
  buffer.writeln(
    _row([
      'Selectable main ingredients',
      '${data.dataset.selectableMainIngredientCount}',
    ]),
  );
  buffer.writeln(
    _row([
      'Family/category nodes',
      '${data.dataset.familyOrCategoryNodeCount}',
    ]),
  );
  buffer.writeln(_row(['Total recipes', '${data.dataset.totalRecipeCount}']));
  buffer.writeln();
  buffer.writeln('Recipe count by pack:');
  buffer.writeln();
  buffer.writeln('| Pack | Count |');
  buffer.writeln('|---|---|');
  for (final entry in data.dataset.recipeCountByPack.entries) {
    buffer.writeln(_row([entry.key, '${entry.value}']));
  }
  buffer.writeln();
  buffer.writeln('Recipe count by hero canonical ID:');
  buffer.writeln();
  buffer.writeln('| Hero canonical ID | Count |');
  buffer.writeln('|---|---|');
  for (final entry in data.dataset.recipeCountByHeroCanonicalId.entries) {
    buffer.writeln(_row([entry.key, '${entry.value}']));
  }
  buffer.writeln();

  buffer.writeln('## 3. Coverage summary');
  buffer.writeln();
  buffer.writeln(
    '> Primary classification is based **only** on eligible tiers '
    '(exact/preferred/compatible/substitute/family). No exclusion reason — '
    'including `unverifiedFamily`, which fires whenever a recipe declares '
    'support for *other* families but not this ingredient\'s — ever '
    'changes these three counts. See section 3b for the exclusion overlay.',
  );
  buffer.writeln();
  buffer.writeln('| Metric | Value |');
  buffer.writeln('|---|---|');
  buffer.writeln(
    _row(['DIRECT_COVERAGE', '${data.coverage.directCoverageCount}']),
  );
  buffer.writeln(
    _row(['ADAPTABLE_ONLY', '${data.coverage.adaptableOnlyCount}']),
  );
  buffer.writeln(_row(['NO_COVERAGE', '${data.coverage.noCoverageCount}']));
  buffer.writeln(
    _row([
      'Ingredients with >=1 exact',
      '${data.coverage.ingredientsWithExact}',
    ]),
  );
  buffer.writeln(
    _row([
      'Ingredients with >=1 preferred',
      '${data.coverage.ingredientsWithPreferred}',
    ]),
  );
  buffer.writeln(
    _row([
      'Ingredients with >=1 compatible',
      '${data.coverage.ingredientsWithCompatible}',
    ]),
  );
  buffer.writeln(
    _row([
      'Ingredients with >=1 substitute',
      '${data.coverage.ingredientsWithSubstitute}',
    ]),
  );
  buffer.writeln(
    _row([
      'Ingredients with >=1 family',
      '${data.coverage.ingredientsWithFamily}',
    ]),
  );
  buffer.writeln(
    _row(['Total eligible exact pairs', '${data.coverage.totalExactPairs}']),
  );
  buffer.writeln(
    _row([
      'Total eligible preferred pairs',
      '${data.coverage.totalPreferredPairs}',
    ]),
  );
  buffer.writeln(
    _row([
      'Total eligible compatible pairs',
      '${data.coverage.totalCompatiblePairs}',
    ]),
  );
  buffer.writeln(
    _row([
      'Total eligible substitute pairs',
      '${data.coverage.totalSubstitutePairs}',
    ]),
  );
  buffer.writeln(
    _row(['Total eligible family pairs', '${data.coverage.totalFamilyPairs}']),
  );
  buffer.writeln();

  buffer.writeln('## 3b. Exclusion diagnostics (overlay, not a coverage tier)');
  buffer.writeln();
  buffer.writeln(
    '> Every recipe/ingredient pair that did **not** reach an eligible '
    'tier falls into exactly one of these six reasons. This table is '
    'diagnostic only — it never changes section 3\'s counts. In '
    'particular, `unverifiedFamily` (the recipe supports other families, '
    'not this one) and `noMatch` (the recipe simply never mentions this '
    'ingredient) are expected to be large for most ingredients and do not '
    'by themselves indicate a defect.',
  );
  buffer.writeln();
  buffer.writeln(
    '| Exclusion reason | Ingredients with >=1 occurrence | Total '
    'ingredient-recipe pairs |',
  );
  buffer.writeln('|---|---|---|');
  for (final reason in allExclusionReasons) {
    buffer.writeln(
      _row([
        reason.name,
        '${data.exclusionDiagnostics.ingredientCountByReason[reason.name] ?? 0}',
        '${data.exclusionDiagnostics.totalPairsByReason[reason.name] ?? 0}',
      ]),
    );
  }
  buffer.writeln();
  buffer.writeln(
    '### Three-way split of the incompatible*/explicitlyExcluded reasons',
  );
  buffer.writeln();
  buffer.writeln(
    '> Production returns the *same* exclusion-reason value '
    '(`incompatibleForm`/`incompatibleTexture`/`incompatibleCookingMethod`) '
    'whether an ingredient\'s declared profile genuinely conflicts with a '
    'recipe\'s constraint, or the ingredient simply has no profile data on '
    'that dimension at all. This audit distinguishes the two using the '
    'canonical profile fields already available when each row is built — '
    'it never changes production behavior. `explicitlyExcluded` is '
    'unambiguous by construction (an authored id on a recipe\'s '
    '`excludedIngredientIds`) and is never split.\n>\n'
    '> Form and texture use a strict "no data means no match" default: an '
    'empty `ingredientForms`/`textures` profile still gets excluded '
    '(as PROFILE_INCOMPLETE) when a recipe requires a form/texture. Cooking '
    'method is asymmetric: production only raises `incompatibleCookingMethod` '
    'when the ingredient DOES have declared `supportedCookingMethods` that '
    'fail to intersect the recipe\'s required methods — an ingredient with '
    'no declared methods is never excluded on that basis at all, so '
    'PROFILE_INCOMPLETE(cookingMethod) is always 0, by production design, '
    'not an audit gap (verified directly against '
    '`MainIngredientCompatibilityService.evaluate`, not assumed).',
  );
  buffer.writeln();
  buffer.writeln('| Category | Ingredients | Pairs (by dimension) |');
  buffer.writeln('|---|---|---|');
  buffer.writeln(
    _row([
      'EXPLICIT_ID_BLOCK (explicitlyExcluded — always deliberate, '
          'ingredient-specific)',
      '${data.exclusionDiagnostics.explicitIdBlockIngredientCount}',
      'total: ${data.exclusionDiagnostics.explicitIdBlockPairCount}',
    ]),
  );
  buffer.writeln(
    _row([
      'CONSTRAINT_MISMATCH (profile data exists and genuinely conflicts)',
      '${data.exclusionDiagnostics.constraintMismatchIngredientCount}',
      profileDimensions
          .map(
            (d) =>
                '$d: ${data.exclusionDiagnostics.constraintMismatchPairCountByDimension[d] ?? 0}',
          )
          .join(', '),
    ]),
  );
  buffer.writeln(
    _row([
      'PROFILE_INCOMPLETE (no profile data on that dimension — a '
          'data-completeness gap, not a deliberate rejection)',
      '${data.exclusionDiagnostics.profileIncompleteIngredientCount}',
      profileDimensions
          .map(
            (d) =>
                '$d: ${data.exclusionDiagnostics.profileIncompletePairCountByDimension[d] ?? 0}',
          )
          .join(', '),
    ]),
  );
  buffer.writeln();

  buffer.writeln('## 4. Integrity findings');
  buffer.writeln();
  final byCode = <String, List<IntegrityIssue>>{};
  for (final issue in data.integrityIssues) {
    byCode.putIfAbsent(issue.code, () => []).add(issue);
  }
  buffer.writeln('| Finding | Count |');
  buffer.writeln('|---|---|');
  buffer.writeln(
    _row([
      'Invalid canonical references',
      '${byCode['invalid_canonical_reference']?.length ?? 0}',
    ]),
  );
  buffer.writeln(
    _row([
      'Invalid family references',
      '${byCode['invalid_family_reference']?.length ?? 0}',
    ]),
  );
  buffer.writeln(
    _row([
      'Duplicate metadata references',
      '${byCode['duplicate_metadata_reference']?.length ?? 0}',
    ]),
  );
  buffer.writeln(
    _row([
      'Conflicting metadata',
      '${byCode['conflicting_metadata']?.length ?? 0}',
    ]),
  );
  buffer.writeln(
    _row([
      'Unknown form tokens (recipe-declared, absent from any ingredient profile)',
      '${data.unknownFormTokens.length}',
    ]),
  );
  buffer.writeln(
    _row([
      'Unknown cooking-method tokens (recipe-declared, absent from any ingredient profile)',
      '${data.unknownCookingMethodTokens.length}',
    ]),
  );
  buffer.writeln(
    _row([
      'Duplicate recipe IDs',
      '${byCode['duplicate_recipe_id']?.length ?? 0}',
    ]),
  );
  buffer.writeln(
    _row([
      'Invalid primary/hero IDs',
      '${byCode['invalid_hero_reference']?.length ?? 0}',
    ]),
  );
  buffer.writeln();
  if (data.integrityIssues.isEmpty) {
    buffer.writeln('No integrity issues found.');
  } else {
    buffer.writeln('| Code | Recipe ID | Field | Value | Detail |');
    buffer.writeln('|---|---|---|---|---|');
    for (final issue in data.integrityIssues) {
      buffer.writeln(
        _row([
          issue.code,
          issue.recipeId,
          issue.field,
          issue.value,
          issue.detail,
        ]),
      );
    }
  }
  buffer.writeln();
  if (data.unknownFormTokens.isNotEmpty) {
    buffer.writeln('Unknown form tokens: ${_list(data.unknownFormTokens)}');
    buffer.writeln();
  }
  if (data.unknownCookingMethodTokens.isNotEmpty) {
    buffer.writeln(
      'Unknown cooking-method tokens: '
      '${_list(data.unknownCookingMethodTokens)}',
    );
    buffer.writeln();
  }
  if (data.orphanCanonicalCookingMethodTokens.isNotEmpty) {
    buffer.writeln(
      'Secondary observation — canonical `supportedCookingMethods` tokens '
      'never referenced by any recipe (not a required check, informational '
      'only): ${_list(data.orphanCanonicalCookingMethodTokens)}',
    );
    buffer.writeln();
  }
  if (data.integrityIssueGroups.isNotEmpty) {
    buffer.writeln(
      '### Grouped by likely root cause (informational — does not replace '
      'or weaken the per-recipe findings above)',
    );
    buffer.writeln();
    buffer.writeln(
      '> Each row below groups findings that share the same (code, field, '
      'value) across multiple recipes. `sourceScope: pack_default_likely` '
      'means every affected recipe belongs to the same recipe pack — a '
      'strong signal (not a proof) that one shared pack-level default is '
      'the true root cause, so a content fix likely needs to happen once '
      'in `probableSourceFile`, not once per affected recipe. This audit '
      'branch does not modify that file.',
    );
    buffer.writeln();
    buffer.writeln(
      '| Code | Field | Value | Manifestations | Source scope | Probable '
      'source file |',
    );
    buffer.writeln('|---|---|---|---|---|---|');
    for (final g in data.integrityIssueGroups) {
      buffer.writeln(
        _row([
          g.code,
          g.field,
          g.value,
          '${g.manifestationCount}',
          g.sourceScope,
          g.probableSourceFile ?? '_(n/a)_',
        ]),
      );
    }
    buffer.writeln();
  }

  final sortedIngredients = [...data.ingredientRows]
    ..sort((a, b) => a.canonicalId.compareTo(b.canonicalId));

  buffer.writeln('## 5. Full selectable-main-ingredient table');
  buffer.writeln();
  buffer.writeln(
    '| canonicalId | displayName | category | taxonomyType | parentId | '
    'rootId | exact | preferred | compatible | substitute | family | '
    'directRecipeCount | adaptableRecipeCount | classification | '
    'ingredientForms# | textures# | cookingMethods# | explicitIdBlock | '
    'constraintMismatch | profileIncomplete | sampleDirectRecipeIds | '
    'sampleAdaptableRecipeIds |',
  );
  buffer.writeln(
    '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|'
    '---|---|---|---|---|',
  );
  for (final row in sortedIngredients) {
    buffer.writeln(
      _row([
        row.canonicalId,
        row.displayName,
        row.category,
        row.taxonomyType,
        row.parentId,
        row.rootId,
        '${row.exact}',
        '${row.preferred}',
        '${row.compatible}',
        '${row.substitute}',
        '${row.family}',
        '${row.directRecipeCount}',
        '${row.adaptableRecipeCount}',
        classificationLabel(row.classification),
        '${row.ingredientForms.length}',
        '${row.textures.length}',
        '${row.supportedCookingMethods.length}',
        '${row.explicitIdBlockPairCount}',
        '${row.constraintMismatchTotal}',
        '${row.profileIncompleteTotal}',
        _list(row.sampleDirectRecipeIds),
        _list(row.sampleAdaptableRecipeIds),
      ]),
    );
  }
  buffer.writeln();

  void writeClassTable(String title, CoverageClassification cls) {
    buffer.writeln('## $title');
    buffer.writeln();
    final rows = sortedIngredients
        .where((r) => r.classification == cls)
        .toList();
    if (rows.isEmpty) {
      buffer.writeln('_(none)_');
      buffer.writeln();
      return;
    }
    buffer.writeln(
      '| canonicalId | displayName | category | taxonomyType | rootId | '
      'exact | preferred | compatible | substitute | family |',
    );
    buffer.writeln('|---|---|---|---|---|---|---|---|---|---|');
    for (final row in rows) {
      buffer.writeln(
        _row([
          row.canonicalId,
          row.displayName,
          row.category,
          row.taxonomyType,
          row.rootId,
          '${row.exact}',
          '${row.preferred}',
          '${row.compatible}',
          '${row.substitute}',
          '${row.family}',
        ]),
      );
    }
    buffer.writeln();
  }

  writeClassTable('6. DIRECT_COVERAGE', CoverageClassification.directCoverage);
  writeClassTable('7. ADAPTABLE_ONLY', CoverageClassification.adaptableOnly);
  writeClassTable('8. NO_COVERAGE', CoverageClassification.noCoverage);

  buffer.writeln(
    '## 9. Exclusion-reason breakdown for NO_COVERAGE ingredients',
  );
  buffer.writeln();
  buffer.writeln(
    '> Restricted to NO_COVERAGE rows (see section 3b for dataset-wide '
    'totals across every classification). `constraintMismatch(form/'
    'texture/method)` and `profileIncomplete(form/texture/method)` are '
    'computed from this ingredient\'s own `ingredientForms`/`textures`/'
    '`supportedCookingMethods` (shown in section 5) — a nonzero '
    '`profileIncomplete` value means the ingredient has no declared data '
    'on that dimension; it is a data-completeness gap, never evidence of a '
    'deliberate rejection. `unverifiedFamily`/`noMatch` never route into '
    'either split.',
  );
  buffer.writeln();
  final noCoverageRows = sortedIngredients
      .where((r) => r.classification == CoverageClassification.noCoverage)
      .toList();
  if (noCoverageRows.isEmpty) {
    buffer.writeln('_(none)_');
  } else {
    buffer.writeln(
      '| canonicalId | displayName | explicitIdBlock | '
      'constraintMismatch(form/texture/method) | '
      'profileIncomplete(form/texture/method) | unverifiedFamily | '
      'noMatch |',
    );
    buffer.writeln('|---|---|---|---|---|---|---|');
    for (final row in noCoverageRows) {
      final cm = row.constraintMismatchPairCounts;
      final pi = row.profileIncompletePairCounts;
      buffer.writeln(
        _row([
          row.canonicalId,
          row.displayName,
          '${row.explicitIdBlockPairCount}',
          '${cm['form'] ?? 0}/${cm['texture'] ?? 0}/${cm['cookingMethod'] ?? 0}',
          '${pi['form'] ?? 0}/${pi['texture'] ?? 0}/${pi['cookingMethod'] ?? 0}',
          '${row.exclusionReasonCounts['unverifiedFamily'] ?? 0}',
          '${row.exclusionReasonCounts['noMatch'] ?? 0}',
        ]),
      );
    }
  }
  buffer.writeln();

  buffer.writeln('## 10. GENERIC_TO_SPECIFIC_ASYMMETRY');
  buffer.writeln();
  buffer.writeln(
    '> Methodology note: this registry parents specific cuts/species/organs '
    'under a `*_family` navigation node as *siblings* of the generic '
    'ingredient (e.g. `pork` and `pork_piece` share `pork_family` as their '
    'parent) rather than nesting them under the generic. `relationship` '
    'below is `true_ancestor` only when `registry.ancestorIdsFor` actually '
    'returns a selectable ingredient with direct coverage; otherwise it is '
    '`generic_sibling` — the nearest generic-typed ingredient sharing the '
    'same immediate parent that has direct coverage. This is a factual '
    'observation, not a substitution claim.',
  );
  buffer.writeln();
  if (data.asymmetryRows.isEmpty) {
    buffer.writeln('_(none)_');
  } else {
    buffer.writeln(
      '| canonicalId | displayName | taxonomyType | parentId | rootId | '
      'nearestCounterpartId (relationship) | counterpartDirect(exact/'
      'preferred/compatible/substitute) | childDirect(exact/preferred/'
      'compatible/substitute) | childFamilyCount | sampleCounterpartRecipeIds |',
    );
    buffer.writeln('|---|---|---|---|---|---|---|---|---|---|');
    for (final row in data.asymmetryRows) {
      final c = row.counterpartDirectTierCounts;
      final d = row.childDirectTierCounts;
      buffer.writeln(
        _row([
          row.canonicalId,
          row.displayName,
          row.taxonomyType,
          row.parentId,
          row.rootId,
          '${row.counterpartId} (${row.relationship})',
          '${c['exact']}/${c['preferred']}/${c['compatible']}/${c['substitute']}',
          '${d['exact']}/${d['preferred']}/${d['compatible']}/${d['substitute']}',
          '${row.childFamilyCount}',
          _list(row.sampleCounterpartRecipeIds),
        ]),
      );
    }
  }
  buffer.writeln();

  buffer.writeln(
    '## 11. Coverage grouped by root taxonomy / category / taxonomyType',
  );
  buffer.writeln();
  Map<String, List<IngredientCoverageRow>> groupBy(
    String Function(IngredientCoverageRow) key,
  ) {
    final map = <String, List<IngredientCoverageRow>>{};
    for (final row in sortedIngredients) {
      map.putIfAbsent(key(row), () => []).add(row);
    }
    return map;
  }

  void writeGroup(String title, Map<String, List<IngredientCoverageRow>> map) {
    buffer.writeln('### $title');
    buffer.writeln();
    buffer.writeln(
      '| Group | Total | DIRECT_COVERAGE | ADAPTABLE_ONLY | NO_COVERAGE | '
      'of which explicitIdBlock | of which constraintMismatch | of which '
      'profileIncomplete |',
    );
    buffer.writeln('|---|---|---|---|---|---|---|---|');
    for (final key in (map.keys.toList()..sort())) {
      final rows = map[key]!;
      int count(CoverageClassification c) =>
          rows.where((r) => r.classification == c).length;
      buffer.writeln(
        _row([
          key.isEmpty ? '_(none)_' : key,
          '${rows.length}',
          '${count(CoverageClassification.directCoverage)}',
          '${count(CoverageClassification.adaptableOnly)}',
          '${count(CoverageClassification.noCoverage)}',
          '${rows.where((r) => r.hasExplicitIdBlock).length}',
          '${rows.where((r) => r.hasConstraintMismatch).length}',
          '${rows.where((r) => r.hasProfileIncomplete).length}',
        ]),
      );
    }
    buffer.writeln();
  }

  writeGroup('By root taxonomy', groupBy((r) => r.rootId));
  writeGroup('By category', groupBy((r) => r.category));
  writeGroup('By taxonomy type', groupBy((r) => r.taxonomyType));

  buffer.writeln('## 12. Recipe metadata table');
  buffer.writeln();
  buffer.writeln(
    '| recipeId | name | heroIngredientId | implicitExactIds | '
    'explicitExactIds | preferredIds | compatibleIds | substituteIds | '
    'familyIds | excludedIds | requiredForms/allowedForms/excludedForms | '
    'cookingMethods | suitabilityNotes |',
  );
  buffer.writeln('|---|---|---|---|---|---|---|---|---|---|---|---|---|');
  final sortedRecipeRows = [...data.recipeRows]
    ..sort((a, b) => a.recipeId.compareTo(b.recipeId));
  for (final row in sortedRecipeRows) {
    buffer.writeln(
      _row([
        row.recipeId,
        row.name,
        row.heroIngredientId,
        _list(row.implicitExactIds),
        _list(row.explicitExactIds),
        _list(row.preferredIds),
        _list(row.compatibleIds),
        _list(row.substituteIds),
        _list(row.familyIds),
        _list(row.excludedIds),
        '${_list(row.requiredForms)} / ${_list(row.allowedForms)} / '
            '${_list(row.excludedForms)}',
        _list(row.cookingMethods),
        row.hasSuitabilityNotes ? 'present' : 'absent',
      ]),
    );
  }
  buffer.writeln();

  buffer.writeln('## 13. Suggested review queue');
  buffer.writeln();
  if (data.reviewQueue.isEmpty) {
    buffer.writeln('_(none)_');
  } else {
    buffer.writeln('| Priority | canonicalId / recipeId | Summary |');
    buffer.writeln('|---|---|---|');
    for (final item in data.reviewQueue) {
      buffer.writeln(_row([item.priority, item.canonicalId, item.summary]));
    }
  }
  buffer.writeln();

  buffer.writeln('## 14. Explicit non-conclusions');
  buffer.writeln();
  buffer.writeln('- No compatibility metadata was added.');
  buffer.writeln('- No recipes were invented.');
  buffer.writeln(
    '- No taxonomy relationship (parent/family/ancestor/generic-sibling) '
    'was treated as a substitution.',
  );
  buffer.writeln('- Zero coverage does not automatically mean a defect.');
  buffer.writeln(
    '- Family coverage does not automatically mean a specific cut/species '
    'is culinarily suitable — production keeps family-tier matches in a '
    'separate adaptable pool for exactly this reason.',
  );
  buffer.writeln(
    '- An `unverifiedFamily` result does not imply the ingredient lacks '
    'authored recipe coverage that it should have — it only means the '
    'recipes it was checked against declared support for other families, '
    'not this one. It is a diagnostic count, not a coverage tier, and it '
    'never demotes an ingredient into a different classification.',
  );
  buffer.writeln(
    '- `noMatch` (a recipe simply never mentions the ingredient) is '
    'expected to be the largest exclusion count for almost every '
    'ingredient and carries no implication on its own.',
  );
  buffer.writeln(
    '- EXPLICIT_ID_BLOCK is always a deliberate, ingredient-specific '
    'authored rejection (an id literally on a recipe\'s '
    'excludedIngredientIds) — worth a look, but still not a claim that the '
    'exclusion is wrong.',
  );
  buffer.writeln(
    '- CONSTRAINT_MISMATCH means the ingredient DOES have declared profile '
    'data that genuinely conflicts with a recipe\'s stated constraint — '
    'worth verifying the conflict itself is correctly authored on either '
    'side, not that the ingredient was "blocked."',
  );
  buffer.writeln(
    '- PROFILE_INCOMPLETE is explicitly NOT evidence of a deliberate '
    'rejection. It means the canonical ingredient has no declared data on '
    'the dimension a recipe required, so production\'s strict "no data '
    'means no match" default excluded the pair. The correction here is '
    'content work (author the missing ingredientForms/textures/'
    'supportedCookingMethods), not a decision to reverse — nothing was '
    'ever decided about this ingredient specifically.',
  );
  buffer.writeln('- Product review is required before any metadata write.');
  buffer.writeln();

  return buffer.toString();
}
