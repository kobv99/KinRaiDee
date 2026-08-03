import 'package:flutter_test/flutter_test.dart';
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
}
