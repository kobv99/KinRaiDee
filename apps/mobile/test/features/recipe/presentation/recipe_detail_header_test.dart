import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/images/image_metadata.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/services/recipe_serving_calculator.dart';
import 'package:mobile/features/recipe/presentation/widgets/recipe_detail_header.dart';

/// A 1x1 transparent PNG, embedded only for this test — never registered as
/// a pubspec asset or shipped in the app.
final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBA'
  'ScY42YAAAAASUVORK5CYII=',
);

final ByteData _emptyAssetManifest = const StandardMessageCodec().encodeMessage(
  <Object?, Object?>{},
)!;

/// Serves [_onePixelPng] for one specific key and throws for everything
/// else, simulating a present asset versus a missing/broken one without
/// touching the real asset bundle or pubspec.yaml.
class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this._presentKey);

  final String _presentKey;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return _emptyAssetManifest;
    }
    if (key != _presentKey) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    final buffer = _onePixelPng.buffer;
    return ByteData.view(buffer, 0, _onePixelPng.length);
  }
}

Widget _wrap(
  Widget child, {
  String presentAssetKey = 'assets/images/present.png',
}) {
  return MaterialApp(
    home: DefaultAssetBundle(
      bundle: _FakeAssetBundle(presentAssetKey),
      child: Scaffold(body: child),
    ),
  );
}

RecipeServingPlan _servingPlanFor(Recipe recipe) {
  return RecipeServingPlan(
    recipe: recipe,
    servings: recipe.servings,
    scaleFactor: 1,
    ingredients: const <ScaledRecipeIngredient>[],
  );
}

Recipe _recipe({
  required String id,
  required String emoji,
  ImageMetadata? image,
}) {
  return Recipe(
    id: id,
    name: 'Test Recipe $id',
    category: 'ทดสอบ',
    ingredients: const [],
    steps: const [],
    emoji: emoji,
    image: image,
  );
}

void main() {
  group('RecipeDetailHeader hero', () {
    testWidgets(
      'renders the existing gradient + emoji when there is no image',
      (tester) async {
        final recipe = _recipe(id: 'som-tam', emoji: '🥗');

        await tester.pumpWidget(
          _wrap(
            RecipeDetailHeader(
              recipe: recipe,
              servingPlan: _servingPlanFor(recipe),
              onBack: () {},
              onAddMissing: null,
              onStartCooking: () {},
            ),
          ),
        );

        expect(find.text('🥗'), findsOneWidget);
        expect(
          find.byKey(ValueKey<String>('recipe-detail-hero-image-${recipe.id}')),
          findsNothing,
        );
        expect(
          find.byKey(
            ValueKey<String>('recipe-detail-hero-fallback-${recipe.id}'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('renders the keyed hero image when an approved asset loads', (
      tester,
    ) async {
      final recipe = _recipe(
        id: 'pad-krapao',
        emoji: '🌶️',
        image: ImageMetadata(
          locationType: ImageLocationType.asset,
          assetPath: 'assets/recipe_images/present.png',
          reviewStatus: ImageReviewStatus.approved,
        ),
      );

      await tester.pumpWidget(
        _wrap(
          RecipeDetailHeader(
            recipe: recipe,
            servingPlan: _servingPlanFor(recipe),
            onBack: () {},
            onAddMissing: null,
            onStartCooking: () {},
          ),
          presentAssetKey: 'assets/recipe_images/present.png',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey<String>('recipe-detail-hero-image-${recipe.id}')),
        findsOneWidget,
      );
    });

    testWidgets(
      'falls back to the keyed exhausted glyph when the approved asset is '
      'missing/broken — not a crash or broken-image icon',
      (tester) async {
        final recipe = _recipe(
          id: 'pad-krapao',
          emoji: '🌶️',
          image: ImageMetadata(
            locationType: ImageLocationType.asset,
            assetPath: 'assets/recipe_images/does-not-exist.png',
            reviewStatus: ImageReviewStatus.approved,
          ),
        );

        await tester.pumpWidget(
          _wrap(
            RecipeDetailHeader(
              recipe: recipe,
              servingPlan: _servingPlanFor(recipe),
              onBack: () {},
              onAddMissing: null,
              onStartCooking: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(
            ValueKey<String>('recipe-detail-hero-fallback-${recipe.id}'),
          ),
          findsOneWidget,
        );
        expect(find.text('🌶️'), findsOneWidget);
      },
    );
  });
}
