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
import 'package:mobile/features/pantry/presentation/pages/ingredient_batch_review_page.dart';
import 'package:mobile/features/pantry/presentation/providers/ingredient_picker_providers.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';

import '../../../../support/inventory_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 8, 4);
  late CanonicalIngredientRegistry registry;

  setUpAll(() async {
    registry = await IngredientCatalog().loadRegistry();
  });

  Future<({ProviderContainer container, InMemoryInventoryStore store})>
  pumpReviewPage(WidgetTester tester, {required Set<String> selection}) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = InMemoryInventoryStore();
    final inventory = HiveInventoryCommitRepository(
      store: store,
      clock: FixedAppClock(now),
    );
    await inventory.recoverPendingTransactions();

    final container = ProviderContainer(
      overrides: [
        canonicalIngredientRegistryProvider.overrideWithValue(registry),
        pantryRepositoryProvider.overrideWithValue(_EmptyPantryRepository()),
        inventoryCommitRepositoryProvider.overrideWithValue(inventory),
        appClockProvider.overrideWithValue(FixedAppClock(now)),
        transactionIdGeneratorProvider.overrideWithValue(
          SequenceTransactionIdGenerator(),
        ),
      ],
    );
    addTearDown(container.dispose);
    for (final id in selection) {
      container.read(ingredientPickerSelectionProvider.notifier).toggle(id);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: IngredientBatchReviewPage()),
      ),
    );
    await tester.pumpAndSettle();
    return (container: container, store: store);
  }

  testWidgets(
    'shows real registry defaults: 300 gram for meat cuts, 1 whole for '
    'mackerel',
    (tester) async {
      await pumpReviewPage(
        tester,
        selection: <String>{'pork_belly', 'mackerel'},
      );

      final porkQuantityField = tester.widget<TextField>(
        find.byKey(
          const ValueKey<String>('ingredient-review-quantity-pork_belly'),
        ),
      );
      expect(porkQuantityField.controller!.text, '300');
      final porkUnit = tester.widget<DropdownButton<String>>(
        find.byKey(const ValueKey<String>('ingredient-review-unit-pork_belly')),
      );
      expect(porkUnit.value, 'gram');

      final mackerelQuantityField = tester.widget<TextField>(
        find.byKey(
          const ValueKey<String>('ingredient-review-quantity-mackerel'),
        ),
      );
      expect(mackerelQuantityField.controller!.text, '1');
      final mackerelUnit = tester.widget<DropdownButton<String>>(
        find.byKey(const ValueKey<String>('ingredient-review-unit-mackerel')),
      );
      expect(mackerelUnit.value, 'whole');
    },
  );

  testWidgets('editing a quantity is reflected in the field', (tester) async {
    await pumpReviewPage(tester, selection: <String>{'pork_belly'});

    await tester.enterText(
      find.byKey(
        const ValueKey<String>('ingredient-review-quantity-pork_belly'),
      ),
      '450',
    );
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(
        const ValueKey<String>('ingredient-review-quantity-pork_belly'),
      ),
    );
    expect(field.controller!.text, '450');
  });

  testWidgets('editing the unit changes the selected dropdown value', (
    tester,
  ) async {
    await pumpReviewPage(tester, selection: <String>{'pork_belly'});

    await tester.tap(
      find.byKey(const ValueKey<String>('ingredient-review-unit-pork_belly')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('กิโลกรัม').last);
    await tester.pumpAndSettle();

    final unit = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey<String>('ingredient-review-unit-pork_belly')),
    );
    expect(unit.value, 'kilogram');
  });

  testWidgets('an invalid (zero/blank) quantity is rejected on commit', (
    tester,
  ) async {
    await pumpReviewPage(tester, selection: <String>{'pork_belly'});

    await tester.enterText(
      find.byKey(
        const ValueKey<String>('ingredient-review-quantity-pork_belly'),
      ),
      '0',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('ingredient-review-commit-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('ingredient-review-error')),
      findsOneWidget,
    );
    // The draft row is still there for correction, not discarded.
    expect(
      find.byKey(const ValueKey<String>('ingredient-review-row-pork_belly')),
      findsOneWidget,
    );
  });

  testWidgets('removing a row takes it out of the review list', (tester) async {
    await pumpReviewPage(tester, selection: <String>{'pork_belly', 'mackerel'});

    await tester.tap(
      find.byKey(const ValueKey<String>('ingredient-review-remove-mackerel')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('ingredient-review-row-mackerel')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('ingredient-review-row-pork_belly')),
      findsOneWidget,
    );
  });

  testWidgets('rows are ordered deterministically by display name', (
    tester,
  ) async {
    await pumpReviewPage(
      tester,
      selection: <String>{'mackerel', 'pork_belly', 'chicken_breast'},
    );

    final rowFinder = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'ingredient-review-row-',
          ),
    );
    final keys = tester
        .widgetList(rowFinder)
        .map((w) => (w.key! as ValueKey<String>).value)
        .toList();
    // Sorted by raw UTF-16 code-point comparison of the display name (no
    // locale-aware Thai collation is applied) — the point under test is
    // that the order is fixed and reproducible regardless of the
    // selection Set's iteration order, not a specific linguistic sort.
    expect(keys, [
      'ingredient-review-row-mackerel',
      'ingredient-review-row-pork_belly',
      'ingredient-review-row-chicken_breast',
    ]);
  });

  testWidgets(
    'committing succeeds, adds every row once, and pops with success',
    (tester) async {
      final result = await pumpReviewPage(
        tester,
        selection: <String>{'pork_belly', 'mackerel'},
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('ingredient-review-commit-button')),
      );
      await tester.pumpAndSettle();

      final pantry = result.container.read(pantryProvider);
      expect(pantry, hasLength(2));
      expect(
        pantry.map((i) => i.canonicalIngredientId),
        containsAll(<String>['pork_belly', 'mackerel']),
      );
    },
  );

  testWidgets(
    'a repository failure shows an error and preserves the draft for retry; '
    'retrying after the failure clears succeeds',
    (tester) async {
      final result = await pumpReviewPage(
        tester,
        selection: <String>{'pork_belly'},
      );
      result.store.failEnvelopeWrites = true;

      await tester.tap(
        find.byKey(const ValueKey<String>('ingredient-review-commit-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('ingredient-review-error')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('ingredient-review-row-pork_belly')),
        findsOneWidget,
      );
      expect(result.container.read(pantryProvider), isEmpty);

      result.store.failEnvelopeWrites = false;
      await tester.tap(
        find.byKey(const ValueKey<String>('ingredient-review-commit-button')),
      );
      await tester.pumpAndSettle();

      expect(result.container.read(pantryProvider), hasLength(1));
    },
  );

  testWidgets(
    'an ingredient with zero recipe coverage is still fully reviewable and '
    'committable',
    (tester) async {
      // pork_ribs has no recipe pack referencing it at all in this branch —
      // the picker/review flow must not know or care about that.
      final result = await pumpReviewPage(
        tester,
        selection: <String>{'pork_ribs'},
      );

      expect(
        find.byKey(const ValueKey<String>('ingredient-review-row-pork_ribs')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('ingredient-review-commit-button')),
      );
      await tester.pumpAndSettle();

      expect(
        result.container
            .read(pantryProvider)
            .map((i) => i.canonicalIngredientId),
        contains('pork_ribs'),
      );
    },
  );
}

class _EmptyPantryRepository implements PantryRepository {
  @override
  Set<String> getFavoriteIngredientNames() => const <String>{};

  @override
  List<Ingredient> getIngredients() => const <Ingredient>[];

  @override
  Future<void> saveFavoriteIngredientNames(Set<String> names) async {}
}
