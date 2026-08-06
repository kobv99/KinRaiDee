import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/canonical_ingredient_providers.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/providers/pantry_provider.dart';
import 'package:mobile/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:mobile/features/pantry/presentation/pages/ingredient_facet_category_page.dart';
import 'package:mobile/features/pantry/presentation/pages/ingredient_family_page.dart';
import 'package:mobile/features/pantry/presentation/pages/ingredient_picker_entry_page.dart';
import 'package:mobile/features/pantry/presentation/pages/ingredient_quick_add_page.dart';
import 'package:mobile/features/pantry/presentation/providers/ingredient_picker_providers.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CanonicalIngredientRegistry registry;

  setUpAll(() async {
    registry = await IngredientCatalog().loadRegistry();
  });

  Future<ProviderContainer> pumpEntryPage(
    WidgetTester tester, {
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
        child: const MaterialApp(home: IngredientPickerEntryPage()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('root screen shows exactly 9 family cards', (tester) async {
    await pumpEntryPage(tester);

    for (final id in <String>[
      'pork_family',
      'chicken_family',
      'beef_family',
      'fish_family',
      'shrimp_family',
      'crab_family',
      'squid_family',
      'shellfish_family',
      'other_seafood_family',
    ]) {
      expect(
        find.byKey(ValueKey<String>('ingredient-picker-family-card-$id')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const ValueKey<String>('ingredient-picker-family-card-fish')),
      findsNothing,
    );
  });

  testWidgets(
    'root screen also shows all 6 browse facet cards (15 tiles total)',
    (tester) async {
      await pumpEntryPage(tester);

      for (final id in <String>[
        'dry_goods',
        'processed_food',
        'ready_to_eat',
        'vegetables',
        'oils',
        'seasonings',
      ]) {
        expect(
          find.byKey(ValueKey<String>('ingredient-picker-family-card-$id')),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets(
    'tapping a browse facet card opens the flat facet category page',
    (tester) async {
      await pumpEntryPage(tester);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('ingredient-picker-family-card-vegetables'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IngredientFacetCategoryPage), findsOneWidget);
    },
  );

  testWidgets('tapping a family card navigates without adding anything', (
    tester,
  ) async {
    final container = await pumpEntryPage(tester);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('ingredient-picker-family-card-pork_family'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IngredientFamilyPage), findsOneWidget);
    expect(container.read(pantryProvider), isEmpty);
  });

  testWidgets('typing a search query never selects anything by itself', (
    tester,
  ) async {
    final container = await pumpEntryPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('ingredient-picker-search-field')),
      'น่อง',
    );
    await tester.pumpAndSettle();

    expect(container.read(ingredientPickerSelectionProvider), isEmpty);
    // Both ambiguous matches are shown, each with a distinct breadcrumb.
    expect(find.textContaining('น่องไก่'), findsOneWidget);
    expect(find.textContaining('เนื้อน่องลาย'), findsOneWidget);
  });

  testWidgets('search "น่อง" against the real bundled registry shows both '
      'results with the exact full root-first breadcrumbs', (tester) async {
    await pumpEntryPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('ingredient-picker-search-field')),
      'น่อง',
    );
    await tester.pumpAndSettle();

    // The full breadcrumb (ancestors + the ingredient's own name) is the
    // tile's only/primary text — no separate duplicated title.
    expect(find.text('ไก่ › น่องไก่'), findsOneWidget);
    expect(find.text('เนื้อวัว › เนื้อน่องลาย'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>(
          'ingredient-picker-search-result-chicken_drumstick',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('ingredient-picker-search-result-beef_shank'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping a search result opens the direct quick-add editor, '
      'never the Browse selection', (tester) async {
    final container = await pumpEntryPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('ingredient-picker-search-field')),
      'อกไก่',
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'ingredient-picker-search-result-chicken_breast',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IngredientQuickAddPage), findsOneWidget);
    // Search never joins the Browse multi-select draft.
    expect(container.read(ingredientPickerSelectionProvider), isEmpty);
    expect(
      find.byKey(const ValueKey<String>('ingredient-picker-continue-button')),
      findsNothing,
    );
  });

  testWidgets(
    'searching hides the browse category grid entirely — only the compact '
    'search-result list is shown',
    (tester) async {
      await pumpEntryPage(tester);

      expect(
        find.byKey(const ValueKey<String>('ingredient-picker-family-grid')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('ingredient-picker-search-field')),
        'น่อง',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('ingredient-picker-family-grid')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('ingredient-picker-family-card-pork_family'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('ingredient-picker-search-results')),
        findsOneWidget,
      );

      // Clearing the query restores browse mode.
      await tester.enterText(
        find.byKey(const ValueKey<String>('ingredient-picker-search-field')),
        '',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('ingredient-picker-family-grid')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'query "หมูสันใน" finds pork tenderloin (สันในหมู) through its alias, '
    'and tapping it opens the quick-add editor with only quantity/unit '
    'input — no category selection, no ingredient cards',
    (tester) async {
      await pumpEntryPage(tester);

      await tester.enterText(
        find.byKey(const ValueKey<String>('ingredient-picker-search-field')),
        'หมูสันใน',
      );
      await tester.pumpAndSettle();

      expect(find.text('หมู › สันในหมู'), findsOneWidget);
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'ingredient-picker-search-result-pork_tenderloin',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IngredientQuickAddPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('ingredient-quick-add-quantity')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('ingredient-quick-add-unit')),
        findsOneWidget,
      );
      // No family/category grid and no browse ingredient-option cards leak
      // into the quick-add screen.
      expect(
        find.byKey(const ValueKey<String>('ingredient-picker-family-grid')),
        findsNothing,
      );
      expect(find.textContaining('ingredient-picker-option'), findsNothing);
    },
  );

  testWidgets('an already-in-pantry search result shows มีแล้ว and is '
      'disabled', (tester) async {
    final now = DateTime(2026, 8, 4);
    await pumpEntryPage(
      tester,
      pantry: <Ingredient>[
        Ingredient(
          id: 'lot-1',
          name: 'อกไก่',
          category: 'protein',
          emoji: '',
          quantity: 300,
          unit: 'กรัม',
          createdAt: now,
          updatedAt: now,
          canonicalIngredientId: 'chicken_breast',
          canonicalUnitId: 'gram',
          canonicalMappingStatus: CanonicalMappingStatus.mapped,
        ),
      ],
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('ingredient-picker-search-field')),
      'อกไก่',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>(
          'ingredient-picker-already-owned-chicken_breast',
        ),
      ),
      findsOneWidget,
    );

    final tile = tester.widget<ListTile>(
      find.byKey(
        const ValueKey<String>(
          'ingredient-picker-search-result-chicken_breast',
        ),
      ),
    );
    expect(tile.enabled, isFalse);
  });
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
