import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/providers/pantry_provider.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/shopping/application/shopping_providers.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_item_status.dart';
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

    testWidgets('renders actionable empty state', (tester) async {
      final harness = await ShoppingUiHarness.create();
      addTearDown(harness.dispose);
      await harness.pump(tester);

      expect(find.text('ยังไม่มีรายการซื้อของ'), findsOneWidget);
      expect(find.text('สร้างรายการจากเมนู'), findsOneWidget);
    });
  });

  group('Shopping list interactions', () {
    testWidgets('completion segments remain single-line on narrow screens', (
      tester,
    ) async {
      final harness = await ShoppingUiHarness.create(
        recipes: _recipes,
        list: testShoppingList(now: now),
      );
      addTearDown(harness.dispose);
      await harness.pump(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('shopping-completion-filter')),
      );

      tester.view.physicalSize = const Size(520, 1100);
      tester.platformDispatcher.textScaleFactorTestValue = 1.15;
      await tester.pumpAndSettle();

      for (final label in <String>['ทั้งหมด', 'ต้องซื้อ', 'เสร็จแล้ว']) {
        final text = tester
            .widgetList<Text>(find.text(label))
            .firstWhere(
              (widget) => widget.maxLines == 1 && widget.softWrap == false,
            );
        expect(text.maxLines, 1);
        expect(text.softWrap, isFalse);
      }
      expect(find.text('All'), findsNothing);
      expect(find.text('Active'), findsNothing);
      expect(find.text('Completed'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'shows overview, Pantry availability, and localized alias search',
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
          list: testShoppingList(now: now),
        );
        addTearDown(harness.dispose);
        await harness.pump(tester);

        expect(find.text('Weekend cooking'), findsOneWidget);
        expect(find.text('Egg'), findsOneWidget);
        expect(find.text('Rice'), findsOneWidget);
        expect(find.text('ใน Pantry 2 ชิ้น'), findsOneWidget);

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

        await tester.tap(find.text('เสร็จแล้ว'));
        await tester.pumpAndSettle();
        expect(find.text('ไม่พบรายการตามตัวกรอง'), findsOneWidget);

        await tester.tap(find.text('ล้างตัวกรอง'));
        await tester.pumpAndSettle();
        expect(find.text('Egg'), findsOneWidget);
        expect(
          harness.container.read(shoppingViewProvider).hasFilters,
          isFalse,
        );
      },
    );

    testWidgets('check and undo synchronize Pantry through durable commits', (
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
        find.byKey(const ValueKey<String>('shopping-check-egg-item')),
      );
      await tester.pumpAndSettle();

      expect(harness.container.read(pantryProvider).single.quantity, 8);
      expect(
        harness.container
            .read(shoppingListsProvider)
            .value!
            .single
            .items
            .single
            .status,
        ShoppingItemStatus.purchased,
      );
      expect(find.textContaining('เพิ่มเข้า Pantry แล้ว'), findsOneWidget);

      await tester.tap(find.byType(SnackBarAction));
      await tester.pumpAndSettle();

      final restored = (await harness.lists()).single.items.single;
      expect(restored.status, ShoppingItemStatus.active);
      expect(harness.container.read(pantryProvider).single.quantity, 2);
      expect(find.text('ยกเลิกการซื้อแล้ว'), findsOneWidget);
    });

    testWidgets('edit and delete support single-use UI undo', (tester) async {
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

      await tester.tap(
        find.byKey(const ValueKey<String>('shopping-undo-action')),
      );
      await tester.pumpAndSettle();
      expect((await harness.lists()).single.items.single.quantity, 6);

      await tester.tap(
        find.byKey(const ValueKey<String>('shopping-delete-egg-item')),
      );
      await tester.pumpAndSettle();
      expect(find.text('ลบรายการนี้?'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('shopping-confirm-delete')),
      );
      await tester.pumpAndSettle();
      expect((await harness.lists()).single.items, isEmpty);

      await tester.tap(find.byType(SnackBarAction));
      await tester.pumpAndSettle();
      expect((await harness.lists()).single.items.single.displayName, 'Egg');
    });

    testWidgets('archives and restores completed entries', (tester) async {
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
        find.byKey(const ValueKey<String>('shopping-check-egg-item')),
      );
      await tester.pumpAndSettle();

      final archive = find.byKey(
        const ValueKey<String>('shopping-archive-completed'),
      );
      await tester.ensureVisible(archive);
      await tester.tap(archive);
      await tester.pumpAndSettle();
      expect(
        (await harness.lists()).single.items.single.status,
        ShoppingItemStatus.archived,
      );

      final restore = find.byKey(
        const ValueKey<String>('shopping-restore-egg-item'),
      );
      await tester.ensureVisible(restore);
      await tester.tap(restore);
      await tester.pumpAndSettle();
      expect(
        (await harness.lists()).single.items.single.status,
        ShoppingItemStatus.purchased,
      );
    });

    testWidgets('failed durable mutation shows an error without UI drift', (
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
        find.byKey(const ValueKey<String>('shopping-check-egg-item')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('ไม่สำเร็จอย่างปลอดภัย'), findsOneWidget);
      expect(
        (await harness.lists()).single.items.single.status,
        ShoppingItemStatus.active,
      );
      expect(harness.container.read(pantryProvider), isEmpty);
    });
  });

  testWidgets(
    'multi-recipe preview confirms and regenerates without duplicates',
    (tester) async {
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
      );
      addTearDown(harness.dispose);
      await harness.pump(tester);

      await _generateAllRecipes(tester);
      final firstList = (await harness.lists()).single;
      expect(firstList.items, hasLength(2));
      expect(
        firstList.items.map((item) => item.canonicalIngredientId).toSet(),
        <String>{'egg', 'rice'},
      );
      expect(
        firstList.items
            .singleWhere((item) => item.canonicalIngredientId == 'egg')
            .quantity,
        2,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('shopping-generate-button')),
      );
      await tester.pumpAndSettle();
      await _selectRecipesAndConfirm(tester);

      final regenerated = (await harness.lists()).single;
      expect(regenerated.items, hasLength(2));
      expect(
        regenerated.items
            .where((item) => item.status == ShoppingItemStatus.active)
            .map((item) => item.canonicalIngredientId)
            .toSet(),
        hasLength(2),
      );
      expect(regenerated.revision, greaterThan(firstList.revision));
    },
  );
}

Future<void> _generateAllRecipes(WidgetTester tester) async {
  await tester.tap(find.text('สร้างรายการจากเมนู'));
  await tester.pumpAndSettle();
  await _selectRecipesAndConfirm(tester);
}

Future<void> _selectRecipesAndConfirm(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey<String>('shopping-recipe-omelette')),
  );
  await tester.pump();
  await tester.tap(
    find.byKey(const ValueKey<String>('shopping-recipe-fried-rice')),
  );
  await tester.pump();
  await tester.tap(
    find.byKey(const ValueKey<String>('shopping-preview-button')),
  );
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey<String>('shopping-generation-preview')),
    findsOneWidget,
  );
  expect(find.text('2'), findsWidgets);
  await tester.tap(
    find.byKey(const ValueKey<String>('shopping-confirm-button')),
  );
  await tester.pumpAndSettle();
}

const List<Recipe> _recipes = <Recipe>[
  Recipe(
    id: 'omelette',
    name: 'Omelette',
    category: 'Breakfast',
    emoji: 'O',
    cookTimeMinutes: 10,
    servings: 2,
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
