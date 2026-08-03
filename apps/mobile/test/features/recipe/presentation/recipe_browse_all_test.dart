import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/presentation/pages/all_recipes_page.dart';
import 'package:mobile/features/recipe/presentation/pages/recipe_hub_page.dart';

import '../../../support/shopping_ui_test_support.dart';

void main() {
  testWidgets(
    'users can search and cook recipes outside Pantry recommendations',
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
      expect(find.text('ค้นหาสูตร'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('browse-all-recipes-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('ค้นหาและสำรวจสูตร'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('all-recipes-freedom-notice')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('recipe-discovery-idle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('recipe-filter-time')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('recipe-filter-difficulty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('recipe-filter-method')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('all-recipe-omelette')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('all-recipe-fried-rice')),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('recipe-discovery-search-field')),
        'Fried Rice',
      );
      await tester.pumpAndSettle();

      expect(find.text('Fried Rice'), findsWidgets);
      expect(find.text('Omelette'), findsNothing);
      expect(find.textContaining('ตรงชื่อเมนู'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('recipe-discovery-low-results')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('all-recipe-fried-rice')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fried Rice'), findsOneWidget);
      expect(find.textContaining('ความพร้อมจาก Pantry'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('start-cooking-cta')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('start-cooking-cta')));
      await tester.pumpAndSettle();

      // Sprint 5.5: starting to cook now opens the step-by-step wizard
      // (serving -> review -> confirm -> cooking mode) instead of jumping
      // straight into cooking mode from Recipe Detail.
      expect(find.text('เลือกจำนวนคน'), findsOneWidget);
    },
  );

  testWidgets('shows useful empty and filtered low-result states', (
    tester,
  ) async {
    final harness = await ShoppingUiHarness.create(recipes: _recipes);
    addTearDown(harness.dispose);
    useShoppingSurface(tester);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const AllRecipesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('recipe-discovery-search-field')),
      'not-a-real-recipe',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('recipe-discovery-empty-results')),
      findsOneWidget,
    );
    expect(find.text('ยังไม่พบสูตรที่ตรงกัน'), findsOneWidget);

    await tester.tap(find.text('เริ่มค้นหาใหม่'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('recipe-discovery-idle')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('recipe-filter-time')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ไม่เกิน 20 นาที'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('all-recipe-omelette')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('all-recipe-fried-rice')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('recipe-discovery-low-results')),
      findsOneWidget,
    );
  });
}

const List<Recipe> _recipes = <Recipe>[
  Recipe(
    id: 'omelette',
    name: 'Omelette',
    category: 'Breakfast',
    difficulty: 'easy',
    cookTimeMinutes: 10,
    cookingMethods: <String>['ทอด'],
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
    difficulty: 'easy',
    cookTimeMinutes: 30,
    cookingMethods: <String>['ผัด'],
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
