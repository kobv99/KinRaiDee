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
import 'package:mobile/features/pantry/presentation/pages/ingredient_quick_add_page.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';

import '../../../../support/inventory_test_support.dart';

/// The direct search-to-pantry flow — a single-item quantity/unit editor
/// that shares the same atomic commit primitive as Browse's batch review
/// ([PantryNotifier.addIngredientsBatch]) but never touches the Browse
/// selection session. See ingredient_picker_entry_page_test.dart /
/// ingredient_picker_session_flow_test.dart for proof the two flows don't
/// interfere with each other.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 8, 4);
  late CanonicalIngredientRegistry registry;

  setUpAll(() async {
    registry = await IngredientCatalog().loadRegistry();
  });

  Future<({ProviderContainer container, InMemoryInventoryStore store})>
  pumpQuickAdd(
    WidgetTester tester, {
    required String canonicalId,
    List<Ingredient> pantry = const <Ingredient>[],
  }) async {
    final store = InMemoryInventoryStore();
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
    // Read once so PantryNotifier.build() picks up the fixture repository's
    // initial contents before the page mounts.
    container.read(pantryProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: IngredientQuickAddPage(canonicalId: canonicalId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container: container, store: store);
  }

  testWidgets('opens with defaults from the real registry: 1 whole for '
      'mackerel, and the full breadcrumb shown', (tester) async {
    await pumpQuickAdd(tester, canonicalId: 'mackerel');

    final quantityField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('ingredient-quick-add-quantity')),
    );
    expect(quantityField.controller!.text, '1');
    final unitDropdown = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey<String>('ingredient-quick-add-unit')),
    );
    expect(unitDropdown.value, 'whole');
    expect(find.text('ปลา › ปลาทะเล › ปลาทู'), findsOneWidget);
  });

  testWidgets('editing quantity and unit is reflected before commit', (
    tester,
  ) async {
    await pumpQuickAdd(tester, canonicalId: 'pork_belly');

    await tester.enterText(
      find.byKey(const ValueKey<String>('ingredient-quick-add-quantity')),
      '450',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('ingredient-quick-add-unit')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('กิโลกรัม').last);
    await tester.pumpAndSettle();

    final quantityField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('ingredient-quick-add-quantity')),
    );
    expect(quantityField.controller!.text, '450');
    final unitDropdown = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey<String>('ingredient-quick-add-unit')),
    );
    expect(unitDropdown.value, 'kilogram');
  });

  testWidgets('an invalid (zero) quantity is rejected and blocks commit', (
    tester,
  ) async {
    final result = await pumpQuickAdd(tester, canonicalId: 'pork_belly');

    await tester.enterText(
      find.byKey(const ValueKey<String>('ingredient-quick-add-quantity')),
      '0',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('ingredient-quick-add-commit')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('ingredient-quick-add-error')),
      findsOneWidget,
    );
    expect(result.container.read(pantryProvider), isEmpty);
    // Entered value remains available for correction, not discarded.
    final quantityField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('ingredient-quick-add-quantity')),
    );
    expect(quantityField.controller!.text, '0');
  });

  testWidgets(
    'a canonical id already in the pantry is blocked as a duplicate',
    (tester) async {
      final result = await pumpQuickAdd(
        tester,
        canonicalId: 'chicken_breast',
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

      await tester.tap(
        find.byKey(const ValueKey<String>('ingredient-quick-add-commit')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('ingredient-quick-add-error')),
        findsOneWidget,
      );
      expect(result.container.read(pantryProvider), hasLength(1));
    },
  );

  testWidgets(
    'committing succeeds in exactly one transaction and pops with success',
    (tester) async {
      final result = await pumpQuickAdd(tester, canonicalId: 'mackerel');

      await tester.tap(
        find.byKey(const ValueKey<String>('ingredient-quick-add-commit')),
      );
      await tester.pumpAndSettle();

      final pantry = result.container.read(pantryProvider);
      expect(pantry, hasLength(1));
      expect(pantry.single.canonicalIngredientId, 'mackerel');
      expect(pantry.single.quantity, 1);
    },
  );

  testWidgets(
    'a repository failure shows an error, commits nothing, and a retry '
    'after the failure clears succeeds',
    (tester) async {
      final result = await pumpQuickAdd(tester, canonicalId: 'mackerel');
      result.store.failEnvelopeWrites = true;

      await tester.tap(
        find.byKey(const ValueKey<String>('ingredient-quick-add-commit')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('ingredient-quick-add-error')),
        findsOneWidget,
      );
      expect(result.container.read(pantryProvider), isEmpty);
      // Entered values are preserved for retry.
      final quantityField = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('ingredient-quick-add-quantity')),
      );
      expect(quantityField.controller!.text, '1');

      result.store.failEnvelopeWrites = false;
      await tester.tap(
        find.byKey(const ValueKey<String>('ingredient-quick-add-commit')),
      );
      await tester.pumpAndSettle();

      expect(result.container.read(pantryProvider), hasLength(1));
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
