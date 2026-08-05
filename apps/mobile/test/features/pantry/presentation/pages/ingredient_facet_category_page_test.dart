import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/canonical_ingredient_providers.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/providers/pantry_provider.dart';
import 'package:mobile/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:mobile/features/pantry/presentation/pages/ingredient_facet_category_page.dart';
import 'package:mobile/features/pantry/presentation/providers/ingredient_picker_providers.dart';
import 'package:mobile/features/pantry/presentation/widgets/ingredient_option_tile.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';

/// A flat browse facet (e.g. "อาหารแปรรูป", "ผัก") — standard tap-to-open,
/// canonical-ID selection, no nested navigation, no duplicate canonical
/// identity ever created here (see ingredient_browse_facet_test.dart for
/// the domain-layer proof of that).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CanonicalIngredientRegistry registry;

  setUpAll(() async {
    registry = await IngredientCatalog().loadRegistry();
  });

  Future<ProviderContainer> pumpFacetPage(
    WidgetTester tester, {
    required String facetId,
    List<Ingredient> pantry = const <Ingredient>[],
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        canonicalIngredientRegistryProvider.overrideWithValue(registry),
        pantryRepositoryProvider.overrideWithValue(
          _FixturePantryRepository(pantry),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: IngredientFacetCategoryPage(facetId: facetId)),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('a flat facet (ผัก) lists its members with no nested-family '
      'cards, only leaf ingredient tiles', (tester) async {
    await pumpFacetPage(tester, facetId: 'vegetables');

    expect(
      find.byKey(const ValueKey<String>('ingredient-picker-option-carrot')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('ingredient-facet-list-vegetables')),
      findsOneWidget,
    );
  });

  testWidgets('moo_yor shows its own real taxonomy ancestry (หมู) as the '
      'row breadcrumb, not the facet label it is browsed under', (
    tester,
  ) async {
    await pumpFacetPage(tester, facetId: 'processed_food');

    expect(
      find.byKey(const ValueKey<String>('ingredient-picker-option-moo_yor')),
      findsOneWidget,
    );
    expect(find.text('หมู'), findsOneWidget);
  });

  testWidgets('tapping a facet member toggles selection and shows the '
      'sticky continue bar', (tester) async {
    final container = await pumpFacetPage(tester, facetId: 'vegetables');

    await tester.tap(
      find.byKey(const ValueKey<String>('ingredient-picker-option-carrot')),
    );
    await tester.pump();

    expect(container.read(ingredientPickerSelectionProvider), <String>{
      'carrot',
    });
    expect(
      find.byKey(const ValueKey<String>('ingredient-picker-continue-button')),
      findsOneWidget,
    );
  });

  testWidgets('an already-in-pantry facet member shows มีแล้ว and is '
      'disabled', (tester) async {
    final now = DateTime(2026, 8, 4);
    await pumpFacetPage(
      tester,
      facetId: 'vegetables',
      pantry: <Ingredient>[
        Ingredient(
          id: 'lot-1',
          name: 'แครอท',
          category: 'vegetable',
          emoji: '',
          quantity: 2,
          unit: 'หัว',
          createdAt: now,
          updatedAt: now,
          canonicalIngredientId: 'carrot',
          canonicalUnitId: 'piece',
          canonicalMappingStatus: CanonicalMappingStatus.mapped,
        ),
      ],
    );

    expect(
      find.byKey(
        const ValueKey<String>('ingredient-picker-already-owned-carrot'),
      ),
      findsOneWidget,
    );
    final tile = tester.widget<ListTile>(
      find.byKey(const ValueKey<String>('ingredient-picker-option-carrot')),
    );
    expect(tile.enabled, isFalse);
  });

  testWidgets(
    'zero-recipe-coverage ingredients remain selectable in a facet, same '
    'as in Browse taxonomy navigation',
    (tester) async {
      // rice_bran_oil has no recipe pack referencing it in this branch —
      // the facet list must not know or care about that.
      final container = await pumpFacetPage(tester, facetId: 'oils');

      expect(
        find.byKey(
          const ValueKey<String>('ingredient-picker-option-rice_bran_oil'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('ingredient-picker-option-rice_bran_oil'),
        ),
      );
      await tester.pump();
      expect(container.read(ingredientPickerSelectionProvider), <String>{
        'rice_bran_oil',
      });
    },
  );

  testWidgets(
    'a canonical id reachable through two different facets (canned_fish: '
    'processed_food and ready_to_eat) shows the same selected state in '
    'both — never a duplicate selection via two paths',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          canonicalIngredientRegistryProvider.overrideWithValue(registry),
          pantryRepositoryProvider.overrideWithValue(
            _FixturePantryRepository(const <Ingredient>[]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: IngredientFacetCategoryPage(facetId: 'processed_food'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('ingredient-picker-option-canned_fish'),
        ),
      );
      await tester.pump();
      expect(
        container.read(ingredientPickerSelectionProvider),
        contains('canned_fish'),
      );

      // Same session, different facet screen for the same shared id.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: IngredientFacetCategoryPage(facetId: 'ready_to_eat'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tile = tester.widget<IngredientOptionTile>(
        find.byWidgetPredicate(
          (widget) =>
              widget is IngredientOptionTile &&
              widget.ingredient.id == 'canned_fish',
        ),
      );
      expect(tile.selected, isTrue);
      // Still exactly one id in the session set — tapping it from the
      // first facet never created a second, facet-scoped entry.
      expect(
        container
            .read(ingredientPickerSelectionProvider)
            .where((id) => id == 'canned_fish'),
        hasLength(1),
      );
    },
  );
}

class _FixturePantryRepository implements PantryRepository {
  _FixturePantryRepository(this._ingredients);
  final List<Ingredient> _ingredients;

  @override
  Set<String> getFavoriteIngredientNames() => const <String>{};

  @override
  List<Ingredient> getIngredients() => List<Ingredient>.of(_ingredients);

  @override
  Future<void> saveFavoriteIngredientNames(Set<String> names) async {}
}
