/// Where the image bytes physically come from. Independent of
/// [ImageProvenance], which describes who made the image.
enum ImageLocationType { asset, network, none }

/// Who/what produced the image. Independent of [ImageLocationType].
enum ImageProvenance {
  unknown,
  aiGenerated,
  photographed,
  licensedStock,
  firstParty,
}

/// Editorial approval state. Only [approved] metadata may ever produce a
/// renderable candidate — see `resolveImageCandidates`.
enum ImageReviewStatus { unreviewed, approved, rejected }

class ImageMetadataException implements Exception {
  const ImageMetadataException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'ImageMetadataException($code): $message';
}

/// Foundation image metadata shared by recipes and canonical ingredients.
///
/// A local [assetPath] and a remote [remoteUrl] may coexist — the approved
/// precedence is asset, then remote, then a deterministic fallback glyph
/// (see `resolveImageCandidates`). [locationType] declares the primary
/// intent and is validated against which fields are populated; it does not
/// itself decide candidate order.
class ImageMetadata {
  ImageMetadata({
    required this.locationType,
    this.assetPath,
    this.remoteUrl,
    this.provenance = ImageProvenance.unknown,
    this.attribution,
    this.reviewStatus = ImageReviewStatus.unreviewed,
  }) {
    _validate();
  }

  final String? assetPath;
  final String? remoteUrl;
  final ImageLocationType locationType;
  final ImageProvenance provenance;
  final String? attribution;
  final ImageReviewStatus reviewStatus;

  void _validate() {
    if (assetPath != null && assetPath!.trim().isEmpty) {
      throw const ImageMetadataException(
        'blank_asset_path',
        'assetPath must not be blank.',
      );
    }
    if (remoteUrl != null && remoteUrl!.trim().isEmpty) {
      throw const ImageMetadataException(
        'blank_remote_url',
        'remoteUrl must not be blank.',
      );
    }
    if (attribution != null && attribution!.trim().isEmpty) {
      throw const ImageMetadataException(
        'blank_attribution',
        'attribution must not be blank.',
      );
    }
    switch (locationType) {
      case ImageLocationType.none:
        if (assetPath != null || remoteUrl != null) {
          throw const ImageMetadataException(
            'none_with_source',
            'locationType none must not declare an assetPath or remoteUrl.',
          );
        }
      case ImageLocationType.asset:
        if (assetPath == null) {
          throw const ImageMetadataException(
            'asset_missing_path',
            'locationType asset requires a non-blank assetPath.',
          );
        }
      case ImageLocationType.network:
        if (remoteUrl == null) {
          throw const ImageMetadataException(
            'network_missing_url',
            'locationType network requires a non-blank remoteUrl.',
          );
        }
        if (assetPath != null) {
          throw const ImageMetadataException(
            'network_with_asset',
            'locationType network must not declare an assetPath; use '
                'asset instead so precedence stays explicit.',
          );
        }
    }
  }

  factory ImageMetadata.fromJson(Map<String, dynamic> json) {
    return ImageMetadata(
      locationType: _locationType(json['locationType']?.toString()),
      assetPath: _nonEmptyString(json['assetPath']),
      remoteUrl: _nonEmptyString(json['remoteUrl']),
      provenance: _provenance(json['provenance']?.toString()),
      attribution: _nonEmptyString(json['attribution']),
      reviewStatus: _reviewStatus(json['reviewStatus']?.toString()),
    );
  }
}

String? _nonEmptyString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

ImageLocationType _locationType(String? value) {
  for (final type in ImageLocationType.values) {
    if (type.name == value) {
      return type;
    }
  }
  return ImageLocationType.none;
}

ImageProvenance _provenance(String? value) {
  for (final provenance in ImageProvenance.values) {
    if (provenance.name == value) {
      return provenance;
    }
  }
  return ImageProvenance.unknown;
}

ImageReviewStatus _reviewStatus(String? value) {
  for (final status in ImageReviewStatus.values) {
    if (status.name == value) {
      return status;
    }
  }
  return ImageReviewStatus.unreviewed;
}
