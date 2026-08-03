import 'image_metadata.dart';

/// One candidate in an [ImageResolution]'s ordered chain. Always
/// [ImageLocationType.asset] or [ImageLocationType.network] — never
/// [ImageLocationType.none], since a candidate always names an actual
/// source to attempt.
class ImageCandidate {
  const ImageCandidate(this.locationType, this.path)
    : assert(
        locationType != ImageLocationType.none,
        'ImageCandidate must not use ImageLocationType.none.',
      );

  final ImageLocationType locationType;
  final String path;
}

/// The deterministic output of [resolveImageCandidates]: an ordered list of
/// sources to try, and the glyph to render once the list is empty or every
/// candidate has failed at runtime. This resolver is pure domain logic — it
/// has no way to know whether an asset is actually missing or a network
/// request actually fails; that is the rendering widget's job.
class ImageResolution {
  const ImageResolution({required this.candidates, required this.fallbackGlyph});

  final List<ImageCandidate> candidates;
  final String fallbackGlyph;
}

/// The single deterministic fallback policy shared by every image consumer
/// (recipes, canonical ingredients, and — by extension — canonical
/// ingredient family/category nodes, since those are `CanonicalIngredient`
/// records too).
///
/// Only [ImageReviewStatus.approved] metadata may produce a candidate.
/// [ImageReviewStatus.unreviewed] and [ImageReviewStatus.rejected] both
/// resolve to zero candidates — production rendering never shows an image
/// that hasn't been explicitly approved. A future preview/admin surface may
/// relax this separately; that is out of scope here.
ImageResolution resolveImageCandidates({
  required ImageMetadata? metadata,
  required String fallbackGlyph,
}) {
  if (metadata == null || metadata.reviewStatus != ImageReviewStatus.approved) {
    return ImageResolution(
      candidates: const <ImageCandidate>[],
      fallbackGlyph: fallbackGlyph,
    );
  }

  final candidates = <ImageCandidate>[
    if (metadata.assetPath != null)
      ImageCandidate(ImageLocationType.asset, metadata.assetPath!),
    if (metadata.remoteUrl != null)
      ImageCandidate(ImageLocationType.network, metadata.remoteUrl!),
  ];

  return ImageResolution(candidates: candidates, fallbackGlyph: fallbackGlyph);
}
