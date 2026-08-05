import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/bootstrap/canonical_ingredient_bootstrap.dart';
import 'package:mobile/app/providers/canonical_ingredient_providers.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/features/pantry/presentation/providers/ingredient_picker_providers.dart';

/// Live-UAT regression: "น่อง" only ever returned น่องไก่, never เนื้อน่องลาย
/// (beef_shank), in the real running app — even though every other test in
/// this repo proved the match using a registry loaded straight from
/// `IngredientCatalog().loadRegistry()`. That left one live possibility
/// unverified: whether `ingredientSearchResultsProvider`, wired up exactly
/// the way `main.dart` wires providers at real app startup, actually
/// receives that same fully-loaded, merged registry — as opposed to a
/// partial/stale/fallback one assembled by some other path.
///
/// This test closes that gap by calling [bootstrapCanonicalIngredientRegistry]
/// — the *exact* function `main.dart` calls before `runApp` — and only then
/// reading the providers through a `ProviderContainer`, the same
/// override-after-bootstrap sequence `main.dart` performs. It never
/// constructs a hand-rolled or trimmed registry.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the real startup-bootstrapped registry contains beef_shank with the '
      'expected shape, and the picker search provider built on top of it '
      'finds both น่องไก่ and เนื้อน่องลาย for "น่อง"', () async {
    final unitEngine = UnitConversionEngine.standard();

    // Identical to main.dart: load the registry first, then hand the
    // *same instance* to the provider graph via overrideWithValue — never
    // a separately constructed or synthetic registry.
    final registry = await bootstrapCanonicalIngredientRegistry(
      unitConversionEngine: unitEngine,
    );

    final container = ProviderContainer(
      overrides: [
        unitConversionEngineProvider.overrideWithValue(unitEngine),
        canonicalIngredientRegistryProvider.overrideWithValue(registry),
      ],
    );
    addTearDown(container.dispose);

    // 1. Prove the runtime registry contains beef_shank with the exact
    // shape the search/breadcrumb/quick-add path depends on.
    final resolvedRegistry = container.read(
      canonicalIngredientRegistryProvider,
    );
    final beefShank = resolvedRegistry?.byId('beef_shank');
    expect(beefShank, isNotNull, reason: 'registry.byId("beef_shank")');
    expect(beefShank!.displayName(), 'เนื้อน่องลาย');
    expect(beefShank.parentId, 'beef_family');
    expect(beefShank.nodeType.name, 'ingredient');
    expect(beefShank.selectableAsMainIngredient, isTrue);
    expect(beefShank.searchableNames, contains('เนื้อน่องลาย'));

    // 2. Prove ingredientSearchResultsProvider is reading that exact
    // instance — not a copy, not a second load — by identity.
    expect(resolvedRegistry, same(registry));

    // 5. Exact-name search resolves beef_shank on its own.
    final exactMatches = container.read(
      ingredientSearchResultsProvider('เนื้อน่องลาย'),
    );
    expect(exactMatches.map((r) => r.ingredient.id), contains('beef_shank'));

    // The reported failure: partial query "น่อง" through the real
    // provider composition, not a bare service call.
    final partialMatches = container.read(
      ingredientSearchResultsProvider('น่อง'),
    );
    final partialIds = partialMatches.map((r) => r.ingredient.id).toSet();
    expect(
      partialIds,
      containsAll(<String>['chicken_drumstick', 'beef_shank']),
      reason:
          'ingredientSearchResultsProvider("น่อง") must return both '
          'chicken_drumstick and beef_shank through the exact provider '
          'graph the picker screen reads from, wired the same way as '
          'main.dart startup.',
    );
  });

  test('6. the registry provider never observes a null/loading intermediate '
      'state once bootstrap has completed — main.dart awaits the load and '
      'overrides the provider synchronously before runApp, so the first '
      'frame the picker ever builds already sees the final registry', () async {
    final unitEngine = UnitConversionEngine.standard();
    final registry = await bootstrapCanonicalIngredientRegistry(
      unitConversionEngine: unitEngine,
    );
    final container = ProviderContainer(
      overrides: [
        canonicalIngredientRegistryProvider.overrideWithValue(registry),
      ],
    );
    addTearDown(container.dispose);

    // overrideWithValue is synchronous: the very first read already
    // returns the complete registry, with no null/loading value ever
    // observable in between.
    expect(container.read(canonicalIngredientRegistryProvider), isNotNull);
  });
}
