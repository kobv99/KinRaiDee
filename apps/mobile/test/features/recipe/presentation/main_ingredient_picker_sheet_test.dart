import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/presentation/widgets/main_ingredient_picker_sheet.dart';

void main() {
  testWidgets('shows automatic mode and returns automatic intent', (
    tester,
  ) async {
    final results = <MainIngredientPickerResult>[];
    await _pumpPicker(
      tester,
      onResult: results.add,
      initialMode: MainIngredientSelectionMode.automatic,
    );

    expect(find.text('ให้ระบบเลือกอัตโนมัติ'), findsOneWidget);
    expect(find.text('ดูของในคลัง ความพร้อม และเมนูที่ทำได้'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('main-ingredient-automatic-selected')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('main-ingredient-auto-option')),
    );

    expect(results, hasLength(1));
    expect(results.single.mode, MainIngredientSelectionMode.automatic);
    expect(results.single.canonicalIngredientId, isNull);
  });

  testWidgets('searches aliases and allows a supported non-Pantry option', (
    tester,
  ) async {
    final results = <MainIngredientPickerResult>[];
    await _pumpPicker(
      tester,
      onResult: results.add,
      initialMode: MainIngredientSelectionMode.automatic,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('main-ingredient-search-field')),
      'ปลาทูนึ่ง',
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('main-ingredient-option-mackerel')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('main-ingredient-option-mackerel'),
        ),
        matching: find.textContaining('ยังไม่มีใน Pantry'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('main-ingredient-option-pork_belly')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('main-ingredient-option-mackerel')),
    );

    expect(results.single.mode, MainIngredientSelectionMode.manual);
    expect(results.single.canonicalIngredientId, 'mackerel');
    expect(results.single.pinAction, MainIngredientPinAction.none);
  });

  testWidgets('shows recents and keeps Pantry options before exploration', (
    tester,
  ) async {
    await _pumpPicker(
      tester,
      onResult: (_) {},
      initialMode: MainIngredientSelectionMode.automatic,
      recentIngredientIds: const <String>['shrimp'],
    );

    expect(find.text('เลือกล่าสุด'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('main-ingredient-recent-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('main-ingredient-pantry-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('main-ingredient-explore-section')),
      findsOneWidget,
    );

    final pantryTop = tester
        .getTopLeft(
          find.byKey(
            const ValueKey<String>('main-ingredient-option-pork_belly'),
          ),
        )
        .dy;
    final explorationTop = tester
        .getTopLeft(
          find.byKey(const ValueKey<String>('main-ingredient-option-mackerel')),
        )
        .dy;
    expect(pantryTop, lessThan(explorationTop));
    expect(
      find.byKey(const ValueKey<String>('main-ingredient-option-shrimp')),
      findsOneWidget,
    );
  });

  testWidgets('shows manual selection and emits optional pin actions', (
    tester,
  ) async {
    final results = <MainIngredientPickerResult>[];
    await _pumpPicker(
      tester,
      onResult: results.add,
      initialMode: MainIngredientSelectionMode.manual,
      selectedIngredientId: 'pork_belly',
      showPinAction: true,
    );

    expect(find.textContaining('เลือกด้วยตนเองอยู่'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('main-ingredient-manual-selected')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('main-ingredient-pin-pork_belly')),
    );

    expect(results.single.canonicalIngredientId, 'pork_belly');
    expect(results.single.mode, MainIngredientSelectionMode.manual);
    expect(results.single.pinAction, MainIngredientPinAction.pin);

    results.clear();
    await _pumpPicker(
      tester,
      onResult: results.add,
      initialMode: MainIngredientSelectionMode.manual,
      selectedIngredientId: 'pork_belly',
      showPinAction: true,
      pinnedIngredientId: 'pork_belly',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('main-ingredient-pin-pork_belly')),
    );

    expect(results.single.pinAction, MainIngredientPinAction.unpin);
  });

  test('option input requires verified Recipe support', () {
    expect(
      () => MainIngredientPickerOption(
        canonicalId: 'fish_category',
        name: 'ปลา',
        emoji: '🐟',
        categoryLabel: 'อาหารทะเล',
        isInPantry: false,
        supportedRecipeCount: 0,
      ),
      throwsAssertionError,
    );
  });
}

Future<void> _pumpPicker(
  WidgetTester tester, {
  required ValueChanged<MainIngredientPickerResult> onResult,
  required MainIngredientSelectionMode initialMode,
  String? selectedIngredientId,
  List<String> recentIngredientIds = const <String>[],
  bool showPinAction = false,
  String? pinnedIngredientId,
}) async {
  tester.view.physicalSize = const Size(700, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: MainIngredientPickerSheet(
          options: _options,
          initialMode: initialMode,
          selectedIngredientId: selectedIngredientId,
          recentIngredientIds: recentIngredientIds,
          showPinAction: showPinAction,
          pinnedIngredientId: pinnedIngredientId,
          onResult: onResult,
        ),
      ),
    ),
  );
  await tester.pump();
}

final List<MainIngredientPickerOption> _options = <MainIngredientPickerOption>[
  MainIngredientPickerOption(
    canonicalId: 'mackerel',
    name: 'ปลาทู',
    emoji: '🐟',
    categoryLabel: 'อาหารทะเล',
    isInPantry: false,
    supportedRecipeCount: 3,
    searchTerms: <String>['ปลาทูนึ่ง'],
  ),
  MainIngredientPickerOption(
    canonicalId: 'shrimp',
    name: 'กุ้ง',
    emoji: '🦐',
    categoryLabel: 'อาหารทะเล',
    isInPantry: false,
    supportedRecipeCount: 8,
    searchTerms: <String>['กุ้งขาว'],
  ),
  MainIngredientPickerOption(
    canonicalId: 'pork_belly',
    name: 'หมูสามชั้น',
    emoji: '🐷',
    categoryLabel: 'โปรตีน',
    isInPantry: true,
    supportedRecipeCount: 4,
    searchTerms: <String>['สามชั้น'],
  ),
  MainIngredientPickerOption(
    canonicalId: 'egg',
    name: 'ไข่ไก่',
    emoji: '🥚',
    categoryLabel: 'โปรตีน',
    isInPantry: true,
    supportedRecipeCount: 10,
    searchTerms: <String>['ไข่'],
  ),
];
