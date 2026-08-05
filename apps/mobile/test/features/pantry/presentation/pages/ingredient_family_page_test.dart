import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/canonical_ingredient_providers.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/providers/pantry_provider.dart';
import 'package:mobile/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:mobile/features/pantry/presentation/pages/ingredient_family_page.dart';
import 'package:mobile/features/pantry/presentation/providers/ingredient_picker_providers.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CanonicalIngredientRegistry registry;

  setUpAll(() async {
    registry = await IngredientCatalog().loadRegistry();
  });

  Future<ProviderContainer> pumpFamilyPage(
    WidgetTester tester,
    String familyId, {
    List<Ingredient> pantry = const <Ingredient>[],
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        canonicalIngredientRegistryProvider.overrideWithValue(registry),
        pantryRepositoryProvider.overrideWithValue(
          _FixturePantryRepository(pantry),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: IngredientFamilyPage(familyId: familyId)),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('fish family shows the generic, form, and both nested '
      'sub-families, but no hardcoded species at this level', (tester) async {
    await pumpFamilyPage(tester, 'fish_family');

    expect(
      find.byKey(const ValueKey<String>('ingredient-picker-option-fish')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('ingredient-picker-option-fish_fillet'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>(
          'ingredient-picker-family-card-freshwater_fish_family',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('ingredient-picker-family-card-sea_fish_family'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('ingredient-picker-option-mackerel')),
      findsNothing,
    );
  });

  testWidgets('navigating into Sea Fish reaches its species at arbitrary '
      'depth, with a root-first breadcrumb', (tester) async {
    await pumpFamilyPage(tester, 'sea_fish_family');

    expect(
      find.byKey(const ValueKey<String>('ingredient-picker-breadcrumb')),
      findsOneWidget,
    );
    expect(find.text('ปลา › ปลาทะเล'), findsOneWidget);
    for (final id in <String>['sea_bass', 'mackerel', 'salmon']) {
      expect(
        find.byKey(ValueKey<String>('ingredient-picker-option-$id')),
        findsOneWidget,
      );
    }
  });

  testWidgets('selecting a leaf ingredient toggles it and updates the '
      'sticky count', (tester) async {
    final container = await pumpFamilyPage(tester, 'chicken_family');

    await tester.tap(
      find.byKey(
        const ValueKey<String>('ingredient-picker-option-chicken_breast'),
      ),
    );
    await tester.pump();

    expect(container.read(ingredientPickerSelectionProvider), <String>{
      'chicken_breast',
    });
    expect(find.textContaining('1 รายการ'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('ingredient-picker-option-chicken_breast'),
      ),
    );
    await tester.pump();

    expect(container.read(ingredientPickerSelectionProvider), isEmpty);
  });

  testWidgets('a family node itself is never rendered as a selectable '
      'option tile', (tester) async {
    await pumpFamilyPage(tester, 'fish_family');

    expect(
      find.byKey(
        const ValueKey<String>(
          'ingredient-picker-option-freshwater_fish_family',
        ),
      ),
      findsNothing,
    );
  });
}

class _FixturePantryRepository implements PantryRepository {
  _FixturePantryRepository(this._ingredients);
  final List<Ingredient> _ingredients;

  @override
  Set<String> getFavoriteIngredientNames() => const <String>{};

  @override
  List<Ingredient> getIngredients() => List<Ingredient>.of(_ingredients);

  @override
  Future<void> saveFavoriteIngredientNames(Set<String> names) async {}
}
