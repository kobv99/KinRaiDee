import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/navigation/app_navigation_provider.dart';
import 'package:mobile/core/providers/pantry_provider.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/shopping/application/shopping_providers.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_list.dart';
import 'package:mobile/features/shopping/presentation/pages/shopping_page.dart';
import 'package:mobile/features/shopping/presentation/providers/shopping_view_provider.dart';

import '../../support/shopping_ui_test_support.dart';

void main() {
  final now = DateTime.utc(2026, 7, 26, 10);

  group('Shopping screen states', () {
    testWidgets('renders loading state', (tester) async {
      useShoppingSurface(tester);
      final pending = Completer<List<ShoppingList>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shoppingListsProvider.overrideWith((ref) => pending.future),
          ],
          child: const MaterialApp(home: ShoppingPage()),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('shopping-loading-state')),
        findsOneWidget,
      );
      pending.complete(const <ShoppingList>[]);
      await tester.pumpAndSettle();
    });

    testWidgets('renders error state with recovery action', (tester) async {
      useShoppingSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shoppingListsProvider.overrideWith(
              (ref) => Future.error(StateError('offline read failed')),
            ),
          ],
          child: const MaterialApp(home: ShoppingPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('shopping-error-state')),
        findsOneWidget,
      );
      expect(find.text('ลองอีกครั้ง'), findsOneWidget);
    });

    testWidgets('renders Pantry-first initial empty state', (tester) async {
      final harness = await ShoppingUiHarness.create();
      addTearDown(harness.dispose);
      await harness.pump(tester);

      expect(find.text('ยังไม่มีรายการซื้อของ'), findsOneWidget);
      expect(find.text('ไปเลือกสูตรจาก Pantry'), findsOneWidget);

      await tester.tap(find.text('ไปเลือกสูตรจาก Pantry'));
      await tester.pump();

      expect(
        harness.container.read(appNavigationProvider),
        AppNavigationNotifier.recipeTab,
      );
      expect(await harness.lists(), isEmpty);
    });
  });

  group('Shopping list interactions', () {
    testWidgets('shows active overview, availability, search, and filters', (
      tester,
    ) async {
      final harness = await ShoppingUiHarness.create(
        pantry: [
          testPantryLot(
            id: 'egg-lot',
            canonicalId: 'egg',
            name: 'Egg',
            quantity: 2,
            unit: 'piece',
            now: now,
          ),
        ],
        recipes: _recipes,
        list: testShoppingList(now: now),
      );
      addTearDown(harness.dispose);
      await harness.pump(tester);

      expect(find.text('Weekend cooking'), findsOneWidget);
      expect(find.text('ต้องซื้อ 2 รายการ'), findsOneWidget);
      expect(find.text('Egg'), findsOneWidget);
      expect(find.text('Rice'), findsOneWidget);
      expect(find.text('ใน Pantry 2 ชิ้น'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('shopping-category-filter')),
        findsNothing,
      );

      // Category/sort dropdowns are secondary, tucked behind a filter
      // sheet so Search and the actual Shopping list stay dominant.
      await tester.tap(
        find.byKey(const ValueKey<String>('shopping-open-filters')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('shopping-category-filter')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('shopping-sort-filter')),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.text('รายการที่เสร็จแล้ว'), findsNothing);
      expect(find.text('เสร็จแล้ว'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey<String>('shopping-search-field')),
        'ไข่ไก่',
      );
      await tester.pumpAndSettle();
      expect(find.text('Egg'), findsOneWidget);
      expect(find.text('Rice'), findsNothing);

      await tester.tap(find.byTooltip('ล้างคำค้น'));
      await tester.pumpAndSettle();
      expect(find.text('Rice'), findsOneWidget);
      expect(harness.container.read(shoppingViewProvider).hasFilters, isFalse);
    });

    testWidgets(
      'purchase updates Pantry, removes Shopping, records history, and undoes',
      (tester) async {
        final harness = await ShoppingUiHarness.create(
          pantry: [
            testPantryLot(
              id: 'egg-lot',
              canonicalId: 'egg',
              name: 'Egg',
              quantity: 2,
              unit: 'piece',
              now: now,
            ),
          ],
          recipes: _recipes,
          list: testShoppingList(
            now: now,
            items: [
              testShoppingItem(
                id: 'egg-item',
                canonicalId: 'egg',
                name: 'Egg',
                quantity: 6,
                unit: 'piece',
                category: testShoppingList(now: now).items.first.category,
                recipeIds: const <String>['omelette'],
                now: now,
              ),
            ],
          ),
        );
        addTearDown(harness.dispose);
        await harness.pump(tester);

        await tester.tap(
          find.byKey(const ValueKey<String>('shopping-complete-egg-item')),
        );
        await tester.pumpAndSettle();

        expect(harness.container.read(pantryProvider).single.quantity, 8);
        expect((await harness.lists()).single.items, isEmpty);
        expect(await harness.history(), hasLength(1));
        expect(find.text('✓ Pantry อัปเดตแล้ว'), findsOneWidget);
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.persist, isFalse);
        expect(
          find.byKey(const ValueKey<String>('shopping-complete-empty-state')),
          findsOneWidget,
        );
        expect(find.text('🎉 ไม่มีรายการที่ต้องซื้อแล้ว'), findsOneWidget);
        expect(find.text('Pantry พร้อมสำหรับสูตรที่วางแผนไว้'), findsOneWidget);

        await tester.tap(find.byType(SnackBarAction));
        await tester.pumpAndSettle();

        expect((await harness.lists()).single.items.single.id, 'egg-item');
        expect(harness.container.read(pantryProvider).single.quantity, 2);
        expect(await harness.history(), isEmpty);
        expect(find.text('คืนรายการและจำนวนใน Pantry แล้ว'), findsOneWidget);
      },
    );

    testWidgets('edit and delete retain single-use Snackbar undo', (
      tester,
    ) async {
      final harness = await ShoppingUiHarness.create(
        recipes: _recipes,
        list: testShoppingList(
          now: now,
          items: [
            testShoppingItem(
              id: 'egg-item',
              canonicalId: 'egg',
              name: 'Egg',
              quantity: 6,
              unit: 'piece',
              category: testShoppingList(now: now).items.first.category,
              recipeIds: const <String>['omelette'],
              now: now,
            ),
          ],
        ),
      );
      addTearDown(harness.dispose);
      await harness.pump(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('shopping-edit-egg-item')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('shopping-quantity-field')),
        '12',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('shopping-save-quantity')),
      );
      await tester.pumpAndSettle();
      expect((await harness.lists()).single.items.single.quantity, 12);

      await tester.tap(find.byType(SnackBarAction));
      await tester.pumpAndSettle();
      expect((await harness.lists()).single.items.single.quantity, 6);

      await tester.tap(
        find.byKey(const ValueKey<String>('shopping-delete-egg-item')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('shopping-confirm-delete')),
      );
      await tester.pumpAndSettle();
      expect((await harness.lists()).single.items, isEmpty);

      await tester.tap(find.byType(SnackBarAction));
      await tester.pumpAndSettle();
      expect((await harness.lists()).single.items.single.displayName, 'Egg');
    });

    testWidgets('failed durable completion shows safe error without UI drift', (
      tester,
    ) async {
      final harness = await ShoppingUiHarness.create(
        recipes: _recipes,
        list: testShoppingList(
          now: now,
          items: [
            testShoppingItem(
              id: 'egg-item',
              canonicalId: 'egg',
              name: 'Egg',
              quantity: 6,
              unit: 'piece',
              category: testShoppingList(now: now).items.first.category,
              recipeIds: const <String>['omelette'],
              now: now,
            ),
          ],
        ),
      );
      addTearDown(harness.dispose);
      await harness.pump(tester);
      harness.store.failEnvelopeWrites = true;

      await tester.tap(
        find.byKey(const ValueKey<String>('shopping-complete-egg-item')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('ทำรายการไม่สำเร็จ ข้อมูลเดิมยังคงปลอดภัย'),
        findsOneWidget,
      );
      expect(find.textContaining('shopping-purchase:'), findsNothing);
      expect((await harness.lists()).single.items.single.id, 'egg-item');
      expect(harness.container.read(pantryProvider), isEmpty);
      expect(await harness.history(), isEmpty);
    });

    testWidgets('planning from Shopping routes to Recipes without mutation', (
      tester,
    ) async {
      final initial = testShoppingList(now: now);
      final harness = await ShoppingUiHarness.create(
        pantry: [
          testPantryLot(
            id: 'egg-lot',
            canonicalId: 'egg',
            name: 'Egg',
            quantity: 1,
            unit: 'piece',
            now: now,
          ),
        ],
        recipes: _recipes,
        list: initial,
      );
      addTearDown(harness.dispose);
      await harness.pump(tester);

      final before = (await harness.lists()).single;
      await tester.tap(
        find.byKey(const ValueKey<String>('shopping-generate-button')),
      );
      await tester.pump();

      expect(
        harness.container.read(appNavigationProvider),
        AppNavigationNotifier.recipeTab,
      );
      final after = (await harness.lists()).single;
      expect(after.revision, before.revision);
      expect(
        after.items.map((item) => item.id),
        orderedEquals(before.items.map((item) => item.id)),
      );
    });
  });
}

const List<Recipe> _recipes = <Recipe>[
  Recipe(
    id: 'omelette',
    name: 'Omelette',
    category: 'Breakfast',
    emoji: 'O',
    cookTimeMinutes: 10,
    servings: 2,
    heroIngredientId: 'egg',
    ingredients: <RecipeIngredient>[
      RecipeIngredient(id: 'egg', name: 'Egg', quantity: 2, unit: 'piece'),
    ],
    steps: <String>['Cook'],
  ),
  Recipe(
    id: 'fried-rice',
    name: 'Fried rice',
    category: 'Main',
    emoji: 'R',
    cookTimeMinutes: 20,
    servings: 2,
    heroIngredientId: 'rice',
    ingredients: <RecipeIngredient>[
      RecipeIngredient(
        id: 'egg',
        name: 'Chicken egg',
        quantity: 1,
        unit: 'piece',
      ),
      RecipeIngredient(
        id: 'rice',
        name: 'Jasmine rice',
        quantity: 500,
        unit: 'gram',
      ),
    ],
    steps: <String>['Cook'],
  ),
];
