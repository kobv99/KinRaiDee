import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/providers/pantry_provider.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/presentation/pages/recipe_detail_page.dart';

import '../../../support/shopping_ui_test_support.dart';

// Regression coverage for the Cook -> Deduct -> Undo transaction flow through
// the actual Recipe Detail UI (recipe_detail_legacy.dart), which this sprint
// touched only for design-system styling and the new favorite toggle. This
// test exists to prove the transaction path itself is unaffected by that UI
// work: it drives the real cooking-mode -> confirm-deduction -> undo cycle
// and asserts against the pantry provider's committed state, not just text.
void main() {
  testWidgets(
    'cooking a recipe deducts pantry quantity exactly once, and undo '
    'restores it exactly once',
    (tester) async {
      final now = DateTime.utc(2026, 7, 30, 9);
      final harness = await ShoppingUiHarness.create(
        at: now,
        recipes: const <Recipe>[_recipe],
        pantry: [
          testPantryLot(
            id: 'egg-lot',
            canonicalId: 'egg',
            name: 'Egg',
            quantity: 6,
            unit: 'piece',
            now: now,
          ),
        ],
      );
      addTearDown(harness.dispose);
      useShoppingSurface(tester);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: const RecipeDetailPage(recipe: _recipe),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_eggQuantity(harness.container), 6);

      await tester.tap(find.text('เริ่มทำอาหารสำหรับ 1 คน'));
      await tester.pumpAndSettle();

      expect(find.text('โหมดทำอาหาร'), findsOneWidget);
      expect(find.text('ขั้นตอน 1'), findsOneWidget);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      expect(find.text('ทำเสร็จแล้ว · ตรวจและหัก Pantry'), findsOneWidget);

      await tester.tap(find.text('ทำเสร็จแล้ว · ตรวจและหัก Pantry'));
      await tester.pumpAndSettle();

      expect(find.text('ยืนยันและหักวัตถุดิบ'), findsOneWidget);

      await tester.tap(find.text('ยืนยันและหักวัตถุดิบ'));
      await tester.pumpAndSettle();

      expect(_eggQuantity(harness.container), 4);
      expect(find.textContaining('หักวัตถุดิบ'), findsOneWidget);
      expect(find.text('ย้อนกลับ'), findsOneWidget);

      await tester.tap(find.text('ย้อนกลับ'));
      await tester.pumpAndSettle();

      expect(_eggQuantity(harness.container), 6);
      expect(find.textContaining('คืนวัตถุดิบ'), findsOneWidget);
    },
  );
}

double _eggQuantity(ProviderContainer container) {
  return container
      .read(pantryProvider)
      .singleWhere((ingredient) => ingredient.id == 'egg-lot')
      .quantity;
}

const Recipe _recipe = Recipe(
  id: 'omelette',
  name: 'Omelette',
  category: 'test',
  servings: 1,
  heroIngredientId: 'egg',
  ingredients: <RecipeIngredient>[
    RecipeIngredient(
      id: 'egg',
      name: 'Egg',
      quantity: 2,
      unit: 'piece',
      role: RecipeIngredientRole.primary,
      weight: 100,
    ),
  ],
  steps: <String>['Cook egg'],
);
