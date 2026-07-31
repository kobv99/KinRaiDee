import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/providers/pantry_provider.dart';
import 'package:mobile/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:mobile/features/recipe/domain/entities/cooking_session.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/presentation/pages/cooking_mode_page.dart';
import 'package:mobile/features/recipe/presentation/providers/cooking_session_provider.dart';

void main() {
  testWidgets('cooking mode walks one step at a time with visible progress', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    expect(find.text('โหมดทำอาหาร'), findsOneWidget);
    expect(find.text('Omelette'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('cooking-progress-bar')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('cooking-start-button')),
    );
    await tester.pumpAndSettle();
    expect(container.read(cookingSessionProvider)?.isActive, isTrue);

    await tester.tap(
      find.byKey(const ValueKey<String>('cooking-checklist-next-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('ขั้นตอน 1 / 2'), findsOneWidget);
    expect(find.text('Beat eggs'), findsOneWidget);
    expect(find.text('Cook eggs'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('cooking-progress-bar')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('cooking-next-step-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('ขั้นตอน 2 / 2'), findsOneWidget);
    expect(find.text('Cook eggs'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('cooking-next-step-button')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('cooking-previous-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('ขั้นตอน 1 / 2'), findsOneWidget);
  });

  testWidgets('leaving cooking mode mid-flow asks for confirmation', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    await tester.tap(
      find.byKey(const ValueKey<String>('cooking-start-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('cooking-mode-exit-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('ออกจากโหมดทำอาหาร?'), findsOneWidget);
    await tester.tap(find.text('ทำต่อ'));
    await tester.pumpAndSettle();
    expect(find.text('โหมดทำอาหาร'), findsOneWidget);
    expect(container.read(cookingSessionProvider)?.isActive, isTrue);

    await tester.tap(
      find.byKey(const ValueKey<String>('cooking-mode-exit-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ออก'));
    await tester.pumpAndSettle();

    expect(
      container.read(cookingSessionProvider)?.status,
      CookingSessionStatus.abandoned,
    );
  });

  testWidgets('finishing cooking completes the session and congratulates', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    await tester.tap(
      find.byKey(const ValueKey<String>('cooking-start-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('cooking-checklist-next-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('cooking-next-step-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('cooking-finish-button')),
    );
    await tester.pumpAndSettle();

    // Empty pantry: nothing is deductible, so the flow explains and completes.
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('รับทราบ'));
    await tester.pumpAndSettle();

    expect(find.text('ทำอาหารเสร็จแล้ว 🎉'), findsOneWidget);
    expect(
      container.read(cookingSessionProvider)?.status,
      CookingSessionStatus.completed,
    );
  });
}

ProviderContainer _container() {
  return ProviderContainer(
    overrides: [
      pantryRepositoryProvider.overrideWithValue(_EmptyPantryRepository()),
    ],
  );
}

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: CookingModePage(recipe: _recipe, servings: 2),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _recipe = Recipe(
  id: 'omelette',
  name: 'Omelette',
  category: 'Breakfast',
  description: 'A complete test recipe.',
  emoji: 'O',
  difficulty: 'medium',
  cookTimeMinutes: 12,
  servings: 2,
  tags: <String>['quick'],
  cookingMethods: <String>['pan'],
  heroIngredientId: 'egg',
  heroIngredientName: 'Egg',
  popularity: 10,
  sourceUrl: 'https://example.invalid/omelette',
  ingredients: <RecipeIngredient>[
    RecipeIngredient(id: 'egg', name: 'Egg', quantity: 2, unit: 'piece'),
  ],
  steps: <String>['Beat eggs', 'Cook eggs'],
);

class _EmptyPantryRepository implements PantryRepository {
  @override
  List<Ingredient> getIngredients() => const <Ingredient>[];

  @override
  Set<String> getFavoriteIngredientNames() => const <String>{};

  @override
  Future<void> saveFavoriteIngredientNames(Set<String> names) async {}
}
