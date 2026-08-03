import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/images/image_fallback_resolver.dart';
import 'package:mobile/core/domain/images/image_metadata.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';

void main() {
  group('Recipe.imageMetadata legacy compatibility', () {
    test('parses legacy JSON with no imageUrl at all', () {
      final recipe = Recipe.fromJson(<String, dynamic>{
        'id': 'som-tam',
        'name': 'Som Tam',
        'category': 'ทั่วไป',
        'ingredients': <dynamic>[],
        'steps': <dynamic>[],
      });

      expect(recipe.imageUrl, isNull);
      expect(recipe.imageMetadata.locationType, ImageLocationType.none);
      expect(recipe.imageMetadata.remoteUrl, isNull);
    });

    test('parses legacy JSON with a populated imageUrl unchanged', () {
      final recipe = Recipe.fromJson(<String, dynamic>{
        'id': 'pad-krapao',
        'name': 'Pad Krapao',
        'category': 'ทั่วไป',
        'ingredients': <dynamic>[],
        'steps': <dynamic>[],
        'imageUrl': 'https://example.com/pad-krapao.png',
      });

      // The stored field and its JSON shape are untouched.
      expect(recipe.imageUrl, 'https://example.com/pad-krapao.png');
    });

    test('adapts a populated legacy imageUrl to pre-approved network metadata '
        'so existing rendering behavior is preserved', () {
      final recipe = Recipe.fromJson(<String, dynamic>{
        'id': 'pad-krapao',
        'name': 'Pad Krapao',
        'category': 'ทั่วไป',
        'ingredients': <dynamic>[],
        'steps': <dynamic>[],
        'imageUrl': 'https://example.com/pad-krapao.png',
      });

      final metadata = recipe.imageMetadata;
      expect(metadata.locationType, ImageLocationType.network);
      expect(metadata.remoteUrl, 'https://example.com/pad-krapao.png');
      expect(metadata.reviewStatus, ImageReviewStatus.approved);
    });

    test('an empty-string imageUrl is treated the same as absent', () {
      final recipe = Recipe.fromJson(<String, dynamic>{
        'id': 'som-tam',
        'name': 'Som Tam',
        'category': 'ทั่วไป',
        'ingredients': <dynamic>[],
        'steps': <dynamic>[],
        'imageUrl': '   ',
      });

      expect(recipe.imageUrl, isNull);
      expect(recipe.imageMetadata.locationType, ImageLocationType.none);
    });
  });

  group('Recipe.imageMetadata structured image precedence', () {
    test('a structured local-asset image is returned verbatim', () {
      final recipe = Recipe.fromJson(<String, dynamic>{
        'id': 'thai-omelette',
        'name': 'ไข่เจียว',
        'category': 'ทั่วไป',
        'ingredients': <dynamic>[],
        'steps': <dynamic>[],
        'image': <String, dynamic>{
          'locationType': 'asset',
          'assetPath': 'assets/recipe_images/thai_omelette.png',
          'provenance': 'firstParty',
          'attribution': 'KinRaiDee self-generated placeholder artwork',
          'reviewStatus': 'approved',
        },
      });

      final metadata = recipe.imageMetadata;
      expect(metadata.locationType, ImageLocationType.asset);
      expect(metadata.assetPath, 'assets/recipe_images/thai_omelette.png');
      expect(metadata.remoteUrl, isNull);
      expect(metadata.provenance, ImageProvenance.firstParty);
      expect(metadata.reviewStatus, ImageReviewStatus.approved);
    });

    test('a structured asset image with a remote fallback keeps both fields, '
        'asset-preferred', () {
      final recipe = Recipe.fromJson(<String, dynamic>{
        'id': 'thai-omelette',
        'name': 'ไข่เจียว',
        'category': 'ทั่วไป',
        'ingredients': <dynamic>[],
        'steps': <dynamic>[],
        'image': <String, dynamic>{
          'locationType': 'asset',
          'assetPath': 'assets/recipe_images/thai_omelette.png',
          'remoteUrl': 'https://example.com/thai-omelette.png',
          'reviewStatus': 'approved',
        },
      });

      final metadata = recipe.imageMetadata;
      expect(metadata.assetPath, 'assets/recipe_images/thai_omelette.png');
      expect(metadata.remoteUrl, 'https://example.com/thai-omelette.png');

      final resolution = resolveImageCandidates(
        metadata: metadata,
        fallbackGlyph: '🍳',
      );
      expect(resolution.candidates, hasLength(2));
      expect(resolution.candidates.first.locationType, ImageLocationType.asset);
      expect(
        resolution.candidates.last.locationType,
        ImageLocationType.network,
      );
    });

    test('unreviewed structured metadata yields zero render candidates', () {
      final recipe = Recipe.fromJson(<String, dynamic>{
        'id': 'thai-omelette',
        'name': 'ไข่เจียว',
        'category': 'ทั่วไป',
        'ingredients': <dynamic>[],
        'steps': <dynamic>[],
        'image': <String, dynamic>{
          'locationType': 'asset',
          'assetPath': 'assets/recipe_images/thai_omelette.png',
          'reviewStatus': 'unreviewed',
        },
      });

      final resolution = resolveImageCandidates(
        metadata: recipe.imageMetadata,
        fallbackGlyph: '🍳',
      );
      expect(resolution.candidates, isEmpty);
    });

    test('rejected structured metadata yields zero render candidates', () {
      final recipe = Recipe.fromJson(<String, dynamic>{
        'id': 'thai-omelette',
        'name': 'ไข่เจียว',
        'category': 'ทั่วไป',
        'ingredients': <dynamic>[],
        'steps': <dynamic>[],
        'image': <String, dynamic>{
          'locationType': 'asset',
          'assetPath': 'assets/recipe_images/thai_omelette.png',
          'reviewStatus': 'rejected',
        },
      });

      final resolution = resolveImageCandidates(
        metadata: recipe.imageMetadata,
        fallbackGlyph: '🍳',
      );
      expect(resolution.candidates, isEmpty);
    });

    test(
      'structured image takes precedence over a populated legacy imageUrl',
      () {
        final recipe = Recipe.fromJson(<String, dynamic>{
          'id': 'thai-omelette',
          'name': 'ไข่เจียว',
          'category': 'ทั่วไป',
          'ingredients': <dynamic>[],
          'steps': <dynamic>[],
          'imageUrl': 'https://example.com/legacy.png',
          'image': <String, dynamic>{
            'locationType': 'asset',
            'assetPath': 'assets/recipe_images/thai_omelette.png',
            'reviewStatus': 'approved',
          },
        });

        final metadata = recipe.imageMetadata;
        expect(metadata.locationType, ImageLocationType.asset);
        expect(metadata.assetPath, 'assets/recipe_images/thai_omelette.png');
        // The legacy field is untouched in storage, just not used for
        // resolution when structured metadata is present.
        expect(recipe.imageUrl, 'https://example.com/legacy.png');
      },
    );

    test('malformed structured image JSON fails predictably', () {
      expect(
        () => Recipe.fromJson(<String, dynamic>{
          'id': 'thai-omelette',
          'name': 'ไข่เจียว',
          'category': 'ทั่วไป',
          'ingredients': <dynamic>[],
          'steps': <dynamic>[],
          'image': <String, dynamic>{
            'locationType': 'asset',
            // Missing required assetPath for locationType: asset.
          },
        }),
        throwsA(isA<ImageMetadataException>()),
      );
    });
  });
}
