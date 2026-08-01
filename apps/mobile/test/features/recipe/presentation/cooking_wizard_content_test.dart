import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/providers/pantry_provider.dart';
import 'package:mobile/core/time/app_clock.dart';
import 'package:mobile/features/pantry/application/inventory_transaction_providers.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/presentation/pages/cooking_wizard_page.dart';
import 'package:mobile/features/recipe/presentation/pages/recipe_detail_page.dart';

import '../../../support/inventory_test_support.dart';

/// Round 3 UAT reported the wizard's Serving Selection, Ingredient Review,
/// and Ready Confirmation screens as rendering "almost completely blank"
/// with only the AppBar title, exit action, and bottom CTA visible.
/// These tests exercise the same code path (real Navigator push from
/// Recipe Detail, and direct construction) with both a fully-available
/// and a partially-missing pantry, and assert every documented piece of
/// required content is actually present in the widget tree — not just
/// that navigation between phases succeeds.
void main() {
  testWidgets('Serving Selection shows recipe summary, name, time, '
      'difficulty, serving selector, and Continue', (tester) async {
    final harness = await _Harness.create(pantry: _fullPantry());
    addTearDown(harness.dispose);

    await _pumpWizard(tester, harness.container, _recipe());

    expect(tester.takeException(), isNull);
    expect(find.text('Test Recipe'), findsOneWidget);
    expect(find.textContaining('20 นาที'), findsOneWidget);
    expect(find.textContaining('ปานกลาง'), findsOneWidget);
    expect(find.text('สำหรับกี่คน?'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // default serving count
    expect(find.text('ต่อไป'), findsOneWidget);
  });

  testWidgets('Ingredient Review shows readiness, available, missing, and '
      'optional ingredients with a Continue action', (tester) async {
    final harness = await _Harness.create(pantry: _partialPantry());
    addTearDown(harness.dispose);

    await _pumpWizard(tester, harness.container, _recipe());
    await tester.tap(find.text('ต่อไป'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ตรวจสอบวัตถุดิบ'), findsOneWidget);
    expect(find.textContaining('ความพร้อมจาก Pantry'), findsOneWidget);
    expect(find.text('Egg'), findsOneWidget); // available
    expect(find.text('Pork'), findsOneWidget); // missing
    expect(find.text('Garlic'), findsOneWidget); // missing (optional-ish)
    expect(find.textContaining('ขาด 2 รายการ'), findsOneWidget);
    expect(find.text('เพิ่มวัตถุดิบ'), findsOneWidget);
    expect(find.text('ต่อไป'), findsOneWidget);
  });

  testWidgets('Ready Confirmation shows recipe name, servings, estimated '
      'time, readiness summary, and Start Cooking', (tester) async {
    final harness = await _Harness.create(pantry: _fullPantry());
    addTearDown(harness.dispose);

    await _pumpWizard(tester, harness.container, _recipe());
    await tester.tap(find.text('ต่อไป'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ต่อไป'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('พร้อมทำอาหาร'), findsOneWidget);
    expect(find.text('คุณพร้อมทำ'), findsOneWidget);
    expect(find.text('Test Recipe'), findsOneWidget);
    expect(find.textContaining('สำหรับ 2 คน'), findsOneWidget);
    expect(find.textContaining('20 นาที'), findsOneWidget);
    expect(find.text('เริ่มทำอาหาร'), findsOneWidget);
  });

  testWidgets('recipe and serving data survive the full push from Recipe '
      'Detail through every wizard step', (tester) async {
    final harness = await _Harness.create(pantry: _partialPantry());
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: MaterialApp(home: RecipeDetailPage(recipe: _recipe())),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey<String>('start-cooking-cta')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Test Recipe'), findsOneWidget, reason: 'serving step');

    await tester.tap(find.text('ต่อไป'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Pork'), findsOneWidget, reason: 'review step');

    await tester.tap(find.text('ต่อไป'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Test Recipe'), findsOneWidget, reason: 'confirm step');
  });

  testWidgets(
    'pushing the wizard from Recipe Detail never throws mid-transition and '
    'never leaves the body blank once settled (Sprint 5.6 blank-body '
    'regression) — Recipe Detail stays mounted underneath the wizard for '
    'this whole push, both watching the same per-recipe Shopping data, '
    'which is the one structural difference from pushing the wizard off a '
    'bare caller screen',
    (tester) async {
      final harness = await _Harness.create(pantry: _partialPantry());
      addTearDown(harness.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: MaterialApp(home: RecipeDetailPage(recipe: _recipe())),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey<String>('start-cooking-cta')));

      // Step through the MaterialPageRoute push transition frame by frame
      // (its default duration is 300ms) instead of jumping straight to the
      // settled end state with pumpAndSettle — a setState()/markNeedsBuild()
      // -during-build failure, if there is one, would happen on one of
      // these intermediate frames while the Overlay is still building, not
      // necessarily on the first or the final one.
      for (var elapsed = 0; elapsed <= 320; elapsed += 16) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          tester.takeException(),
          isNull,
          reason: 'no exception at ${elapsed}ms into the push transition',
        );
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The reported symptom was an AppBar/CTA-visible-but-otherwise-blank
      // body: assert the actual step content rendered, not just that no
      // exception was thrown.
      expect(find.text('เลือกจำนวนคน'), findsOneWidget, reason: 'AppBar title');
      expect(find.text('Test Recipe'), findsOneWidget, reason: 'body content');
      expect(
        find.text('สำหรับกี่คน?'),
        findsOneWidget,
        reason: 'serving selector heading',
      );
      expect(find.text('ต่อไป'), findsOneWidget, reason: 'bottom CTA');

      // Advancing a step keeps Recipe Detail's own subscription to the same
      // Shopping data alive underneath, unpaused, the whole time.
      await tester.tap(find.text('ต่อไป'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('ตรวจสอบวัตถุดิบ'), findsOneWidget);
      expect(find.text('Pork'), findsOneWidget, reason: 'review step content');
    },
  );
}

Future<void> _pumpWizard(
  WidgetTester tester,
  ProviderContainer container,
  Recipe recipe,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: CookingWizardPage(recipe: recipe)),
    ),
  );
  await tester.pumpAndSettle();
}

Recipe _recipe() {
  return const Recipe(
    id: 'test-recipe',
    name: 'Test Recipe',
    category: 'Dinner',
    emoji: 'C',
    difficulty: 'medium',
    cookTimeMinutes: 20,
    servings: 2,
    ingredients: <RecipeIngredient>[
      RecipeIngredient(id: 'egg', name: 'Egg', quantity: 2, unit: 'piece'),
      RecipeIngredient(
        id: 'pork',
        name: 'Pork',
        quantity: 300,
        unit: 'gram',
        role: RecipeIngredientRole.primary,
      ),
      RecipeIngredient(
        id: 'garlic',
        name: 'Garlic',
        quantity: 3,
        unit: 'clove',
        role: RecipeIngredientRole.secondary,
      ),
    ],
    steps: <String>['Step one', 'Step two', 'Step three'],
  );
}

List<Ingredient> _fullPantry() {
  final now = DateTime.utc(2026, 7, 26, 9);
  return <Ingredient>[
    _ingredient(
      id: 'egg-lot',
      name: 'Egg',
      quantity: 10,
      unit: 'piece',
      now: now,
    ),
    _ingredient(
      id: 'pork-lot',
      name: 'Pork',
      quantity: 500,
      unit: 'gram',
      now: now,
    ),
    _ingredient(
      id: 'garlic-lot',
      name: 'Garlic',
      quantity: 10,
      unit: 'clove',
      now: now,
    ),
  ];
}

List<Ingredient> _partialPantry() {
  final now = DateTime.utc(2026, 7, 26, 9);
  return <Ingredient>[
    _ingredient(
      id: 'egg-lot',
      name: 'Egg',
      quantity: 10,
      unit: 'piece',
      now: now,
    ),
  ];
}

Ingredient _ingredient({
  required String id,
  required String name,
  required double quantity,
  required String unit,
  required DateTime now,
}) {
  return Ingredient(
    id: id,
    name: name,
    category: 'Test',
    emoji: 'T',
    quantity: quantity,
    unit: unit,
    createdAt: now.subtract(const Duration(days: 10)),
    updatedAt: now,
  );
}

class _Harness {
  _Harness(this.container);

  final ProviderContainer container;

  static Future<_Harness> create({required List<Ingredient> pantry}) async {
    final now = DateTime.utc(2026, 7, 26, 9);
    final store = InMemoryInventoryStore(legacyPantry: pantry);
    final clock = FixedAppClock(now);
    final repository = HiveInventoryCommitRepository(
      store: store,
      clock: clock,
    );
    await repository.recoverPendingTransactions();
    final container = ProviderContainer(
      overrides: [
        pantryRepositoryProvider.overrideWithValue(
          _MemoryPantryRepository(pantry),
        ),
        inventoryCommitRepositoryProvider.overrideWithValue(repository),
        appClockProvider.overrideWithValue(clock),
      ],
    );
    return _Harness(container);
  }

  void dispose() => container.dispose();
}

class _MemoryPantryRepository implements PantryRepository {
  _MemoryPantryRepository(List<Ingredient> ingredients)
    : _ingredients = List<Ingredient>.of(ingredients);

  final List<Ingredient> _ingredients;

  @override
  List<Ingredient> getIngredients() => List<Ingredient>.of(_ingredients);

  @override
  Set<String> getFavoriteIngredientNames() => <String>{};

  @override
  Future<void> saveFavoriteIngredientNames(Set<String> names) async {}
}
