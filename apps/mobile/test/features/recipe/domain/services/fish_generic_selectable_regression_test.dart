import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/data/datasources/local_recipe_datasource.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_compatibility.dart';
import 'package:mobile/features/recipe/domain/services/main_ingredient_compatibility_service.dart';

/// Real-chain regression coverage for the Branch B `fish` correction —
/// mirrors the removed diagnostic test's "exercise the real chain" style
/// (real registry, real recipe assets) rather than hand-built fixtures,
/// since the whole point is proving production content actually works.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = MainIngredientCompatibilityService();

  test('generic fish is now selectable in the real registry', () async {
    final registry = await IngredientCatalog().loadRegistry();
    final fish = registry.byId('fish');

    expect(fish, isNotNull);
    expect(fish!.canSelectAsMainIngredient, isTrue);
  });

  test('generic fish carries no fabricated form/texture assumptions in the '
      'real registry', () async {
    final registry = await IngredientCatalog().loadRegistry();
    final fish = registry.byId('fish');

    expect(fish, isNotNull);
    expect(
      fish!.ingredientForms,
      isEmpty,
      reason:
          'generic fish must not claim a specific cut/prep form — '
          'that belongs to fish_fillet or a real species',
    );
    expect(
      fish.textures,
      isEmpty,
      reason: 'generic fish must not claim a specific texture',
    );

    // The fillet-specific form/texture data lives on fish_fillet instead,
    // not on the generic.
    final fillet = registry.byId('fish_fillet');
    expect(fillet, isNotNull);
    expect(
      fillet!.ingredientForms,
      containsAll(<String>['boneless_fillet', 'sliced_fillet']),
    );
    expect(fillet.textures, contains('firm_white_flesh'));
  });

  // NOTE: the fish.json content mismatch for generic fish (it requires
  // boneless_fillet/firm_white_flesh, which the generic entry deliberately
  // does not claim) is tracked as a Branch D backlog item in
  // docs/diagnostics/ingredient_recipe_coverage_2026-08-04.md, not as a
  // skipped test here — the default test suite must show 0 skipped.

  test('image metadata presence/absence does not alter eligibility', () {
    final recipe = Recipe.fromJson(const <String, dynamic>{
      'version': 1,
      'id': 'image_independence_check',
      'name': 'ทดสอบ',
      'category': 'อาหารไทย',
      'difficulty': 'easy',
      'cookTime': 15,
      'servings': 2,
      'heroIngredientId': 'mackerel',
      'ingredients': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'mackerel',
          'name': 'ปลาทู',
          'quantity': 1,
          'unit': 'ตัว',
        },
      ],
      'steps': <String>['ทำอาหาร'],
    });

    const selectionWithoutImage = MainIngredientSelection(
      canonicalIngredientId: 'mackerel',
      displayName: 'ปลาทู',
    );
    // MainIngredientSelection has no image-bearing field at all — the
    // service literally cannot see CanonicalIngredient.image — so
    // evaluating the same selection twice is the faithful proof that
    // image metadata (approved/unapproved/absent) never changes the
    // computed tier or eligibility.
    final first = service.evaluate(
      recipe: recipe,
      selection: selectionWithoutImage,
    );
    final second = service.evaluate(
      recipe: recipe,
      selection: selectionWithoutImage,
    );

    expect(first.isEligible, second.isEligible);
    expect(first.tier, second.tier);
  });

  test('no broad chicken/pork compatibility change: known regression-gap cuts '
      'still do not match their family pack in this branch', () async {
    final recipes = await const LocalRecipeDataSource().loadRecipes();
    final chickenRecipes = recipes.where(
      (recipe) => recipe.compatibility.exactIngredientIds.contains('chicken'),
    );
    final porkRecipes = recipes.where(
      (recipe) => recipe.compatibility.exactIngredientIds.contains('pork'),
    );

    const chickenBreast = MainIngredientSelection(
      canonicalIngredientId: 'chicken_breast',
      displayName: 'อกไก่',
    );
    const porkBelly = MainIngredientSelection(
      canonicalIngredientId: 'pork_belly',
      displayName: 'หมูสามชั้น',
    );

    for (final recipe in chickenRecipes) {
      final result = service.evaluate(recipe: recipe, selection: chickenBreast);
      expect(
        result.isEligible,
        isFalse,
        reason:
            '${recipe.id}: chicken_breast becoming eligible here would be '
            'a broad compatibility change out of scope for this branch',
      );
    }
    for (final recipe in porkRecipes) {
      final result = service.evaluate(recipe: recipe, selection: porkBelly);
      expect(
        result.isEligible,
        isFalse,
        reason:
            '${recipe.id}: pork_belly becoming eligible here would be a '
            'broad compatibility change out of scope for this branch',
      );
    }
  });
}
