import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/presentation/pages/recipe_detail_page.dart';

import '../../../support/shopping_ui_test_support.dart';

void main() {
  testWidgets(
    'Recipe Detail keeps advisory compact and adds only missing ingredients',
    (tester) async {
      final harness = await _harness();
      addTearDown(harness.dispose);
      await _pumpRecipe(tester, harness);

      expect(
        find.byKey(const ValueKey<String>('recipe-readiness-panel')),
        findsOneWidget,
      );
      expect(find.text('ความพร้อม 40%'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('recipe-readiness-recommendation'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('คุณยังเริ่มทำอาหารได้เสมอ'), findsOneWidget);
      expect(find.text('เราแนะนำให้เตรียมเพิ่ม'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('add-missing-to-shopping')),
        findsOneWidget,
      );
      expect(find.text('เริ่มทำอาหารสำหรับ 2 คน'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('recipe-readiness-toggle')),
      );
      await tester.pumpAndSettle();

      expect(find.text('เราแนะนำให้เตรียมเพิ่ม'), findsOneWidget);
      expect(
        find.textContaining('Rice · แนะนำเพิ่ม 0.8 kilogram'),
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
      expect(find.text('วัตถุดิบที่แนะนำมีอยู่ใน Shopping แล้ว'), findsOneWidget);
    },
  );

  testWidgets(
    'recommendation can be dismissed and never blocks cooking',
    (tester) async {
      final harness = await _harness();
      addTearDown(harness.dispose);
      await _pumpRecipe(tester, harness);

      await tester.tap(
        find.byKey(const ValueKey<String>('recipe-readiness-dismiss')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('recipe-readiness-panel')),
        findsNothing,
      );
      expect(find.text('Fried Rice'), findsOneWidget);
      expect(find.text('เริ่มทำอาหารสำหรับ 2 คน'), findsOneWidget);

      await tester.tap(find.text('เริ่มทำอาหารสำหรับ 2 คน'));
      await tester.pumpAndSettle();

      expect(find.text('โหมดทำอาหาร'), findsOneWidget);
      expect(find.text('ขั้นตอน 1'), findsOneWidget);
    },
  );

  testWidgets('compact and expanded advisory do not overflow small screens', (
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

    _expectNoHorizontalOverflow(
      tester,
      exception: tester.takeException(),
      phase: 'compact',
    );
    expect(
      find.byKey(const ValueKey<String>('add-missing-to-shopping')),
      findsOneWidget,
    );
    expect(find.text('เริ่มทำอาหารสำหรับ 2 คน'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('recipe-readiness-toggle')),
    );
    await tester.pumpAndSettle();

    _expectNoHorizontalOverflow(
      tester,
      exception: tester.takeException(),
      phase: 'expanded',
    );
    expect(find.text('เราแนะนำให้เตรียมเพิ่ม'), findsOneWidget);
    expect(find.text('เริ่มทำอาหารสำหรับ 2 คน'), findsOneWidget);
  });
}

void _expectNoHorizontalOverflow(
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

Future<void> _pumpRecipe(
  WidgetTester tester,
  ShoppingUiHarness harness,
) async {
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
