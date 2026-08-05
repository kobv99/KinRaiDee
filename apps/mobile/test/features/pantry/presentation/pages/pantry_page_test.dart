import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/canonical_ingredient_providers.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/providers/pantry_provider.dart';
import 'package:mobile/core/time/app_clock.dart';
import 'package:mobile/features/pantry/application/inventory_transaction_providers.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:mobile/features/pantry/presentation/pages/ingredient_picker_entry_page.dart';
import 'package:mobile/features/pantry/presentation/pages/ingredient_quick_add_page.dart';
import 'package:mobile/features/pantry/presentation/pages/pantry_page.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';

import '../../../../support/inventory_test_support.dart';

/// Regression coverage for the live-UAT bug: the primary Pantry "add
/// ingredient" action (the FAB, and the empty-state CTA of the same name)
/// must open the canonical [IngredientPickerEntryPage] — never the legacy
/// `AddIngredientDialog` — so users no longer land back in the old
/// category-chip-plus-card dialog with its separate, weaker search.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 8, 5);
  late CanonicalIngredientRegistry registry;

  setUpAll(() async {
    registry = await IngredientCatalog().loadRegistry();
  });

  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<ProviderContainer> pumpPantry(
    WidgetTester tester, {
    List<Ingredient> pantry = const <Ingredient>[],
  }) async {
    useLargeSurface(tester);
    final store = InMemoryInventoryStore(legacyPantry: pantry);
    final inventory = HiveInventoryCommitRepository(
      store: store,
      clock: FixedAppClock(now),
    );
    await inventory.recoverPendingTransactions();

    final container = ProviderContainer(
      overrides: [
        canonicalIngredientRegistryProvider.overrideWithValue(registry),
        pantryRepositoryProvider.overrideWithValue(
          _FixturePantryRepository(pantry),
        ),
        inventoryCommitRepositoryProvider.overrideWithValue(inventory),
        appClockProvider.overrideWithValue(FixedAppClock(now)),
        transactionIdGeneratorProvider.overrideWithValue(
          SequenceTransactionIdGenerator(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(pantryProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PantryPage()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('primary FAB add action opens IngredientPickerEntryPage, not the '
      'legacy AddIngredientDialog', (tester) async {
    await pumpPantry(
      tester,
      pantry: <Ingredient>[_ingredient(id: 'egg-lot', now: now)],
    );

    expect(
      find.byKey(const ValueKey<String>('pantry-primary-add-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('pantry-primary-add-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IngredientPickerEntryPage), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('เพิ่มวัตถุดิบ 🥬'), findsNothing);
  });

  testWidgets(
    'empty-pantry "เพิ่มวัตถุดิบ" call-to-action also opens the canonical '
    'picker, matching the FAB entry point',
    (tester) async {
      await pumpPantry(tester);

      await tester.tap(find.text('เพิ่มวัตถุดิบ').first);
      await tester.pumpAndSettle();

      expect(find.byType(IngredientPickerEntryPage), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'the approved top-right category icon opens the same canonical picker '
    'as the primary add action',
    (tester) async {
      await pumpPantry(
        tester,
        pantry: <Ingredient>[_ingredient(id: 'egg-lot', now: now)],
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('pantry-open-ingredient-picker')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IngredientPickerEntryPage), findsOneWidget);
    },
  );

  testWidgets('live path: Pantry\'s own inline search reads the same canonical '
      'registry/search provider as IngredientPickerEntryPage — query "น่อง" '
      'surfaces both ไก่ › น่องไก่ and เนื้อวัว › เนื้อน่องลาย, and tapping a '
      'result opens IngredientQuickAddPage directly', (tester) async {
    await pumpPantry(
      tester,
      pantry: <Ingredient>[_ingredient(id: 'egg-lot', now: now)],
    );

    await tester.enterText(find.byType(TextField).first, 'น่อง');
    await tester.pumpAndSettle();

    expect(find.text('ไก่ › น่องไก่'), findsOneWidget);
    expect(find.text('เนื้อวัว › เนื้อน่องลาย'), findsOneWidget);
    // Never the legacy dialog/panel this bug report was about.
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('เนื้อวัว › เนื้อน่องลาย'));
    await tester.pumpAndSettle();

    expect(find.byType(IngredientQuickAddPage), findsOneWidget);
  });
}

Ingredient _ingredient({required String id, required DateTime now}) {
  return Ingredient(
    id: id,
    name: 'Egg',
    category: 'Test',
    emoji: 'E',
    quantity: 6,
    unit: 'piece',
    createdAt: now,
    updatedAt: now,
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
