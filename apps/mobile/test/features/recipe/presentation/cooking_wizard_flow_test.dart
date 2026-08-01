import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/navigation/app_navigation_provider.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/presentation/pages/cooking_wizard_page.dart';

import '../../../support/shopping_ui_test_support.dart';

/// Sprint 5.6 Round 4 rebuild — covers the flow-level behaviors the content
/// tests in cooking_wizard_content_test.dart don't: navigating forward and
/// back between steps, exiting, Cooking Mode's real per-recipe step count,
/// Add to Shopping / Go to Shopping from inside the wizard, and the
/// explicit error state that replaces a blank body + enabled CTA.
void main() {
  testWidgets('Previous and Next move between wizard steps correctly', (
    tester,
  ) async {
    final harness = await ShoppingUiHarness.create(
      at: DateTime.utc(2026, 7, 31, 9),
    );
    addTearDown(harness.dispose);
    await _pumpWizard(tester, harness, _recipe());

    expect(find.text('เลือกจำนวนคน'), findsOneWidget);

    await tester.tap(find.text('ต่อไป'));
    await tester.pumpAndSettle();
    expect(find.text('ตรวจสอบวัตถุดิบ'), findsOneWidget);

    await tester.tap(find.text('ต่อไป'));
    await tester.pumpAndSettle();
    expect(find.text('พร้อมทำอาหาร'), findsOneWidget);

    // AppBar back arrow steps back one phase at a time, not straight to exit.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('ตรวจสอบวัตถุดิบ'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('เลือกจำนวนคน'), findsOneWidget);
  });

  testWidgets('Exit action closes the wizard and returns to the caller', (
    tester,
  ) async {
    final harness = await ShoppingUiHarness.create(
      at: DateTime.utc(2026, 7, 31, 9),
    );
    addTearDown(harness.dispose);
    await _pumpWizard(tester, harness, _recipe());

    await tester.tap(find.byKey(const ValueKey<String>('wizard-exit-action')));
    await tester.pumpAndSettle();

    expect(find.text('เลือกจำนวนคน'), findsNothing);
    expect(find.text('caller screen'), findsOneWidget);
  });

  testWidgets(
    'Cooking Mode shows the real step count and different recipes can have '
    'different step counts',
    (tester) async {
      final harness = await ShoppingUiHarness.create(
        at: DateTime.utc(2026, 7, 31, 9),
      );
      addTearDown(harness.dispose);
      await _pumpWizard(
        tester,
        harness,
        _recipe(
          steps: const ['หั่นผัก', 'ผัดหมู', 'ปรุงรส', 'พักไว้', 'จัดจาน'],
        ),
      );

      await tester.tap(find.text('ต่อไป'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ต่อไป'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เริ่มทำอาหาร'));
      await tester.pumpAndSettle();

      expect(find.text('ขั้นตอนที่ 1 / 5'), findsOneWidget);
      expect(find.text('หั่นผัก'), findsOneWidget);

      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();
      expect(find.text('ขั้นตอนที่ 2 / 5'), findsOneWidget);
      expect(find.text('ผัดหมู'), findsOneWidget);

      // A different recipe with a different number of steps must show its
      // own count, never a hardcoded assumption of 3. Re-pumping a fresh
      // widget tree resets state regardless of the first wizard's phase.
      await _pumpWizard(
        tester,
        harness,
        _recipe(steps: const ['ขั้นตอนเดียว']),
      );

      await tester.tap(find.text('ต่อไป'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ต่อไป'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เริ่มทำอาหาร'));
      await tester.pumpAndSettle();
      expect(find.text('ขั้นตอนที่ 1 / 1'), findsOneWidget);
      expect(find.text('เสร็จแล้ว'), findsOneWidget);
    },
  );

  testWidgets(
    'Adding missing ingredients to Shopping does not destroy wizard state, '
    'and Go to Shopping switches the main tab',
    (tester) async {
      final harness = await ShoppingUiHarness.create(
        at: DateTime.utc(2026, 7, 31, 9),
        pantry: [
          testPantryLot(
            id: 'egg-lot',
            canonicalId: 'egg',
            name: 'Egg',
            quantity: 10,
            unit: 'piece',
            now: DateTime.utc(2026, 7, 31, 9),
          ),
        ],
      );
      addTearDown(harness.dispose);
      useShoppingSurface(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: MaterialApp(home: CookingWizardPage(recipe: _recipe())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ต่อไป'));
      await tester.pumpAndSettle();

      expect(find.text('Test Recipe'), findsNothing);
      expect(find.textContaining('ขาด'), findsWidgets);
      expect(
        harness.container.read(appNavigationProvider),
        AppNavigationNotifier.homeTab,
      );

      final addMissingButton = find.byKey(
        const ValueKey<String>('add-missing-to-shopping'),
      );
      expect(addMissingButton, findsOneWidget);
      expect(
        addMissingButton.hitTestable(),
        findsOneWidget,
        reason: 'the Shopping action must receive real pointer input',
      );
      await tester.tap(addMissingButton);
      await tester.pumpAndSettle();

      expect(
        find.text('เพิ่มวัตถุดิบที่ขาดเข้า Shopping แล้ว'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'added-to-shopping-confirmation-go-to-shopping',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "ไปที่ Shopping" must actually switch the main tab...
      expect(
        harness.container.read(appNavigationProvider),
        AppNavigationNotifier.shoppingTab,
      );
      // ...while the wizard itself (still the top route in this test, since
      // there's no MainShell here to unwind it) keeps its state intact:
      // still on the review step, recipe data still present.
      expect(find.text('ตรวจสอบวัตถุดิบ'), findsOneWidget);
      expect(find.textContaining('เพิ่มเข้า Shopping แล้ว'), findsWidgets);
    },
  );

  testWidgets('a failed serving-plan computation shows a safe error state with '
      'working Retry and Exit, never a blank body with an enabled CTA', (
    tester,
  ) async {
    var attempts = 0;
    var onRetryCalls = 0;
    var onExitCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: WizardErrorScaffold(
          phaseLabel: 'เลือกจำนวนคน',
          onRetry: () {
            attempts++;
            onRetryCalls++;
          },
          onExit: () => onExitCalls++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // AppBar chrome (title + exit) still renders, matching the reported
    // shape, but the body explains what happened instead of being blank.
    expect(find.text('เลือกจำนวนคน'), findsOneWidget);
    expect(find.textContaining('โหลดข้อมูลสูตรนี้ไม่สำเร็จ'), findsOneWidget);

    // No Continue/Start Cooking CTA exists anywhere on this screen — the
    // error state replaces the whole body, it doesn't sit behind a still
    // -enabled bottom action.
    expect(find.text('ต่อไป'), findsNothing);
    expect(find.text('เริ่มทำอาหาร'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('wizard-error-retry')));
    expect(attempts, 1);
    expect(onRetryCalls, 1);

    await tester.tap(find.byKey(const ValueKey<String>('wizard-error-exit')));
    expect(onExitCalls, 1);
  });
}

Future<void> _pumpWizard(
  WidgetTester tester,
  ShoppingUiHarness harness,
  Recipe recipe,
) async {
  useShoppingSurface(tester);
  // A fresh key on each call forces Flutter to tear down any previous
  // MaterialApp/Navigator entirely instead of reconciling into it — without
  // this, a wizard route pushed by an earlier _pumpWizard call in the same
  // test survives underneath the "new" tree, buried offstage.
  await tester.pumpWidget(
    UncontrolledProviderScope(
      key: UniqueKey(),
      container: harness.container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                child: const Text('caller screen'),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => CookingWizardPage(recipe: recipe),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('caller screen'));
  await tester.pumpAndSettle();
}

Recipe _recipe({
  List<String> steps = const ['Step one', 'Step two', 'Step three'],
}) {
  return Recipe(
    id: 'test-recipe',
    name: 'Test Recipe',
    category: 'Dinner',
    emoji: 'C',
    difficulty: 'medium',
    cookTimeMinutes: 20,
    servings: 2,
    ingredients: const <RecipeIngredient>[
      RecipeIngredient(id: 'egg', name: 'Egg', quantity: 2, unit: 'piece'),
      RecipeIngredient(
        id: 'pork',
        name: 'Pork',
        quantity: 300,
        unit: 'gram',
        role: RecipeIngredientRole.primary,
      ),
    ],
    steps: steps,
  );
}
