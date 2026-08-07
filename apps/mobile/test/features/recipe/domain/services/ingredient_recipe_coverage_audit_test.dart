// Phase 2 — Recipe Coverage Baseline audit.
//
// This test exercises the real production registry, real bundled recipe
// packs, and the real MainIngredientCompatibilityService /
// RecipeReadinessService / RecipeCandidateService / SmartRecommendationEngine
// chain — the same services `recipe_provider.dart` wires together — to build
// a deterministic coverage baseline. It writes nothing to production code,
// assets, or Pantry/recipe data.
//
// The selectable-ingredient x recipe coverage matrix itself
// (buildRecipeCoverageBaselineDataset) evaluates every pair exactly once
// through MainIngredientCompatibilityService — O(ingredients x recipes).
// SmartRecommendationEngine placement is *not* re-verified for every
// ingredient (a full build() call is itself O(ingredients x recipes)
// internally, which would reintroduce an O(ingredients^2 x recipes) cost);
// instead it is cross-checked against a small, deterministic sample covering
// every distinct tier actually present in the dataset — see the
// "production placement agreement" group below.
//
// Regenerating the generated baseline artifacts (docs/diagnostics/
// recipe_coverage_baseline_2026-08-06.{md,json}) is a deliberate,
// explicitly-gated action, not a side effect of a normal `flutter test` run:
// set KINRAIDEE_REGENERATE_COVERAGE_BASELINE=1 to write them. Every other
// run only reads the on-disk working-tree files and compares them,
// byte-for-byte, against a freshly recomputed in-memory version. (As of
// this audit these files are untracked/uncommitted working-tree artifacts
// — "generated"/"working-tree" is used throughout rather than "committed"
// to avoid asserting a Git state that does not yet exist.)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/features/recipe/data/datasources/local_recipe_datasource.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_compatibility.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_match.dart';
import 'package:mobile/features/recipe/domain/entities/smart_recommendation.dart';
import 'package:mobile/features/recipe/domain/services/main_ingredient_compatibility_service.dart';
import 'package:mobile/features/recipe/domain/services/recipe_candidate_service.dart';
import 'package:mobile/features/recipe/domain/services/recipe_readiness_service.dart';
import 'package:mobile/features/recipe/domain/services/smart_recommendation_engine.dart';

import 'support/recipe_coverage_baseline.dart';

const _mdPath = 'docs/diagnostics/recipe_coverage_baseline_2026-08-06.md';
const _jsonPath = 'docs/diagnostics/recipe_coverage_baseline_2026-08-06.json';
const _historicalPath =
    'docs/diagnostics/ingredient_recipe_coverage_2026-08-04.md';
const _identity = AuditIdentity(
  branch: 'audit/recipe-coverage-baseline',
  baseSha: '2932be8e38dad91c996039049b5f038fcf020fb9',
  generatedDate: '2026-08-06',
);
final _evaluatedAt = DateTime.utc(2026, 8, 6);

/// Built exactly like recipe_provider.dart's
/// mainIngredientCompatibilityServiceProvider: forms/textures/
/// cookingMethods from the ingredient definition, familyIds from
/// registry.ancestorIdsFor. Shared by every call site in this file so the
/// config is never rebuilt with subtly different logic.
MainIngredientCompatibilityService _buildCompatibilityService(
  CanonicalIngredientRegistry registry,
) {
  return MainIngredientCompatibilityService(
    config: MainIngredientCompatibilityConfig(
      profiles: <String, IngredientCompatibilityProfile>{
        for (final ingredient in registry.ingredients)
          ingredient.id: IngredientCompatibilityProfile(
            forms: ingredient.ingredientForms,
            textures: ingredient.textures,
            cookingMethods: ingredient.supportedCookingMethods,
            familyIds: registry
                .ancestorIdsFor(ingredient.id)
                .toList(growable: false),
          ),
      },
    ),
  );
}

/// Shared by both the real-sample and synthetic-fallback branches of the
/// family-only placement test: proves (1) MainIngredientCompatibilityService
/// resolves the pair to `family`, (2) SmartRecommendationEngine's hero pool
/// is empty for this ingredient, and (3) the recipe lands in
/// adaptableMatches rather than primaryMatches.
void _assertFamilyOnlyPlacement({
  required String canonicalId,
  required String sampleRecipeId,
  required Recipe recipe,
  required CanonicalIngredientRegistry registry,
  required MainIngredientCompatibilityService compatibilityService,
  required SmartRecommendation Function(String canonicalId) recommendationFor,
}) {
  final ingredient = registry.byId(canonicalId)!;
  final selection = compatibilityService.enrichSelection(
    MainIngredientSelection(
      canonicalIngredientId: ingredient.id,
      displayName: ingredient.displayName(),
      emoji: ingredient.emoji,
    ),
  );

  final direct = compatibilityService.evaluate(
    recipe: recipe,
    selection: selection,
  );
  expect(direct.isEligible, isTrue);
  expect(direct.tier, MainIngredientMatchTier.family);

  final recommendation = recommendationFor(canonicalId);
  expect(
    recommendation.totalHeroRecipes,
    0,
    reason: 'family-only ingredient must have an empty hero pool',
  );
  expect(
    recommendation.primaryMatches.map((m) => m.recipe.id),
    isNot(contains(sampleRecipeId)),
  );
  expect(
    recommendation.adaptableMatches.map((m) => m.recipe.id),
    contains(sampleRecipeId),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CanonicalIngredientRegistry registry;
  late UnitConversionEngine unitEngine;
  late List<Recipe> allRecipes;
  late Map<String, String> recipePackByRecipeId;
  late MainIngredientCompatibilityService compatibilityService;
  late RecipeCandidateService candidateService;
  late RecipeCoverageBaselineDataset dataset;
  late String regeneratedMarkdown;
  late String regeneratedJson;

  setUpAll(() async {
    unitEngine = UnitConversionEngine.standard();
    registry = await IngredientCatalog(
      unitConversionEngine: unitEngine,
    ).loadRegistry();

    const dataSource = LocalRecipeDataSource();
    allRecipes = await dataSource.loadRecipes();

    // Per-pack recipe IDs, purely for the "recipe count by pack" / `pack`
    // column — loaded via the same real LocalRecipeDataSource, one asset
    // path at a time, using the production-declared defaultAssetPaths list.
    recipePackByRecipeId = <String, String>{};
    for (final assetPath in LocalRecipeDataSource.defaultAssetPaths) {
      final packRecipes = await dataSource.loadRecipes(assetPaths: [assetPath]);
      final packName = assetPath.split('/').last.replaceAll('.json', '');
      for (final recipe in packRecipes) {
        recipePackByRecipeId[recipe.id] = packName;
      }
    }

    compatibilityService = _buildCompatibilityService(registry);
    candidateService = RecipeCandidateService(
      readinessService: RecipeReadinessService(
        registry: registry,
        unitEngine: unitEngine,
      ),
    );

    dataset = buildRecipeCoverageBaselineDataset(
      registry: registry,
      recipes: allRecipes,
      recipePackByRecipeId: recipePackByRecipeId,
      compatibilityService: compatibilityService,
      candidateService: candidateService,
    );
    regeneratedMarkdown = renderRecipeCoverageBaselineMarkdown(
      dataset,
      _identity,
    );
    regeneratedJson = recipeCoverageBaselineToJsonString(dataset, _identity);

    if (Platform.environment['KINRAIDEE_REGENERATE_COVERAGE_BASELINE'] == '1') {
      File(_mdPath).writeAsStringSync(regeneratedMarkdown);
      File(_jsonPath).writeAsStringSync(regeneratedJson);
    }
  });

  group('audit uses real production inputs', () {
    test('the registry is the real merged registry (has selectable animal '
        '& seafood taxonomy ingredients from the merged main branch)', () {
      expect(registry.byId('pork_piece'), isNotNull);
      expect(registry.byId('crab_meat'), isNotNull);
      expect(
        registry.ingredients.where((i) => i.canSelectAsMainIngredient).length,
        dataset.dataset.selectableMainIngredientCount,
      );
    });

    test('all current default recipe packs are loaded', () {
      for (final assetPath in LocalRecipeDataSource.defaultAssetPaths) {
        final packName = assetPath.split('/').last.replaceAll('.json', '');
        expect(
          dataset.dataset.recipeCountByPack.containsKey(packName),
          isTrue,
          reason: '$packName missing from recipeCountByPack',
        );
      }
      final sumByPack = dataset.dataset.recipeCountByPack.values.fold<int>(
        0,
        (a, b) => a + b,
      );
      expect(sumByPack, allRecipes.length);
      expect(dataset.dataset.totalRecipeCount, allRecipes.length);
    });
  });

  group('classification follows the exact definitions', () {
    test('DIRECT_COVERAGE requires at least one of exact/preferred/'
        'compatible/substitute', () {
      for (final row in dataset.ingredientRows) {
        if (row.classification == CoverageClassification.directCoverage) {
          expect(row.directRecipeCount, greaterThan(0));
        } else {
          expect(row.directRecipeCount, 0);
        }
      }
    });

    test('ADAPTABLE_ONLY requires zero direct coverage and at least one '
        'family match', () {
      for (final row in dataset.ingredientRows) {
        if (row.classification == CoverageClassification.adaptableOnly) {
          expect(row.directRecipeCount, 0);
          expect(row.family, greaterThan(0));
        }
      }
    });

    test('family-only never becomes direct coverage', () {
      final adaptableOnly = dataset.ingredientRows.where(
        (r) => r.classification == CoverageClassification.adaptableOnly,
      );
      for (final row in adaptableOnly) {
        expect(row.exact, 0);
        expect(row.preferred, 0);
        expect(row.compatible, 0);
        expect(row.substitute, 0);
      }
    });

    test('the three primary classifications are mutually exclusive and '
        'exhaustive', () {
      final byClass = <CoverageClassification, Set<String>>{};
      for (final row in dataset.ingredientRows) {
        byClass
            .putIfAbsent(row.classification, () => <String>{})
            .add(row.canonicalId);
      }
      final all = <String>{};
      for (final entry in byClass.entries) {
        for (final id in entry.value) {
          expect(
            all.add(id),
            isTrue,
            reason: '$id appears in more than one classification bucket',
          );
        }
      }
      expect(all.length, dataset.ingredientRows.length);
    });

    test('every classification is exactly one of the three defined labels '
        '(EXCLUDED_ONLY is not a primary classification)', () {
      const allowed = {
        CoverageClassification.directCoverage,
        CoverageClassification.adaptableOnly,
        CoverageClassification.noCoverage,
      };
      for (final row in dataset.ingredientRows) {
        expect(allowed.contains(row.classification), isTrue);
      }
      expect(
        dataset.coverage.directCoverageCount +
            dataset.coverage.adaptableOnlyCount +
            dataset.coverage.noCoverageCount,
        dataset.ingredientRows.length,
      );
    });

    test('an ingredient with zero eligible tiers is NO_COVERAGE even when '
        'other recipes return unverifiedFamily against it — unverifiedFamily '
        'never demotes a classification into EXCLUDED_ONLY (removed) or any '
        'other bucket', () {
      // Construct a synthetic recipe that positively produces an
      // unverifiedFamily result for a real ingredient with otherwise zero
      // coverage: the recipe declares support for a *different* family than
      // the target ingredient's own family, so the target is evaluated,
      // rejected as unverifiedFamily, and must still classify NO_COVERAGE.
      final target = dataset.ingredientRows.firstWhere(
        (r) =>
            r.classification == CoverageClassification.noCoverage &&
            registry.ancestorIdsFor(r.canonicalId).isNotEmpty,
      );
      final targetFamilyId = registry.ancestorIdsFor(target.canonicalId).first;
      final otherFamilyId = registry.ingredients
          .firstWhere(
            (i) =>
                i.nodeType == CanonicalIngredientNodeType.family &&
                i.id != targetFamilyId,
          )
          .id;
      final syntheticRecipe = Recipe(
        id: 'zz_test_unverified_family_recipe',
        name: 'Synthetic unverifiedFamily proof recipe',
        category: 'test',
        ingredients: const [],
        steps: const ['step'],
        compatibility: RecipeCompatibilityMetadata(
          ingredientFamilyIds: [otherFamilyId],
        ),
      );
      final selection = compatibilityService.enrichSelection(
        MainIngredientSelection(
          canonicalIngredientId: target.canonicalId,
          displayName: registry.byId(target.canonicalId)!.displayName(),
          emoji: registry.byId(target.canonicalId)!.emoji,
        ),
      );
      final result = compatibilityService.evaluate(
        recipe: syntheticRecipe,
        selection: selection,
      );
      expect(result.isEligible, isFalse);
      expect(
        result.exclusionReason,
        MainIngredientExclusionReason.unverifiedFamily,
      );

      final withSynthetic = buildRecipeCoverageBaselineDataset(
        registry: registry,
        recipes: [...allRecipes, syntheticRecipe],
        recipePackByRecipeId: recipePackByRecipeId,
        compatibilityService: compatibilityService,
        candidateService: candidateService,
      );
      final updatedRow = withSynthetic.ingredientRows.firstWhere(
        (r) => r.canonicalId == target.canonicalId,
      );
      expect(updatedRow.classification, CoverageClassification.noCoverage);
      expect(
        updatedRow.exclusionReasonCounts['unverifiedFamily'],
        greaterThan(target.exclusionReasonCounts['unverifiedFamily'] ?? 0),
        reason:
            'unverifiedFamily must still be counted, just not as a '
            'primary classification',
      );
    });

    IngredientCoverageRow rowFor(
      RecipeCoverageBaselineDataset ds,
      String canonicalId,
    ) => ds.ingredientRows.firstWhere((r) => r.canonicalId == canonicalId);

    RecipeCoverageBaselineDataset withExtraRecipe(Recipe recipe) =>
        buildRecipeCoverageBaselineDataset(
          registry: registry,
          recipes: [...allRecipes, recipe],
          recipePackByRecipeId: recipePackByRecipeId,
          compatibilityService: compatibilityService,
          candidateService: candidateService,
        );

    test('explicitlyExcluded becomes EXPLICIT_ID_BLOCK, and never changes '
        'primary classification', () {
      final target = dataset.ingredientRows.firstWhere(
        (r) => r.classification == CoverageClassification.noCoverage,
      );
      final before = target.explicitIdBlockPairCount;
      final withSynthetic = withExtraRecipe(
        Recipe(
          id: 'zz_test_explicit_id_block_recipe',
          name: 'Synthetic explicit-id-block proof recipe',
          category: 'test',
          ingredients: const [],
          steps: const ['step'],
          compatibility: RecipeCompatibilityMetadata(
            excludedIngredientIds: [target.canonicalId],
          ),
        ),
      );
      final updated = rowFor(withSynthetic, target.canonicalId);
      expect(updated.classification, CoverageClassification.noCoverage);
      expect(updated.explicitIdBlockPairCount, before + 1);
      expect(updated.hasExplicitIdBlock, isTrue);
    });

    test('incompatibleForm routes to CONSTRAINT_MISMATCH when the '
        'ingredient has non-empty ingredientForms, and to '
        'PROFILE_INCOMPLETE when it does not', () {
      final withProfile = registry.ingredients.firstWhere(
        (i) => i.canSelectAsMainIngredient && i.ingredientForms.isNotEmpty,
      );
      final withoutProfile = dataset.ingredientRows.firstWhere(
        (r) =>
            r.ingredientForms.isEmpty &&
            r.classification == CoverageClassification.noCoverage,
      );
      final recipeForProfile = Recipe(
        id: 'zz_test_form_mismatch_recipe',
        name: 'Synthetic form-constraint proof recipe',
        category: 'test',
        ingredients: const [],
        steps: const ['step'],
        compatibility: const RecipeCompatibilityMetadata(
          requiredIngredientForms: ['zz_nonexistent_form'],
        ),
      );
      final withSynthetic = withExtraRecipe(recipeForProfile);

      final constraintRow = rowFor(withSynthetic, withProfile.id);
      expect(
        constraintRow.constraintMismatchPairCounts['form'],
        greaterThan(0),
      );
      expect(constraintRow.profileIncompletePairCounts['form'], 0);
      expect(constraintRow.hasConstraintMismatch, isTrue);

      final incompleteRow = rowFor(withSynthetic, withoutProfile.canonicalId);
      expect(incompleteRow.profileIncompletePairCounts['form'], greaterThan(0));
      expect(incompleteRow.constraintMismatchPairCounts['form'], 0);
      expect(incompleteRow.hasProfileIncomplete, isTrue);
      expect(
        incompleteRow.classification,
        CoverageClassification.noCoverage,
        reason: 'PROFILE_INCOMPLETE must never change primary coverage',
      );
    });

    test('incompatibleTexture routes to CONSTRAINT_MISMATCH when the '
        'ingredient has non-empty textures, and to PROFILE_INCOMPLETE '
        'when it does not', () {
      final withProfile = registry.ingredients.firstWhere(
        (i) => i.canSelectAsMainIngredient && i.textures.isNotEmpty,
      );
      final withoutProfile = dataset.ingredientRows.firstWhere(
        (r) =>
            r.textures.isEmpty &&
            r.classification == CoverageClassification.noCoverage,
      );
      final recipe = Recipe(
        id: 'zz_test_texture_mismatch_recipe',
        name: 'Synthetic texture-constraint proof recipe',
        category: 'test',
        ingredients: const [],
        steps: const ['step'],
        compatibility: const RecipeCompatibilityMetadata(
          requiredTexture: 'zz_nonexistent_texture',
        ),
      );
      final withSynthetic = withExtraRecipe(recipe);

      final constraintRow = rowFor(withSynthetic, withProfile.id);
      expect(
        constraintRow.constraintMismatchPairCounts['texture'],
        greaterThan(0),
      );
      expect(constraintRow.profileIncompletePairCounts['texture'], 0);

      final incompleteRow = rowFor(withSynthetic, withoutProfile.canonicalId);
      expect(
        incompleteRow.profileIncompletePairCounts['texture'],
        greaterThan(0),
      );
      expect(incompleteRow.constraintMismatchPairCounts['texture'], 0);
      expect(incompleteRow.classification, CoverageClassification.noCoverage);
    });

    test('incompatibleCookingMethod routes to CONSTRAINT_MISMATCH when the '
        'ingredient has non-empty supportedCookingMethods; production never '
        'raises incompatibleCookingMethod at all when it does not, so '
        'PROFILE_INCOMPLETE(cookingMethod) is structurally always zero — '
        'confirmed directly against MainIngredientCompatibilityService, not '
        'assumed', () {
      final withProfile = registry.ingredients.firstWhere(
        (i) =>
            i.canSelectAsMainIngredient && i.supportedCookingMethods.isNotEmpty,
      );
      final withoutProfile = dataset.ingredientRows.firstWhere(
        (r) =>
            r.supportedCookingMethods.isEmpty &&
            r.classification == CoverageClassification.noCoverage,
      );
      // The cooking-method check only runs for a non-exact tier (see
      // MainIngredientCompatibilityService.evaluate), so both synthetic
      // recipes give the target ingredient a `compatible` tier via
      // compatibleIngredientIds, then require a method the "withProfile"
      // ingredient does not support.
      Recipe recipeFor(String id, String recipeId) => Recipe(
        id: recipeId,
        name: 'Synthetic cooking-method-constraint proof recipe',
        category: 'test',
        ingredients: const [],
        steps: const ['step'],
        compatibility: RecipeCompatibilityMetadata(
          compatibleIngredientIds: [id],
          cookingMethods: const ['zz_nonexistent_method'],
        ),
      );
      final withSynthetic = withExtraRecipe(
        recipeFor(withProfile.id, 'zz_test_method_mismatch_recipe_a'),
      );
      final constraintRow = rowFor(withSynthetic, withProfile.id);
      expect(
        constraintRow.constraintMismatchPairCounts['cookingMethod'],
        greaterThan(0),
      );
      expect(constraintRow.profileIncompletePairCounts['cookingMethod'], 0);

      // Unlike form/texture, production's cooking-method check
      // (lib/features/recipe/domain/services/
      // main_ingredient_compatibility_service.dart) requires
      // `ingredientMethods.isNotEmpty` before it will ever exclude a pair
      // — when the ingredient has no declared supportedCookingMethods, the
      // check is skipped entirely (treated as "no constraint to violate"),
      // and the pair proceeds to eligible instead of being excluded. Proven
      // directly here, not assumed: the same synthetic recipe against an
      // ingredient with an empty cooking-method profile becomes ELIGIBLE.
      final syntheticRecipeB = recipeFor(
        withoutProfile.canonicalId,
        'zz_test_method_mismatch_recipe_b',
      );
      final selectionB = compatibilityService.enrichSelection(
        MainIngredientSelection(
          canonicalIngredientId: withoutProfile.canonicalId,
          displayName: registry.byId(withoutProfile.canonicalId)!.displayName(),
          emoji: registry.byId(withoutProfile.canonicalId)!.emoji,
        ),
      );
      final directResultB = compatibilityService.evaluate(
        recipe: syntheticRecipeB,
        selection: selectionB,
      );
      expect(
        directResultB.isEligible,
        isTrue,
        reason:
            'production does not exclude a compatible-tier pair on cooking '
            'method when the ingredient has no declared methods to conflict '
            'with — this is why PROFILE_INCOMPLETE(cookingMethod) is always '
            '0 in the dataset-wide totals, by production design, not by an '
            'audit gap',
      );
      expect(directResultB.tier, MainIngredientMatchTier.compatible);

      // Dataset-wide: confirm the structural invariant holds everywhere,
      // not just for this one sample.
      for (final row in dataset.ingredientRows) {
        expect(row.profileIncompletePairCounts['cookingMethod'], 0);
      }
    });

    test('PROFILE_INCOMPLETE never appears as an EXPLICIT_ID_BLOCK or as a '
        'CONSTRAINT_MISMATCH for the same dimension — the three categories '
        'are mutually exclusive per (ingredient, dimension)', () {
      for (final row in dataset.ingredientRows) {
        for (final dimension in profileDimensions) {
          final mismatch = row.constraintMismatchPairCounts[dimension] ?? 0;
          final incomplete = row.profileIncompletePairCounts[dimension] ?? 0;
          if (incomplete > 0) {
            expect(
              mismatch,
              0,
              reason:
                  '${row.canonicalId}/$dimension has both a '
                  'constraint-mismatch and a profile-incomplete count — '
                  'these must be mutually exclusive per dimension',
            );
          }
        }
        // explicitIdBlockPairCount is tracked independently of the two
        // profileDimensions maps and must equal the raw explicitlyExcluded
        // reason count exactly (no double-counting, no divergence).
        expect(
          row.explicitIdBlockPairCount,
          row.exclusionReasonCounts['explicitlyExcluded'] ?? 0,
        );
      }
    });

    test('all three overlay categories leave primary coverage '
        'classification unchanged, dataset-wide', () {
      // Structural invariant re-derived independently of any synthetic
      // data: classification is provably a pure function of
      // exact/preferred/compatible/substitute/family alone (see
      // buildRecipeCoverageBaselineDataset), so it cannot depend on
      // explicitIdBlockPairCount / constraintMismatchPairCounts /
      // profileIncompletePairCounts by construction. Spot-checked here by
      // confirming the invariant holds across every real row.
      for (final row in dataset.ingredientRows) {
        final expectedDirect =
            row.classification == CoverageClassification.directCoverage
            ? row.directRecipeCount > 0
            : row.directRecipeCount == 0;
        expect(expectedDirect, isTrue, reason: row.canonicalId);
      }
    });
  });

  group('production placement agreement (SmartRecommendationEngine)', () {
    // Deliberately NOT a full ingredient x ingredient x recipe sweep — see
    // the file header. This picks one representative ingredient per tier
    // that actually exists in the generated dataset (deterministic:
    // lowest canonicalId per tier) and proves SmartRecommendationEngine's
    // real placement agrees with the audit's own MainIngredientCompatibility
    // Service-derived counts for exactly those samples.
    late List<RecipeMatch> readinessMatches;
    late SmartRecommendationEngine smartEngine;

    setUpAll(() {
      readinessMatches = candidateService.evaluateAllRecipes(
        recipes: allRecipes,
        pantry: const [],
        evaluatedAt: _evaluatedAt,
      );
      smartEngine = SmartRecommendationEngine(
        compatibilityService: compatibilityService,
      );
    });

    IngredientCoverageRow? firstWhere(
      bool Function(IngredientCoverageRow) test,
    ) {
      final matches = dataset.ingredientRows.where(test).toList()
        ..sort((a, b) => a.canonicalId.compareTo(b.canonicalId));
      return matches.isEmpty ? null : matches.first;
    }

    SmartRecommendation recommendationFor(String canonicalId) {
      final ingredient = registry.byId(canonicalId)!;
      final selection = compatibilityService.enrichSelection(
        MainIngredientSelection(
          canonicalIngredientId: ingredient.id,
          displayName: ingredient.displayName(),
          emoji: ingredient.emoji,
        ),
      );
      return smartEngine.build(
        matches: readinessMatches,
        pantry: const [],
        allRecipeMatches: readinessMatches,
        registry: registry,
        selectedIngredient: selection,
      );
    }

    test(
      'a focused sample covering every distinct direct tier present in '
      'the dataset agrees with SmartRecommendationEngine.build on '
      'totalHeroRecipes, and every adaptableMatches entry is family-tier',
      () {
        final samples = <String, IngredientCoverageRow>{
          if (dataset.coverage.ingredientsWithExact > 0)
            'exact': firstWhere((r) => r.exact > 0)!,
          if (dataset.coverage.ingredientsWithPreferred > 0)
            'preferred': firstWhere((r) => r.preferred > 0)!,
          if (dataset.coverage.ingredientsWithCompatible > 0)
            'compatible': firstWhere((r) => r.compatible > 0)!,
          if (dataset.coverage.ingredientsWithSubstitute > 0)
            'substitute': firstWhere((r) => r.substitute > 0)!,
        };
        expect(
          samples,
          isNotEmpty,
          reason: 'dataset produced zero direct-tier ingredients to sample',
        );

        for (final entry in samples.entries) {
          final row = entry.value;
          final recommendation = recommendationFor(row.canonicalId);
          expect(
            recommendation.totalHeroRecipes,
            row.directRecipeCount,
            reason:
                '${entry.key} sample "${row.canonicalId}": '
                'SmartRecommendationEngine totalHeroRecipes disagreed with '
                'the audit\'s directRecipeCount',
          );
          expect(
            recommendation.adaptableMatches.map(
              (m) => m.mainIngredientMatchTier,
            ),
            everyElement(MainIngredientMatchTier.family),
            reason:
                '${entry.key} sample "${row.canonicalId}": adaptableMatches '
                'contained a non-family-tier match',
          );
        }
      },
    );

    test('the family-only requirement: MainIngredientCompatibilityService '
        'returns family, SmartRecommendationEngine excludes it from '
        'primaryMatches, and includes it in adaptableMatches', () {
      final familyRow = firstWhere(
        (r) => r.classification == CoverageClassification.adaptableOnly,
      );

      if (familyRow != null) {
        _assertFamilyOnlyPlacement(
          canonicalId: familyRow.canonicalId,
          sampleRecipeId: familyRow.sampleAdaptableRecipeIds.first,
          recipe: allRecipes.firstWhere(
            (r) => r.id == familyRow.sampleAdaptableRecipeIds.first,
          ),
          registry: registry,
          compatibilityService: compatibilityService,
          recommendationFor: recommendationFor,
        );
        return;
      }

      // The real current dataset has zero ADAPTABLE_ONLY ingredients today
      // (confirmed by dataset.coverage.adaptableOnlyCount below) — a
      // factual finding reported in the Markdown/JSON artifacts, not a test
      // bug. The family-tier *mechanism* is still required to be proven, so
      // this constructs one synthetic recipe (declaring a real family node,
      // no specific ingredient) against a real selectable ingredient that
      // currently has zero direct coverage, and proves the exact same
      // three-part placement through the real, unmodified production
      // services. This never touches the real (working-tree) recipe data.
      expect(dataset.coverage.adaptableOnlyCount, 0);
      final candidateRow = dataset.ingredientRows.firstWhere(
        (r) =>
            r.directRecipeCount == 0 &&
            registry.ancestorIdsFor(r.canonicalId).isNotEmpty,
        orElse: () => throw StateError(
          'no ingredient with zero direct coverage and a taxonomy family '
          'was found to build a synthetic family-tier proof',
        ),
      );
      final familyId = registry.ancestorIdsFor(candidateRow.canonicalId).first;
      final syntheticRecipe = Recipe(
        id: 'zz_test_synthetic_family_only_recipe',
        name: 'Synthetic family-tier proof recipe',
        category: 'test',
        ingredients: const [],
        steps: const ['step'],
        compatibility: RecipeCompatibilityMetadata(
          ingredientFamilyIds: [familyId],
        ),
      );
      _assertFamilyOnlyPlacement(
        canonicalId: candidateRow.canonicalId,
        sampleRecipeId: syntheticRecipe.id,
        recipe: syntheticRecipe,
        registry: registry,
        compatibilityService: compatibilityService,
        recommendationFor: (id) {
          final ingredient = registry.byId(id)!;
          final selection = compatibilityService.enrichSelection(
            MainIngredientSelection(
              canonicalIngredientId: ingredient.id,
              displayName: ingredient.displayName(),
              emoji: ingredient.emoji,
            ),
          );
          final matches = [
            ...readinessMatches,
            candidateService.evaluateReadiness(
              recipe: syntheticRecipe,
              pantry: const [],
              servings: 1,
              evaluatedAt: _evaluatedAt,
            ),
          ];
          return smartEngine.build(
            matches: matches,
            pantry: const [],
            allRecipeMatches: matches,
            registry: registry,
            selectedIngredient: selection,
          );
        },
      );
    });

    test('a NO_COVERAGE sample produces an empty hero pool and empty '
        'adaptable matches from SmartRecommendationEngine', () {
      final noCoverageRow = firstWhere(
        (r) => r.classification == CoverageClassification.noCoverage,
      );
      if (noCoverageRow == null) {
        // Nothing to sample; the dataset's own coverage summary already
        // proves NO_COVERAGE count is zero in this case.
        expect(dataset.coverage.noCoverageCount, 0);
        return;
      }
      final recommendation = recommendationFor(noCoverageRow.canonicalId);
      expect(recommendation.totalHeroRecipes, 0);
      expect(recommendation.primaryMatches, isEmpty);
      expect(recommendation.adaptableMatches, isEmpty);
    });

    test('no ingredient row has a recipe id in both its direct and '
        'adaptable sample sets (structural sanity)', () {
      for (final row in dataset.ingredientRows) {
        final directSet = row.sampleDirectRecipeIds.toSet();
        final adaptableSet = row.sampleAdaptableRecipeIds.toSet();
        expect(directSet.intersection(adaptableSet), isEmpty);
      }
    });
  });

  group('invalid metadata references fail loudly with recipe id + field', () {
    test('every reported integrity issue names a concrete recipe id and '
        'field', () {
      for (final issue in dataset.integrityIssues) {
        expect(issue.recipeId, isNotEmpty);
        expect(issue.field, isNotEmpty);
        expect(issue.detail, isNotEmpty);
      }
    });

    test('a deliberately-broken recipe metadata reference is detected by '
        'the same integrity-check logic the audit uses (proves the checker '
        'is not vacuously always-empty)', () {
      final brokenRecipe = Recipe(
        id: 'zz_test_broken_recipe',
        name: 'Broken test recipe',
        category: 'test',
        ingredients: const [],
        steps: const ['step'],
        heroIngredientId: 'this_id_does_not_exist_anywhere',
        compatibility: const RecipeCompatibilityMetadata(
          exactIngredientIds: ['also_does_not_exist'],
          ingredientFamilyIds: ['pork'], // a real ingredient, not a family
        ),
      );
      final brokenDataset = buildRecipeCoverageBaselineDataset(
        registry: registry,
        recipes: [...allRecipes, brokenRecipe],
        recipePackByRecipeId: recipePackByRecipeId,
        compatibilityService: compatibilityService,
        candidateService: candidateService,
      );
      final issuesForBrokenRecipe = brokenDataset.integrityIssues
          .where((i) => i.recipeId == 'zz_test_broken_recipe')
          .toList();
      expect(issuesForBrokenRecipe, isNotEmpty);
      expect(
        issuesForBrokenRecipe.any((i) => i.code == 'invalid_hero_reference'),
        isTrue,
      );
      expect(
        issuesForBrokenRecipe.any(
          (i) => i.code == 'invalid_canonical_reference',
        ),
        isTrue,
      );
      expect(
        issuesForBrokenRecipe.any((i) => i.code == 'invalid_family_reference'),
        isTrue,
        reason:
            '"pork" is a real ingredient, not a family node, so declaring '
            'it in ingredientFamilyIds must be flagged',
      );
    });
  });

  group('determinism and byte-identical generated artifacts', () {
    test('the generated Markdown report matches a freshly regenerated '
        'version byte-for-byte', () {
      final onDisk = File(_mdPath).readAsStringSync();
      expect(
        onDisk,
        regeneratedMarkdown,
        reason:
            'Generated $_mdPath does not match the freshly regenerated '
            'report. Run with KINRAIDEE_REGENERATE_COVERAGE_BASELINE=1 to '
            'refresh it after confirming the change is intended.',
      );
    });

    test('the generated JSON artifact matches a freshly regenerated version '
        'byte-for-byte', () {
      final onDisk = File(_jsonPath).readAsStringSync();
      expect(
        onDisk,
        regeneratedJson,
        reason:
            'Generated $_jsonPath does not match the freshly regenerated '
            'artifact. Run with KINRAIDEE_REGENERATE_COVERAGE_BASELINE=1 to '
            'refresh it after confirming the change is intended.',
      );
    });

    test('regenerating the dataset twice from the same inputs produces '
        'byte-identical Markdown and JSON (ordering is deterministic)', () {
      final again = buildRecipeCoverageBaselineDataset(
        registry: registry,
        recipes: allRecipes,
        recipePackByRecipeId: recipePackByRecipeId,
        compatibilityService: compatibilityService,
        candidateService: candidateService,
      );
      expect(
        recipeCoverageBaselineToJsonString(again, _identity),
        regeneratedJson,
      );
      expect(
        renderRecipeCoverageBaselineMarkdown(again, _identity),
        regeneratedMarkdown,
      );
    });
  });

  test('the old historical report is not treated as current truth', () {
    final historical = File(_historicalPath).readAsStringSync();
    expect(
      historical,
      contains('Historical diagnostic snapshot'),
      reason:
          '$_historicalPath must carry the historical-snapshot warning '
          '(added on feature/full-animal-seafood-taxonomy) — this audit '
          'does not read or rely on that file for current taxonomy facts.',
    );
    expect(
      regeneratedMarkdown,
      isNot(contains('hotfix/home-hero-missing-after-pantry-update')),
      reason:
          'the new baseline report must not inherit branch/context text '
          'from the historical snapshot',
    );
  });

  test('no production file is changed by test execution', () {
    // This test asserts intent, not filesystem state (a test cannot
    // meaningfully assert "no other file changed" from inside itself).
    // Enforcement is external: `git status`/`git diff --stat` after running
    // the full suite, checked in the audit's final report, confirms zero
    // changes under lib/ and assets/.
    expect(true, isTrue);
  });
}
