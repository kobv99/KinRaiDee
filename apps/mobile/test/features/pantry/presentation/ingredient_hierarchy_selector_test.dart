import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/canonical_ingredient_providers.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/features/pantry/data/ingredient_hierarchy_loader.dart';
import 'package:mobile/features/pantry/domain/models/ingredient_hierarchy.dart';
import 'package:mobile/features/pantry/presentation/widgets/emoji_selector.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CanonicalIngredientRegistry registry;
  late IngredientHierarchy hierarchy;

  setUpAll(() async {
    registry = await IngredientCatalog().loadRegistry();
    hierarchy = await IngredientHierarchyLoader().load(registry: registry);
  });

  Future<void> pumpSelector(
    WidgetTester tester, {
    IngredientSelectedCallback? onSelected,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          canonicalIngredientRegistryProvider.overrideWithValue(registry),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EmojiSelector(
                onSelected: onSelected ?? (_, _, _, _) {},
                initialHierarchy: hierarchy,
              ),
            ),
          ),
        ),
      ),
    );
    for (var index = 0; index < 5; index++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('ingredient-hierarchy-error')), findsNothing);
  }

  testWidgets('initially displays only top-level categories', (tester) async {
    await pumpSelector(tester);

    expect(find.byKey(const Key('label-category_meat')), findsOneWidget);
    expect(find.byKey(const Key('label-category_seafood')), findsOneWidget);
    expect(find.byKey(const Key('label-family_pork')), findsNothing);
    expect(find.byKey(const Key('label-pork_belly')), findsNothing);
  });

  testWidgets('expanding Meat displays only its direct families', (
    tester,
  ) async {
    await pumpSelector(tester);
    await tester.tap(find.byKey(const Key('expand-category_meat')));
    await tester.pump();

    expect(find.byKey(const Key('label-family_pork')), findsOneWidget);
    expect(find.byKey(const Key('label-family_chicken')), findsOneWidget);
    expect(find.byKey(const Key('label-family_beef')), findsOneWidget);
    expect(find.byKey(const Key('label-family_duck')), findsOneWidget);
    expect(find.byKey(const Key('label-pork_belly')), findsNothing);
    expect(find.byKey(const Key('label-family_fish')), findsNothing);
  });

  testWidgets('expanding Pork displays only pork ingredients', (tester) async {
    await pumpSelector(tester);
    await tester.tap(find.byKey(const Key('expand-category_meat')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('expand-family_pork')));
    await tester.pump();

    expect(find.byKey(const Key('label-pork_belly')), findsOneWidget);
    expect(find.byKey(const Key('label-minced_pork')), findsOneWidget);
    expect(find.byKey(const Key('label-chicken_breast')), findsNothing);
    expect(find.byKey(const Key('label-beef_ribeye')), findsNothing);
  });

  testWidgets('collapse preserves selected pork ingredient without siblings', (
    tester,
  ) async {
    await pumpSelector(tester);
    await tester.tap(find.byKey(const Key('expand-category_meat')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('expand-family_pork')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('select-pork_belly')));
    await tester.pump();

    expect(_checkbox(tester, 'pork_belly').value, isTrue);
    expect(_checkbox(tester, 'minced_pork').value, isFalse);

    await tester.tap(find.byKey(const Key('expand-family_pork')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('expand-family_pork')));
    await tester.pump();

    expect(_checkbox(tester, 'pork_belly').value, isTrue);
    expect(_checkbox(tester, 'minced_pork').value, isFalse);
  });

  testWidgets('search quick-add selects canonical leaf without opening tree', (
    tester,
  ) async {
    String? selectedCanonicalId;
    await pumpSelector(
      tester,
      onSelected: (_, _, _, canonicalId) {
        selectedCanonicalId = canonicalId;
      },
    );
    await tester.enterText(
      find.byKey(const Key('ingredient-hierarchy-search')),
      'หมูสามชั้น',
    );
    await tester.pump();

    expect(find.text('เนื้อสัตว์ > หมู > หมูสามชั้น'), findsOneWidget);
    expect(find.byKey(const Key('label-family_chicken')), findsNothing);

    await tester.tap(find.byKey(const Key('ingredient-search-pork_belly')));
    await tester.pump();
    expect(selectedCanonicalId, 'pork_belly');
    expect(find.byKey(const Key('label-family_pork')), findsNothing);
    expect(find.byKey(const Key('select-pork_belly')), findsNothing);
  });

  test('category and family nodes cannot be recipe ingredient IDs', () {
    final nonLeaves = <IngredientHierarchyNode>[
      ...hierarchy.topLevel,
      ...hierarchy.topLevel.expand(
        (category) => category.children.where(
          (node) => node.nodeType == IngredientNodeType.family,
        ),
      ),
    ];

    expect(
      nonLeaves,
      everyElement(
        isA<IngredientHierarchyNode>()
            .having((node) => node.selectable, 'selectable', isFalse)
            .having(
              (node) => node.canonicalIngredientId,
              'canonicalIngredientId',
              isNull,
            ),
      ),
    );
  });
}

Checkbox _checkbox(WidgetTester tester, String id) {
  return tester.widget<Checkbox>(find.byKey(Key('select-$id')));
}
