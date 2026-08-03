import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/images/image_metadata.dart';

void main() {
  group('ImageMetadata', () {
    test('permits an asset and a remote candidate to coexist', () {
      final metadata = ImageMetadata(
        locationType: ImageLocationType.asset,
        assetPath: 'assets/images/pad_thai.png',
        remoteUrl: 'https://example.com/pad_thai.png',
      );

      expect(metadata.assetPath, 'assets/images/pad_thai.png');
      expect(metadata.remoteUrl, 'https://example.com/pad_thai.png');
    });

    test('provenance is independent from location', () {
      final asset = ImageMetadata(
        locationType: ImageLocationType.asset,
        assetPath: 'assets/images/pad_thai.png',
        provenance: ImageProvenance.aiGenerated,
      );
      final network = ImageMetadata(
        locationType: ImageLocationType.network,
        remoteUrl: 'https://example.com/pad_thai.png',
        provenance: ImageProvenance.aiGenerated,
      );
      final none = ImageMetadata(
        locationType: ImageLocationType.none,
        provenance: ImageProvenance.firstParty,
      );

      expect(asset.provenance, ImageProvenance.aiGenerated);
      expect(network.provenance, ImageProvenance.aiGenerated);
      expect(none.provenance, ImageProvenance.firstParty);
    });

    test('rejects locationType none declared alongside a source path', () {
      expect(
        () => ImageMetadata(
          locationType: ImageLocationType.none,
          assetPath: 'assets/images/pad_thai.png',
        ),
        throwsA(
          isA<ImageMetadataException>().having(
            (error) => error.code,
            'code',
            'none_with_source',
          ),
        ),
      );
    });

    test('rejects locationType asset with no assetPath', () {
      expect(
        () => ImageMetadata(locationType: ImageLocationType.asset),
        throwsA(
          isA<ImageMetadataException>().having(
            (error) => error.code,
            'code',
            'asset_missing_path',
          ),
        ),
      );
    });

    test('rejects locationType network with no remoteUrl', () {
      expect(
        () => ImageMetadata(locationType: ImageLocationType.network),
        throwsA(
          isA<ImageMetadataException>().having(
            (error) => error.code,
            'code',
            'network_missing_url',
          ),
        ),
      );
    });

    test('rejects locationType network declared alongside an assetPath', () {
      expect(
        () => ImageMetadata(
          locationType: ImageLocationType.network,
          remoteUrl: 'https://example.com/pad_thai.png',
          assetPath: 'assets/images/pad_thai.png',
        ),
        throwsA(
          isA<ImageMetadataException>().having(
            (error) => error.code,
            'code',
            'network_with_asset',
          ),
        ),
      );
    });

    test('rejects blank assetPath, remoteUrl, and attribution', () {
      expect(
        () => ImageMetadata(
          locationType: ImageLocationType.asset,
          assetPath: '   ',
        ),
        throwsA(isA<ImageMetadataException>()),
      );
      expect(
        () => ImageMetadata(
          locationType: ImageLocationType.network,
          remoteUrl: '   ',
        ),
        throwsA(isA<ImageMetadataException>()),
      );
      expect(
        () => ImageMetadata(
          locationType: ImageLocationType.network,
          remoteUrl: 'https://example.com/pad_thai.png',
          attribution: '   ',
        ),
        throwsA(isA<ImageMetadataException>()),
      );
    });

    test('fromJson parses a full record', () {
      final metadata = ImageMetadata.fromJson(<String, dynamic>{
        'locationType': 'asset',
        'assetPath': 'assets/images/pad_thai.png',
        'remoteUrl': 'https://example.com/pad_thai.png',
        'provenance': 'photographed',
        'attribution': 'Photo by Jane',
        'reviewStatus': 'approved',
      });

      expect(metadata.locationType, ImageLocationType.asset);
      expect(metadata.assetPath, 'assets/images/pad_thai.png');
      expect(metadata.remoteUrl, 'https://example.com/pad_thai.png');
      expect(metadata.provenance, ImageProvenance.photographed);
      expect(metadata.attribution, 'Photo by Jane');
      expect(metadata.reviewStatus, ImageReviewStatus.approved);
    });

    test('fromJson defaults missing fields deterministically', () {
      final metadata = ImageMetadata.fromJson(const <String, dynamic>{});

      expect(metadata.locationType, ImageLocationType.none);
      expect(metadata.provenance, ImageProvenance.unknown);
      expect(metadata.reviewStatus, ImageReviewStatus.unreviewed);
      expect(metadata.assetPath, isNull);
      expect(metadata.remoteUrl, isNull);
    });
  });
}
