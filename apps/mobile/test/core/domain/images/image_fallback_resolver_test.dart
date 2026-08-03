import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/images/image_fallback_resolver.dart';
import 'package:mobile/core/domain/images/image_metadata.dart';

void main() {
  group('resolveImageCandidates', () {
    test('local asset takes precedence over remote when both are approved', () {
      final metadata = ImageMetadata(
        locationType: ImageLocationType.asset,
        assetPath: 'assets/images/pad_thai.png',
        remoteUrl: 'https://example.com/pad_thai.png',
        reviewStatus: ImageReviewStatus.approved,
      );

      final resolution = resolveImageCandidates(
        metadata: metadata,
        fallbackGlyph: '🍜',
      );

      expect(resolution.candidates, hasLength(2));
      expect(resolution.candidates[0].locationType, ImageLocationType.asset);
      expect(resolution.candidates[0].path, 'assets/images/pad_thai.png');
      expect(resolution.candidates[1].locationType, ImageLocationType.network);
      expect(resolution.candidates[1].path, 'https://example.com/pad_thai.png');
    });

    test('approved metadata with only a remote URL produces one candidate', () {
      final metadata = ImageMetadata(
        locationType: ImageLocationType.network,
        remoteUrl: 'https://example.com/pad_thai.png',
        reviewStatus: ImageReviewStatus.approved,
      );

      final resolution = resolveImageCandidates(
        metadata: metadata,
        fallbackGlyph: '🍜',
      );

      expect(resolution.candidates, hasLength(1));
      expect(
        resolution.candidates.single.locationType,
        ImageLocationType.network,
      );
    });

    test('unreviewed metadata produces zero candidates and falls back', () {
      final metadata = ImageMetadata(
        locationType: ImageLocationType.asset,
        assetPath: 'assets/images/pad_thai.png',
      );

      final resolution = resolveImageCandidates(
        metadata: metadata,
        fallbackGlyph: '🍜',
      );

      expect(resolution.candidates, isEmpty);
      expect(resolution.fallbackGlyph, '🍜');
    });

    test(
      'rejected metadata produces zero candidates regardless of populated paths',
      () {
        final metadata = ImageMetadata(
          locationType: ImageLocationType.asset,
          assetPath: 'assets/images/pad_thai.png',
          remoteUrl: 'https://example.com/pad_thai.png',
          reviewStatus: ImageReviewStatus.rejected,
        );

        final resolution = resolveImageCandidates(
          metadata: metadata,
          fallbackGlyph: '🍜',
        );

        expect(resolution.candidates, isEmpty);
      },
    );

    test('null metadata produces zero candidates', () {
      final resolution = resolveImageCandidates(
        metadata: null,
        fallbackGlyph: '🍜',
      );

      expect(resolution.candidates, isEmpty);
      expect(resolution.fallbackGlyph, '🍜');
    });

    test('locationType none, even if approved, produces zero candidates', () {
      final metadata = ImageMetadata(
        locationType: ImageLocationType.none,
        reviewStatus: ImageReviewStatus.approved,
      );

      final resolution = resolveImageCandidates(
        metadata: metadata,
        fallbackGlyph: '🍜',
      );

      expect(resolution.candidates, isEmpty);
    });
  });
}
