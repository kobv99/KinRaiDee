import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/canonical_ingredient_providers.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/features/pantry/domain/models/food_category.dart';
import 'package:mobile/features/pantry/data/ingredient_hierarchy_loader.dart';
import 'package:mobile/features/pantry/domain/models/ingredient_hierarchy.dart';
import 'package:mobile/features/pantry/presentation/widgets/add_ingredient_dialog.dart';
import 'package:mobile/features/pantry/presentation/widgets/emoji_selector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final unitEngine = UnitConversionEngine.standard();
  final registry = CanonicalIngredientRegistry(
    ingredients: <CanonicalIngredient>[
      _canonical(
        id: 'fish',
        name: 'ปลา',
        category: 'seafood',
        preferred: 'whole',
        recommended: const <String>['whole', 'piece', 'gram', 'kilogram'],
      ),
      _canonical(
        id: 'cooking_oil',
        name: 'น้ำมันพืช',
        category: 'seasoning',
        preferred: 'bottle',
        recommended: const <String>['bottle', 'milliliter', 'liter'],
      ),
      _canonical(
        id: 'egg',
        name: 'ไข่ไก่',
        category: 'protein',
        preferred: 'egg',
        recommended: const <String>['egg', 'pack'],
      ),
      _canonical(
        id: 'pork_belly',
        name: 'หมูสามชั้น',
        category: 'protein',
        preferred: 'gram',
        recommended: const <String>['gram', 'kilogram'],
      ),
    ],
  );
  late IngredientHierarchy hierarchy;

  setUpAll(() async {
    hierarchy = await IngredientHierarchyLoader().load(registry: registry);
  });

  Future<void> pumpDialog(
    WidgetTester tester, {
    Ingredient? ingredient,
    FoodCatalogItem? initialCatalogItem,
    String? initialSearchQuery,
  }) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          canonicalIngredientRegistryProvider.overrideWithValue(registry),
          unitConversionEngineProvider.overrideWithValue(unitEngine),
        ],
        child: MaterialApp(
          home: AddIngredientDialog(
            ingredient: ingredient,
            initialCatalogItem: initialCatalogItem,
            initialSearchQuery: initialSearchQuery,
            initialHierarchy: hierarchy,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('fish primary selector excludes liter and bottle', (
    tester,
  ) async {
    await pumpDialog(tester, initialCatalogItem: _catalog('ปลา', '🐟'));

    final primary = _unitSelector(tester, 0);
    final values = _itemValues(primary);

    expect(values, containsAll(<String>['whole', 'piece', 'gram', 'kilogram']));
    expect(values, isNot(contains('liter')));
    expect(values, isNot(contains('bottle')));
    expect(primary.value, 'whole');
  });

  testWidgets('cooking oil primary selector excludes piece and whole', (
    tester,
  ) async {
    await pumpDialog(tester, initialCatalogItem: _catalog('น้ำมันพืช', '🫗'));

    final primary = _unitSelector(tester, 0);
    final values = _itemValues(primary);

    expect(values, containsAll(<String>['bottle', 'milliliter', 'liter']));
    expect(values, isNot(contains('piece')));
    expect(values, isNot(contains('whole')));
    expect(primary.value, 'bottle');
  });

  testWidgets('egg defaults to egg', (tester) async {
    await pumpDialog(tester, initialCatalogItem: _catalog('ไข่ไก่', '🥚'));

    final primary = _unitSelector(tester, 0);

    expect(_itemValues(primary), containsAll(<String>['egg', 'pack']));
    expect(primary.value, 'egg');
  });

  testWidgets('ingredient change refreshes recommendations and default', (
    tester,
  ) async {
    await pumpDialog(tester, initialCatalogItem: _catalog('ปลา', '🐟'));
    expect(_unitSelector(tester, 0).value, 'whole');

    await tester.tap(find.byKey(const Key('change-ingredient')));
    await tester.pump();
    final selector = tester.widget<EmojiSelector>(find.byType(EmojiSelector));
    selector.onSelected('ไข่', 'ไข่ไก่', '🥚', 'egg');
    await tester.pump();

    final refreshed = _unitSelector(tester, 0);
    expect(_itemValues(refreshed), containsAll(<String>['egg', 'pack']));
    expect(_itemValues(refreshed), isNot(contains('whole')));
    expect(refreshed.value, 'egg');
  });

  testWidgets('search selection immediately opens quantity workflow', (
    tester,
  ) async {
    await pumpDialog(tester, initialSearchQuery: 'หมูสามชั้น');
    for (var index = 0; index < 5; index++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      find.byKey(const Key('ingredient-hierarchy-search')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('ingredient-search-pork_belly')));
    await tester.pump();

    expect(find.byKey(const Key('ingredient-hierarchy-search')), findsNothing);
    expect(find.byKey(const Key('ingredient-quantity-field')), findsOneWidget);
    expect(find.text('หมูสามชั้น'), findsOneWidget);
    expect(find.byKey(const Key('change-ingredient')), findsOneWidget);
  });

  testWidgets('legacy unusual unit remains recoverable through Other unit', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 7, 27);
    await pumpDialog(
      tester,
      ingredient: Ingredient(
        id: 'legacy-egg',
        name: 'ไข่ไก่',
        category: 'ไข่',
        emoji: '🥚',
        quantity: 2,
        unit: 'ช้อนชา',
        createdAt: now,
        updatedAt: now,
        canonicalIngredientId: 'egg',
        canonicalUnitId: 'teaspoon',
        canonicalMappingStatus: CanonicalMappingStatus.mapped,
      ),
    );

    expect(find.text('Other unit…'), findsWidgets);
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
    final primary = _unitSelector(tester, 0);
    final other = _unitSelector(tester, 1);

    expect(primary.value, isNot(anyOf('egg', 'pack')));
    expect(other.value, 'teaspoon');
    expect(_itemValues(other), contains('teaspoon'));
  });
}

DropdownButton<String> _unitSelector(WidgetTester tester, int index) {
  final dropdowns = find.byWidgetPredicate(
    (widget) => widget is DropdownButton<String>,
  );
  return tester.widget<DropdownButton<String>>(dropdowns.at(index));
}

List<String?> _itemValues(DropdownButton<String> selector) {
  return selector.items?.map((item) => item.value).toList(growable: false) ??
      const <String?>[];
}

FoodCatalogItem _catalog(String name, String emoji) {
  return FoodCatalogItem(
    category: 'test',
    categoryEmoji: emoji,
    item: FoodItem(name: name, emoji: emoji),
  );
}

CanonicalIngredient _canonical({
  required String id,
  required String name,
  required String category,
  required String preferred,
  required List<String> recommended,
}) {
  return CanonicalIngredient(
    id: id,
    canonicalName: id,
    localizedNames: <String, String>{'th': name},
    aliases: const <String>[],
    searchKeywords: const <String>[],
    category: category,
    defaultStorageType: IngredientStorageType.refrigerated,
    defaultPurchaseUnitId: preferred,
    defaultInventoryUnitId: preferred,
    preferredUnitId: preferred,
    recommendedUnitIds: recommended,
  );
}
