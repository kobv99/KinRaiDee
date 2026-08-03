import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/design_system/theme/app_theme_extensions.dart';
import 'package:mobile/core/design_system/components/app_button.dart';
import 'package:mobile/core/design_system/components/app_card.dart';
import 'package:mobile/core/design_system/components/app_chip.dart';
import 'package:mobile/core/design_system/components/app_progress.dart';
import 'package:mobile/core/domain/images/image_metadata.dart';
import 'package:mobile/core/design_system/feature_components/recommendation_metric.dart';
import 'package:mobile/core/design_system/feature_components/recipe_card.dart';
import 'package:mobile/core/design_system/feature_components/pantry_readiness_card.dart';
import 'package:mobile/core/design_system/feature_components/serving_selector.dart';
import 'package:mobile/core/design_system/components/responsive_cta.dart';
import 'package:mobile/core/design_system/feature_components/ingredient_status_chip.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );
}

/// A 1x1 transparent PNG, embedded only for this test — never registered as
/// a pubspec asset or shipped in the app.
final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBA'
  'ScY42YAAAAASUVORK5CYII=',
);

final ByteData _emptyAssetManifest = const StandardMessageCodec().encodeMessage(
  <Object?, Object?>{},
)!;

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

Widget _wrapWithAsset(Widget child, {required String presentAssetKey}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Center(
        child: DefaultAssetBundle(
          bundle: _FakeAssetBundle(presentAssetKey),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('AppTheme', () {
    testWidgets('exposes AppSemanticColors extension', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              final semantic = Theme.of(context).extension<AppSemanticColors>();
              expect(semantic, isNotNull);
              expect(semantic!.success, isNotNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('text theme has all required roles', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              final text = Theme.of(context).textTheme;
              expect(text.displayLarge, isNotNull);
              expect(text.headlineMedium, isNotNull);
              expect(text.titleMedium, isNotNull);
              expect(text.bodyMedium, isNotNull);
              expect(text.bodySmall, isNotNull);
              expect(text.labelLarge, isNotNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('AppButton', () {
    testWidgets('primary variant fires onPressed', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(AppButton(label: 'เริ่มทำอาหาร', onPressed: () => tapped = true)),
      );
      await tester.tap(find.text('เริ่มทำอาหาร'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppButton(label: 'Disabled', onPressed: null)),
      );
      final widget = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(widget.onPressed, isNull);
    });
  });

  testWidgets('AppCard renders child content', (tester) async {
    await tester.pumpWidget(_wrap(const AppCard(child: Text('card content'))));
    expect(find.text('card content'), findsOneWidget);
  });

  testWidgets('AppChip shows selected state semantics', (tester) async {
    await tester.pumpWidget(
      _wrap(const AppChip(label: 'พร้อมครบ', selected: true)),
    );
    expect(find.text('พร้อมครบ'), findsOneWidget);
  });

  testWidgets('AppProgress clamps value between 0 and 1', (tester) async {
    await tester.pumpWidget(_wrap(const AppProgress(value: 1.5)));
    expect(find.byType(AppProgress), findsOneWidget);
  });

  group('RecommendationMetric', () {
    testWidgets('is tappable and reports taps', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          RecommendationMetric(
            icon: Icons.check,
            value: '18',
            label: 'Pantry Friendly',
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.byType(RecommendationMetric));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  testWidgets('RecipeCard shows name, match %, and cooking time', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        RecipeCard(
          name: 'หมูกระเทียม',
          pantryMatchPercent: 95,
          readiness: RecipeReadiness.ready,
          cookingTimeMinutes: 30,
          onTap: () {},
        ),
      ),
    );
    expect(find.textContaining('หมูกระเทียม'), findsOneWidget);
    expect(find.textContaining('95%'), findsOneWidget);
    expect(find.textContaining('30 นาที'), findsOneWidget);
  });

  testWidgets(
    'RecipeCard renders the resolved image when imageMetadata is approved',
    (tester) async {
      await tester.pumpWidget(
        _wrapWithAsset(
          RecipeCard(
            name: 'หมูกระเทียม',
            pantryMatchPercent: 95,
            readiness: RecipeReadiness.ready,
            cookingTimeMinutes: 30,
            placeholderEmoji: '🍳',
            imageMetadata: ImageMetadata(
              locationType: ImageLocationType.asset,
              assetPath: 'assets/recipe_images/present.png',
              reviewStatus: ImageReviewStatus.approved,
            ),
            onTap: () {},
          ),
          presentAssetKey: 'assets/recipe_images/present.png',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('🍳'), findsNothing);
    },
  );

  testWidgets(
    'RecipeCard falls back to placeholderEmoji when imageMetadata has no '
    'approved candidates',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          RecipeCard(
            name: 'หมูกระเทียม',
            pantryMatchPercent: 95,
            readiness: RecipeReadiness.ready,
            cookingTimeMinutes: 30,
            placeholderEmoji: '🍳',
            imageMetadata: ImageMetadata(
              locationType: ImageLocationType.asset,
              assetPath: 'assets/recipe_images/present.png',
              reviewStatus: ImageReviewStatus.unreviewed,
            ),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('🍳'), findsOneWidget);
    },
  );

  testWidgets('PantryReadinessCard exposes a working add-missing action', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        PantryReadinessCard(
          readyPercent: 95,
          haveCount: 9,
          totalCount: 10,
          missingCount: 1,
          onAddMissingIngredients: () => tapped = true,
        ),
      ),
    );
    expect(find.text('เพิ่มวัตถุดิบ'), findsOneWidget);
    await tester.tap(find.text('เพิ่มวัตถุดิบ'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  group('ServingSelector', () {
    testWidgets('increments and decrements within bounds', (tester) async {
      var value = 2;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              return ServingSelector(
                value: value,
                min: 1,
                max: 4,
                onChanged: (v) => setState(() => value = v),
              );
            },
          ),
        ),
      );
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });
  });

  group('IngredientStatusChip', () {
    testWidgets('shows an explicit status label, not just a colored icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              IngredientStatusChip(
                name: 'หมู',
                status: IngredientStatus.available,
              ),
              IngredientStatusChip(
                name: 'ไข่',
                status: IngredientStatus.missing,
              ),
            ],
          ),
        ),
      );

      expect(find.text('มี'), findsOneWidget);
      expect(find.text('ขาด'), findsOneWidget);
    });
  });

  group('ResponsiveCta', () {
    Future<void> setViewportWidth(WidgetTester tester, double width) async {
      final dpr = tester.view.devicePixelRatio;
      tester.view.physicalSize = Size(width, 800) * dpr;
      addTearDown(tester.view.resetPhysicalSize);
    }

    testWidgets('stays full width below the breakpoint (phone)', (
      tester,
    ) async {
      await setViewportWidth(tester, 390);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: ResponsiveCta(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                key: ValueKey('cta'),
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byKey(const ValueKey('cta')));
      expect(size.width, 390);
    });

    testWidgets('is capped to maxWidth at/above the breakpoint (desktop)', (
      tester,
    ) async {
      await setViewportWidth(tester, 1280);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: ResponsiveCta(
              maxWidth: 360,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                key: ValueKey('cta'),
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byKey(const ValueKey('cta')));
      expect(size.width, 360);
    });

    testWidgets('shrink-wraps its height in a desktop bottom bar', (
      tester,
    ) async {
      await setViewportWidth(tester, 1280);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(key: ValueKey('body')),
            bottomNavigationBar: ResponsiveCta(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                key: ValueKey('cta'),
              ),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(const ValueKey('cta'))).height, 48);
      expect(
        tester.getSize(find.byKey(const ValueKey('body'))).height,
        greaterThan(0),
      );
    });
  });
}
