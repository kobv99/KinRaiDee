import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/presentation/widgets/recipe_image.dart';

void main() {
  testWidgets('shows the emoji fallback immediately when imageUrl is null', (
    tester,
  ) async {
    final recipe = _recipe(id: 'omelette', emoji: '🍳');

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: RecipeImage(recipe: recipe))),
    );
    await tester.pump();

    expect(find.text('🍳'), findsOneWidget);
    expect(
      find.byKey(ValueKey<String>('recipe-image-${recipe.id}')),
      findsNothing,
    );
  });

  testWidgets(
    'degrades to the emoji fallback (never a broken-image icon) when the '
    'network image fails to load',
    (tester) async {
      final recipe = _recipe(
        id: 'fried-rice',
        emoji: '🍚',
        imageUrl: 'https://example.invalid/fried-rice.jpg',
      );

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: RecipeImage(recipe: recipe))),
      );
      // No real network exists in the test environment, so Image.network's
      // errorBuilder always fires; give it a few bounded frames to resolve
      // rather than pumpAndSettle(), which has no timeout of its own.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('🍚'), findsOneWidget);
      expect(find.byIcon(Icons.broken_image), findsNothing);
    },
  );

  testWidgets('respects the requested size', (tester) async {
    final recipe = _recipe(id: 'omelette', emoji: '🍳');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecipeImage(recipe: recipe, size: 80)),
      ),
    );
    await tester.pump();

    final sizedBox = tester.widget<SizedBox>(
      find.descendant(
        of: find.byType(RecipeImage),
        matching: find.byType(SizedBox),
      ),
    );
    expect(sizedBox.width, 80);
    expect(sizedBox.height, 80);
  });
}

Recipe _recipe({required String id, required String emoji, String? imageUrl}) {
  return Recipe(
    id: id,
    name: id,
    category: 'test',
    emoji: emoji,
    imageUrl: imageUrl,
    ingredients: const <RecipeIngredient>[],
    steps: const <String>[],
  );
}
