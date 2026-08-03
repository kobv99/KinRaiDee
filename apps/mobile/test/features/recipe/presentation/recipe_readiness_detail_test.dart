import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/presentation/pages/recipe_detail_page.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_category.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_item.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_list.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_source.dart';

import '../../../support/shopping_ui_test_support.dart';

/// NOTE: this file was rewritten for the Sprint 5.5 Recipe Detail redesign.
/// The old advisory panel (compact/expand/dismiss, keys
/// 'recipe-readiness-panel'/'-toggle'/'-dismiss'/'-recommendation') no
/// longer exists — it was replaced by [RecipeDetailHeader]'s always-visible
/// PantryReadinessCard, per the approved mockup. These tests keep the real
/// business-logic assertions (missing-ingredient quantity, shopping-list
/// dedup, cooking is never blocked) and drop only the assertions tied to
/// UI structure that was intentionally removed.
void main() {
  testWidgets(
    'Recipe Detail adds only the missing ingredient, with dedup on repeat',
    (tester) async {
      final harness = await _harness();
      addTearDown(harness.dispose);
      await _pumpRecipe(tester, harness);

      // Readiness numbers come from the same underlying provider as before —
      // still real, still visible, just in the new PantryReadinessCard shape.
      expect(find.textContaining('ความพร้อมจาก Pantry'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('add-missing-to-shopping')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('start-cooking-cta')),
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

      // Adding missing ingredients shows a confirmation sheet (matching the
      // cooking wizard's pattern) rather than a plain SnackBar, with a
      // direct way to jump to Shopping or stay on Recipe Detail.
      expect(
        find.text('เพิ่มวัตถุดิบที่ขาดเข้า Shopping แล้ว'),
        findsOneWidget,
      );
      expect(find.text('ทำต่อ'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>(
            'added-to-shopping-confirmation-go-to-shopping',
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('ทำต่อ'));
      await tester.pumpAndSettle();

      // The card must now reflect that the missing ingredient is already
      // planned for purchase, offering a direct "go to Shopping" action
      // instead of "add again".
      expect(find.textContaining('เพิ่มเข้า Shopping แล้ว'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('go-to-shopping-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('add-missing-to-shopping')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Recipe Detail shows the already-in-Shopping state on load, without any tap',
    (tester) async {
      final now = DateTime.utc(2026, 7, 28, 8);
      final list = ShoppingList(
        id: 'primary-shopping-list',
        name: 'รายการซื้อของของฉัน',
        items: <ShoppingItem>[
          ShoppingItem(
            id: 'item-rice',
            canonicalIngredientId: 'rice',
            displayName: 'Rice',
            quantity: 0.8,
            unitId: 'kilogram',
            category: ShoppingCategory.grains,
            source: ShoppingSource.recipe,
            sourceReferenceIds: const <String>['fried-rice'],
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      final harness = await ShoppingUiHarness.create(
        at: now,
        list: list,
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
      await _pumpRecipe(tester, harness);

      // Rice is already in Shopping (sourced from this recipe), so the
      // card must reflect that on first render — not just after tapping
      // "เพิ่มวัตถุดิบ" — and offer a direct way to see it instead of
      // an "add again" action.
      expect(find.textContaining('เพิ่มเข้า Shopping แล้ว'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('go-to-shopping-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('add-missing-to-shopping')),
        findsNothing,
      );
    },
  );

  testWidgets('missing ingredients never block starting the cooking wizard', (
    tester,
  ) async {
    final harness = await _harness();
    addTearDown(harness.dispose);
    await _pumpRecipe(tester, harness);

    expect(find.text('Fried Rice'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('start-cooking-cta')));
    await tester.pumpAndSettle();

    // The recipe is still missing rice, but cooking must not be gated on it
    // — the wizard opens straight to its first step (serving selection).
    expect(find.text('เลือกจำนวนคน'), findsOneWidget);
  });

  testWidgets('Recipe Detail does not overflow on a small phone screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await _harness();
    addTearDown(harness.dispose);
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

    _expectNoOverflow(
      tester,
      exception: tester.takeException(),
      phase: 'initial render',
    );
    expect(
      find.byKey(const ValueKey<String>('start-cooking-cta')),
      findsOneWidget,
    );
  });
}

void _expectNoOverflow(
  WidgetTester tester, {
  required Object? exception,
  required String phase,
}) {
  if (exception == null) {
    return;
  }

  final reports = <String>[];
  for (final element in find.byType(Row).evaluate()) {
    final renderObject = element.renderObject;
    if (renderObject is! RenderFlex ||
        renderObject.direction != Axis.horizontal ||
        !renderObject.hasSize) {
      continue;
    }

    var minLeft = 0.0;
    var maxRight = renderObject.size.width;
    RenderBox? child = renderObject.firstChild;
    while (child != null) {
      final parentData = child.parentData;
      if (parentData is FlexParentData && child.hasSize) {
        final rect = parentData.offset & child.size;
        if (rect.left < minLeft) {
          minLeft = rect.left;
        }
        if (rect.right > maxRight) {
          maxRight = rect.right;
        }
      }
      child = renderObject.childAfter(child);
    }

    final leftOverflow = -minLeft;
    final rightOverflow = maxRight - renderObject.size.width;
    if (leftOverflow <= 0.5 && rightOverflow <= 0.5) {
      continue;
    }

    final labels = <String>[];
    void collectText(Element current) {
      final widget = current.widget;
      if (widget is Text && widget.data != null && widget.data!.isNotEmpty) {
        labels.add(widget.data!);
      }
      current.visitChildren(collectText);
    }

    collectText(element);
    reports.add(
      'Row labels=${labels.join(' | ')} '
      'size=${renderObject.size} '
      'leftOverflow=${leftOverflow.toStringAsFixed(1)} '
      'rightOverflow=${rightOverflow.toStringAsFixed(1)} '
      'owner=${renderObject.debugCreator}',
    );
  }

  fail(
    'Layout exception during $phase: $exception\n'
    'Measured overflowing rows:\n'
    '${reports.isEmpty ? '(none found)' : reports.join('\n---\n')}',
  );
}

Future<ShoppingUiHarness> _harness() {
  final now = DateTime.utc(2026, 7, 28, 8);
  return ShoppingUiHarness.create(
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
}

Future<void> _pumpRecipe(WidgetTester tester, ShoppingUiHarness harness) async {
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
