import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/design_system/feature_components/ingredient_image.dart';
import 'package:mobile/core/domain/images/image_metadata.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';

void main() {
  group('IngredientImage', () {
    testWidgets('shows the emoji fallback when the ingredient has no image', (
      tester,
    ) async {
      final ingredient = _ingredient(id: 'mackerel', emoji: '🐟');

      await tester.pumpWidget(
        MaterialApp(home: IngredientImage(ingredient: ingredient)),
      );

      expect(find.text('🐟'), findsOneWidget);
      expect(
        find.byKey(ValueKey<String>('ingredient-image-${ingredient.id}')),
        findsNothing,
      );
    });

    testWidgets(
      'shows the emoji fallback when the image is unreviewed, even with a valid URL',
      (tester) async {
        final ingredient = _ingredient(
          id: 'mackerel',
          emoji: '🐟',
          image: ImageMetadata(
            locationType: ImageLocationType.network,
            remoteUrl: 'https://example.com/mackerel.png',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(home: IngredientImage(ingredient: ingredient)),
        );
        await tester.pumpAndSettle();

        expect(find.text('🐟'), findsOneWidget);
        expect(
          find.byKey(ValueKey<String>('ingredient-image-${ingredient.id}')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'shows the fallback when an approved network image fails to load',
      (tester) async {
        final ingredient = _ingredient(
          id: 'mackerel',
          emoji: '🐟',
          image: ImageMetadata(
            locationType: ImageLocationType.network,
            remoteUrl: 'https://example.invalid/does-not-exist.png',
            reviewStatus: ImageReviewStatus.approved,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(home: IngredientImage(ingredient: ingredient)),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            ValueKey<String>('ingredient-image-fallback-${ingredient.id}'),
          ),
          findsOneWidget,
        );
        expect(find.text('🐟'), findsOneWidget);
      },
    );

    testWidgets('exposes a semantic label with the ingredient display name', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final ingredient = _ingredient(
        id: 'mackerel',
        emoji: '🐟',
        thaiName: 'ปลาทู',
      );

      await tester.pumpWidget(
        MaterialApp(home: IngredientImage(ingredient: ingredient)),
      );

      expect(find.bySemanticsLabel('รูปภาพวัตถุดิบ ปลาทู'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('lays out without overflow at a compact mobile width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final ingredient = _ingredient(id: 'mackerel', emoji: '🐟');

      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              SizedBox(
                width: 40,
                child: IngredientImage(ingredient: ingredient, size: 56),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

CanonicalIngredient _ingredient({
  required String id,
  required String emoji,
  String? thaiName,
  ImageMetadata? image,
}) {
  return CanonicalIngredient(
    id: id,
    canonicalName: id,
    localizedNames: thaiName == null
        ? const <String, String>{}
        : <String, String>{'th': thaiName},
    aliases: const <String>[],
    searchKeywords: const <String>[],
    category: 'test',
    defaultStorageType: IngredientStorageType.refrigerated,
    defaultPurchaseUnitId: 'kilogram',
    defaultInventoryUnitId: 'gram',
    emoji: emoji,
    image: image,
  );
}
