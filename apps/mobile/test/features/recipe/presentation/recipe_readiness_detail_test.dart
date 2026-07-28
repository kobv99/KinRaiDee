import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/presentation/pages/recipe_detail_page.dart';

import '../../../support/shopping_ui_test_support.dart';

void main() {
  testWidgets('Recipe Detail shows readiness groups and adds missing items', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 7, 28, 8);
    final harness = await ShoppingUiHarness.create(
      at: now,
      pantry: [
        testPantryLot(
          id: 'egg-lot',
          canonicalId: 'egg',
          name: 'Egg',
          quantity: 6,
          unit: 'piece',
          now: now,
        ),
        testPantryLot(
          id: 'rice-lot',
          canonicalId: 'rice',
          name: 'Rice',
          quantity: 0.2,
          unit: 'kilogram',
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

    expect(
      find.byKey(const ValueKey<String>('recipe-readiness-panel')),
      findsOneWidget,
    );
    expect(find.text('ความพร้อม 40%'), findsOneWidget);
    expect(find.text('มีใน Pantry แล้ว'), findsOneWidget);
    expect(find.text('วัตถุดิบที่ขาด'), findsOneWidget);
    expect(find.text('Egg'), findsWidgets);
    expect(find.textContaining('Rice · ขาด 0.8 kilogram'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('add-missing-to-shopping')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('add-missing-to-shopping')),
    );
    await tester.pumpAndSettle();

    final items = (await harness.lists()).single.items;
    expect(items, hasLength(1));
    expect(items.single.canonicalIngredientId, 'rice');
    expect(items.single.quantity, closeTo(0.8, 0.000001));
    expect(find.textContaining('เพิ่มวัตถุดิบที่ขาด 1 รายการ'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('add-missing-to-shopping')),
    );
    await tester.pumpAndSettle();

    expect((await harness.lists()).single.items, hasLength(1));
    expect(find.text('วัตถุดิบที่ขาดอยู่ใน Shopping แล้ว'), findsOneWidget);
  });
}

const Recipe _recipe = Recipe(
  id: 'fried-rice',
  name: 'Fried Rice',
  category: 'test',
  servings: 2,
  heroIngredientId: 'rice',
  ingredients: <RecipeIngredient>[
    RecipeIngredient(
      id: 'egg',
      name: 'Egg',
      quantity: 6,
      unit: 'piece',
      role: RecipeIngredientRole.secondary,
      weight: 25,
    ),
    RecipeIngredient(
      id: 'rice',
      name: 'Rice',
      quantity: 1,
      unit: 'kilogram',
      role: RecipeIngredientRole.primary,
      weight: 75,
    ),
  ],
  steps: <String>['Cook'],
);
