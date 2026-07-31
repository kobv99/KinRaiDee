import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/presentation/pages/recipe_hub_page.dart';

import '../../../support/shopping_ui_test_support.dart';

void main() {
  testWidgets(
    'users can browse and cook recipes outside Pantry recommendations',
    (tester) async {
      final harness = await ShoppingUiHarness.create(recipes: _recipes);
      addTearDown(harness.dispose);
      useShoppingSurface(tester);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: const RecipeHubPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('browse-all-recipes-button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('browse-all-recipes-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('สูตรทั้งหมด'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('all-recipes-freedom-notice')),
        findsOneWidget,
      );
      expect(find.text('Omelette'), findsOneWidget);
      expect(find.text('Fried Rice'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('all-recipe-fried-rice')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fried Rice'), findsOneWidget);
      expect(find.textContaining('ความพร้อมจาก Pantry'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('start-cooking-cta')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('start-cooking-cta')));
      await tester.pumpAndSettle();

      // Sprint 5.5: starting to cook now opens the step-by-step wizard
      // (serving -> review -> confirm -> cooking mode) instead of jumping
      // straight into cooking mode from Recipe Detail.
      expect(find.text('เลือกจำนวนคน'), findsOneWidget);
    },
  );
}

const List<Recipe> _recipes = <Recipe>[
  Recipe(
    id: 'omelette',
    name: 'Omelette',
    category: 'Breakfast',
    servings: 2,
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
  ),
  Recipe(
    id: 'fried-rice',
    name: 'Fried Rice',
    category: 'Main',
    servings: 2,
    heroIngredientId: 'rice',
    ingredients: <RecipeIngredient>[
      RecipeIngredient(
        id: 'rice',
        name: 'Rice',
        quantity: 1,
        unit: 'kilogram',
        role: RecipeIngredientRole.primary,
        weight: 75,
      ),
      RecipeIngredient(
        id: 'egg',
        name: 'Egg',
        quantity: 2,
        unit: 'piece',
        role: RecipeIngredientRole.secondary,
        weight: 25,
      ),
    ],
    steps: <String>['Cook rice'],
  ),
];
