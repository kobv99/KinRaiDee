import 'package:flutter/material.dart';

import '../../domain/images/image_fallback_resolver.dart';
import '../../domain/images/image_metadata.dart';
import '../design_tokens/app_colors.dart';

/// Renders the first working candidate in an [ImageResolution]'s ordered
/// chain — local asset, then remote network — advancing to the next
/// candidate on any runtime load failure, and finally rendering a glyph
/// fallback when the chain is empty or every candidate has failed.
///
/// This is the single place candidate fallthrough and fallback rendering
/// happen. Feature widgets resolve an [ImageResolution] via
/// `resolveImageCandidates` and hand it here rather than reimplementing
/// loading/error handling themselves.
class ResolvedImage extends StatelessWidget {
  const ResolvedImage({
    required this.resolution,
    required this.semanticLabel,
    super.key,
    this.size = 56,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.loadedKey,
    this.exhaustedFallbackKey,
  });

  final ImageResolution resolution;
  final String semanticLabel;

  /// Square footprint used when [width]/[height] are omitted, and always the
  /// reference size for the fallback glyph's font scale regardless of the
  /// actual rendered footprint.
  final double size;

  /// Optional non-square footprint override (e.g. a full-width hero banner).
  /// Falls back to [size] when null, preserving the original square-only
  /// behavior for every existing caller.
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  /// Applied to whichever candidate widget is currently being attempted.
  final Key? loadedKey;

  /// Applied to the fallback glyph only when it is reached after the
  /// candidate chain started non-empty and was exhausted by runtime
  /// failures — distinct from the fallback shown when there was never a
  /// candidate to try in the first place (which stays keyless).
  final Key? exhaustedFallbackKey;

  @override
  Widget build(BuildContext context) {
    final resolvedWidth = width ?? size;
    final resolvedHeight = height ?? size;
    return Semantics(
      image: true,
      container: true,
      excludeSemantics: true,
      label: semanticLabel,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          width: resolvedWidth,
          height: resolvedHeight,
          child: _CandidateChain(
            candidates: resolution.candidates,
            fallbackGlyph: resolution.fallbackGlyph,
            width: resolvedWidth,
            height: resolvedHeight,
            glyphSize: size,
            isPrimary: true,
            loadedKey: loadedKey,
            fallbackKey: resolution.candidates.isEmpty
                ? null
                : exhaustedFallbackKey,
          ),
        ),
      ),
    );
  }
}

class _CandidateChain extends StatelessWidget {
  const _CandidateChain({
    required this.candidates,
    required this.fallbackGlyph,
    required this.width,
    required this.height,
    required this.glyphSize,
    required this.isPrimary,
    this.loadedKey,
    this.fallbackKey,
  });

  final List<ImageCandidate> candidates;
  final String fallbackGlyph;
  final double width;
  final double height;

  /// Reference size for the fallback glyph's font scale — independent of
  /// [width]/[height] so a wide rectangular hero doesn't render an
  /// oversized glyph on the rare runtime-failure fallback path.
  final double glyphSize;

  /// True only for the first candidate attempt. [loadedKey] is applied
  /// only when this is true, so a retried candidate never ends up mounted
  /// with the same key as the original attempt it replaced.
  final bool isPrimary;
  final Key? loadedKey;
  final Key? fallbackKey;

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) {
      return _FallbackGlyph(
        key: fallbackKey,
        glyph: fallbackGlyph,
        size: glyphSize,
      );
    }

    final candidate = candidates.first;
    final remaining = candidates.skip(1).toList(growable: false);
    final key = isPrimary ? loadedKey : null;

    Widget onError(BuildContext context, Object error, StackTrace? stackTrace) {
      return _CandidateChain(
        candidates: remaining,
        fallbackGlyph: fallbackGlyph,
        width: width,
        height: height,
        glyphSize: glyphSize,
        isPrimary: false,
        loadedKey: loadedKey,
        fallbackKey: fallbackKey,
      );
    }

    if (candidate.locationType == ImageLocationType.asset) {
      return Image.asset(
        candidate.path,
        key: key,
        fit: BoxFit.cover,
        width: width,
        height: height,
        errorBuilder: onError,
      );
    }

    return Image.network(
      candidate.path,
      key: key,
      fit: BoxFit.cover,
      width: width,
      height: height,
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }
        return _FallbackGlyph(glyph: fallbackGlyph, size: glyphSize);
      },
      errorBuilder: onError,
    );
  }
}

class _FallbackGlyph extends StatelessWidget {
  const _FallbackGlyph({required this.glyph, required this.size, super.key});

  final String glyph;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primarySoft,
      child: Center(
        child: Text(glyph, style: TextStyle(fontSize: size * 0.5)),
      ),
    );
  }
}
