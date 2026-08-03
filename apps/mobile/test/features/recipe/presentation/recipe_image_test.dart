import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/presentation/widgets/recipe_image.dart';

void main() {
  testWidgets('shows the emoji fallback when the recipe has no imageUrl', (
    tester,
  ) async {
    final recipe = _recipe(id: 'som-tam', emoji: '🥗');

    await tester.pumpWidget(MaterialApp(home: RecipeImage(recipe: recipe)));

    expect(find.text('🥗'), findsOneWidget);
    expect(
      find.byKey(ValueKey<String>('recipe-image-${recipe.id}')),
      findsNothing,
    );
  });

  testWidgets('shows the emoji fallback when the network image fails to load', (
    tester,
  ) async {
    final recipe = _recipe(
      id: 'pad-krapao',
      emoji: '🌶️',
      imageUrl: 'https://example.invalid/does-not-exist.png',
    );

    await tester.pumpWidget(MaterialApp(home: RecipeImage(recipe: recipe)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey<String>('recipe-image-fallback-${recipe.id}')),
      findsOneWidget,
    );
    expect(find.text('🌶️'), findsOneWidget);
  });

  testWidgets('exposes a semantic label with the recipe name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final recipe = _recipe(id: 'som-tam', emoji: '🥗');

    await tester.pumpWidget(MaterialApp(home: RecipeImage(recipe: recipe)));

    expect(find.bySemanticsLabel('รูปภาพเมนู ${recipe.name}'), findsOneWidget);
    handle.dispose();
  });
}

Recipe _recipe({required String id, required String emoji, String? imageUrl}) {
  return Recipe(
    id: id,
    name: 'Test Recipe $id',
    category: 'ทดสอบ',
    ingredients: const [],
    steps: const [],
    emoji: emoji,
    imageUrl: imageUrl,
  );
}
