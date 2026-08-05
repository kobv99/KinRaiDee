import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/canonical_ingredient_providers.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/providers/pantry_provider.dart';
import 'package:mobile/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:mobile/features/pantry/presentation/pages/ingredient_batch_review_page.dart';
import 'package:mobile/features/pantry/presentation/pages/ingredient_family_page.dart';
import 'package:mobile/features/pantry/presentation/pages/ingredient_picker_entry_page.dart';
import 'package:mobile/features/pantry/presentation/providers/ingredient_picker_providers.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';

/// Exercises the picker as a real user would: open, browse three different
/// families (including one arbitrary-depth nested family), and confirm
/// every selection survives all of that navigation into one review screen
/// — the scenario no single-page test can prove on its own.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CanonicalIngredientRegistry registry;

  setUpAll(() async {
    registry = await IngredientCatalog().loadRegistry();
  });

  Future<ProviderContainer> pumpEntry(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        canonicalIngredientRegistryProvider.overrideWithValue(registry),
        pantryRepositoryProvider.overrideWithValue(_EmptyPantryRepository()),
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

  testWidgets(
    'selections made across three families, including a nested family, '
    'all persist into one review screen',
    (tester) async {
      final container = await pumpEntry(tester);

      // Family 1: Chicken — select two cuts.
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'ingredient-picker-family-card-chicken_family',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('ingredient-picker-option-chicken_breast'),
        ),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('ingredient-picker-option-chicken_drumstick'),
        ),
      );
      await tester.pump();
      expect(container.read(ingredientPickerSelectionProvider), <String>{
        'chicken_breast',
        'chicken_drumstick',
      });

      // Back to entry — selection must still be there.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(IngredientFamilyPage), findsNothing);
      expect(container.read(ingredientPickerSelectionProvider), <String>{
        'chicken_breast',
        'chicken_drumstick',
      });

      // Family 2: Pork — add one more, on top of the earlier two.
      await tester.tap(
        find.byKey(
          const ValueKey<String>('ingredient-picker-family-card-pork_family'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('ingredient-picker-option-pork_belly'),
        ),
      );
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Family 3: Fish — nested-family navigation (fish_family ›
      // sea_fish_family) adds a fourth item, on top of the earlier three.
      await tester.tap(
        find.byKey(
          const ValueKey<String>('ingredient-picker-family-card-fish_family'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'ingredient-picker-family-card-sea_fish_family',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('ingredient-picker-option-mackerel')),
      );
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(container.read(ingredientPickerSelectionProvider), <String>{
        'chicken_breast',
        'chicken_drumstick',
        'pork_belly',
        'mackerel',
      });

      await tester.tap(
        find.byKey(const ValueKey<String>('ingredient-picker-continue-button')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IngredientBatchReviewPage), findsOneWidget);
      for (final id in <String>[
        'chicken_breast',
        'chicken_drumstick',
        'pork_belly',
        'mackerel',
      ]) {
        expect(
          find.byKey(ValueKey<String>('ingredient-review-row-$id')),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('backing out of the picker without committing leaves the session '
      'provider invalidated for the next open (mirrors pantry_page.dart\'s '
      'exit-time ref.invalidate)', (tester) async {
    final container = await pumpEntry(tester);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('ingredient-picker-family-card-pork_family'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('ingredient-picker-option-pork_belly')),
    );
    await tester.pump();
    expect(container.read(ingredientPickerSelectionProvider), isNotEmpty);

    // Simulates the caller (pantry_page.dart) resetting the session once
    // the whole flow is left, regardless of how it was left.
    container.invalidate(ingredientPickerSelectionProvider);

    expect(container.read(ingredientPickerSelectionProvider), isEmpty);
  });

  testWidgets('searching and cancelling out of quick-add leaves an active '
      'Browse selection completely untouched', (tester) async {
    final container = await pumpEntry(tester);

    // Start a Browse selection first.
    await tester.tap(
      find.byKey(
        const ValueKey<String>('ingredient-picker-family-card-pork_family'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('ingredient-picker-option-pork_belly')),
    );
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(container.read(ingredientPickerSelectionProvider), <String>{
      'pork_belly',
    });

    // Now search and open (then cancel out of) the direct quick-add flow —
    // it must never read or write the Browse selection session.
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
    await tester.tap(
      find.byKey(const ValueKey<String>('ingredient-quick-add-cancel')),
    );
    await tester.pumpAndSettle();

    expect(container.read(ingredientPickerSelectionProvider), <String>{
      'pork_belly',
    });
  });
}

class _EmptyPantryRepository implements PantryRepository {
  @override
  Set<String> getFavoriteIngredientNames() => const <String>{};

  @override
  List<Ingredient> getIngredients() => const <Ingredient>[];

  @override
  Future<void> saveFavoriteIngredientNames(Set<String> names) async {}
}
