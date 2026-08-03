import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/design_system/components/resolved_image.dart';
import 'package:mobile/core/domain/images/image_fallback_resolver.dart';
import 'package:mobile/core/domain/images/image_metadata.dart';

/// A 1x1 transparent PNG, embedded only for this test — never registered as
/// a pubspec asset or shipped in the app.
final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBA'
  'ScY42YAAAAASUVORK5CYII=',
);

/// `Image.asset` looks up `AssetManifest.bin` for resolution-aware variants
/// before loading the asset itself; an empty manifest lets it fall back to
/// loading the exact requested key.
final ByteData _emptyAssetManifest = const StandardMessageCodec().encodeMessage(
  <Object?, Object?>{},
)!;

/// Serves [_onePixelPng] for one specific key and throws for everything
/// else, simulating a present asset versus a missing one without touching
/// the real asset bundle or pubspec.yaml.
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
      child: child,
    ),
  );
}

void main() {
  group('ResolvedImage', () {
    testWidgets('renders the fallback glyph when there are no candidates', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ResolvedImage(
            resolution: ImageResolution(candidates: [], fallbackGlyph: '🍜'),
            semanticLabel: 'test image',
          ),
        ),
      );

      expect(find.text('🍜'), findsOneWidget);
    });

    testWidgets('local asset takes precedence over remote when it loads', (
      tester,
    ) async {
      const key = ValueKey<String>('resolved-image');
      await tester.pumpWidget(
        _wrap(
          ResolvedImage(
            resolution: const ImageResolution(
              candidates: [
                ImageCandidate(
                  ImageLocationType.asset,
                  'assets/images/present.png',
                ),
                ImageCandidate(
                  ImageLocationType.network,
                  'https://example.invalid/does-not-exist.png',
                ),
              ],
              fallbackGlyph: '🍜',
            ),
            semanticLabel: 'test image',
            loadedKey: key,
          ),
          presentAssetKey: 'assets/images/present.png',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(key), findsOneWidget);
      expect(find.text('🍜'), findsNothing);
    });

    testWidgets('a broken/missing asset advances to the remote candidate', (
      tester,
    ) async {
      const exhaustedKey = ValueKey<String>('resolved-image-fallback');
      await tester.pumpWidget(
        _wrap(
          const ResolvedImage(
            resolution: ImageResolution(
              candidates: [
                ImageCandidate(
                  ImageLocationType.asset,
                  'assets/images/does-not-exist.png',
                ),
                ImageCandidate(
                  ImageLocationType.network,
                  'https://example.invalid/does-not-exist.png',
                ),
              ],
              fallbackGlyph: '🍜',
            ),
            semanticLabel: 'test image',
            exhaustedFallbackKey: exhaustedKey,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both the missing asset and the unreachable remote host fail, so
      // the chain is fully exhausted and the keyed fallback renders.
      expect(find.byKey(exhaustedKey), findsOneWidget);
      expect(find.text('🍜'), findsOneWidget);
    });

    testWidgets('a failed remote candidate advances to the fallback glyph', (
      tester,
    ) async {
      const exhaustedKey = ValueKey<String>('resolved-image-fallback');
      await tester.pumpWidget(
        _wrap(
          const ResolvedImage(
            resolution: ImageResolution(
              candidates: [
                ImageCandidate(
                  ImageLocationType.network,
                  'https://example.invalid/does-not-exist.png',
                ),
              ],
              fallbackGlyph: '🌶️',
            ),
            semanticLabel: 'test image',
            exhaustedFallbackKey: exhaustedKey,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(exhaustedKey), findsOneWidget);
      expect(find.text('🌶️'), findsOneWidget);
    });

    testWidgets('exposes the semantic label', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _wrap(
          const ResolvedImage(
            resolution: ImageResolution(candidates: [], fallbackGlyph: '🍜'),
            semanticLabel: 'รูปภาพเมนูผัดไทย',
          ),
        ),
      );

      expect(find.bySemanticsLabel('รูปภาพเมนูผัดไทย'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('lays out without overflow at a compact mobile width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          Row(
            children: const [
              SizedBox(
                width: 40,
                child: ResolvedImage(
                  resolution: ImageResolution(
                    candidates: [],
                    fallbackGlyph: '🍜',
                  ),
                  semanticLabel: 'test image',
                  size: 56,
                ),
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
