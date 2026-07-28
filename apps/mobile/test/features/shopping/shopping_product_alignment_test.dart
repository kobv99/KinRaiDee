import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/navigation/app_navigation_provider.dart';

import '../../support/shopping_ui_test_support.dart';

void main() {
  testWidgets('empty Shopping directs users to Pantry-based Recipes', (
    tester,
  ) async {
    final harness = await ShoppingUiHarness.create();
    addTearDown(harness.dispose);
    await harness.pump(tester);

    expect(find.text('ไปเลือกสูตรจาก Pantry'), findsOneWidget);
    expect(find.text('สร้างรายการจากเมนู'), findsNothing);

    await tester.tap(find.text('ไปเลือกสูตรจาก Pantry'));
    await tester.pump();

    expect(
      harness.container.read(appNavigationProvider),
      AppNavigationNotifier.recipeTab,
    );
  });

  testWidgets('Shopping header no longer opens a standalone generator', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 7, 28, 8);
    final harness = await ShoppingUiHarness.create(
      at: now,
      list: testShoppingList(now: now),
    );
    addTearDown(harness.dispose);
    await harness.pump(tester);

    expect(find.text('เลือกสูตร'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);

    await tester.tap(find.text('เลือกสูตร'));
    await tester.pump();

    expect(
      harness.container.read(appNavigationProvider),
      AppNavigationNotifier.recipeTab,
    );
  });
}
