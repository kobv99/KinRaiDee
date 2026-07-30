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

      expect(find.text('ค้นหาสูตรอาหาร'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('recipe-catalog-search-field')),
        findsOneWidget,
      );
      expect(find.text('Omelette'), findsNothing);
      expect(find.text('Fried Rice'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey<String>('recipe-catalog-search-field')),
        'Fried Rice',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('recipe-catalog-search')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Omelette'), findsNothing);
      expect(find.text('Fried Rice'), findsNWidgets(2));
      await tester.tap(
        find.byKey(const ValueKey<String>('recipe-search-result-fried-rice')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fried Rice'), findsOneWidget);
      expect(find.text('ความพร้อม 0%'), findsOneWidget);
      expect(find.text('เริ่มทำอาหารสำหรับ 2 คน'), findsOneWidget);

      await tester.tap(find.text('เริ่มทำอาหารสำหรับ 2 คน'));
      await tester.pumpAndSettle();

      expect(find.text('โหมดทำอาหาร'), findsOneWidget);
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
