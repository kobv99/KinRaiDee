import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:mobile/app/app.dart';
import 'package:mobile/app/providers/canonical_ingredient_providers.dart';
import 'package:mobile/core/design_system/design_tokens/app_colors.dart';
import 'package:mobile/core/design_system/feature_components/serving_selector.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/core/services/storage_service.dart';
import 'package:mobile/features/pantry/application/canonical_ingredient_migration.dart';
import 'package:mobile/features/pantry/application/inventory_transaction_providers.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/pantry/domain/repositories/inventory_commit_repository.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';
import 'package:mobile/features/recipe/presentation/pages/recipe_detail_page.dart';

/// Reproduces the exact path the person takes on a real device: boot the
/// real app (real bundled recipe/ingredient assets, real Hive-backed
/// pantry, real canonical ingredient registry loaded the same way
/// `main.dart` loads it) rather than a synthetic Recipe object built by
/// hand, then drive the UI from the bottom-nav Recipe tab through "สูตร
/// ทั้งหมด", into a real recipe's Recipe Detail, and into the Cooking
/// Wizard. Product Acceptance reported the wizard body rendering nothing
/// but the bottom CTA under this exact real-data path even though
/// synthetic-data widget tests (cooking_wizard_content_test.dart) pass.
void main() {
  testWidgets(
    'Cooking Wizard renders real recipe/ingredient content for a real '
    'bundled recipe, pushed via the real app shell',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late Directory tempDirectory;
      late Box<dynamic> pantryBox;
      late HiveInventoryCommitRepository inventoryRepository;
      late InventoryRecoveryResult startupRecovery;
      late final unitEngine = UnitConversionEngine.standard();
      late final CanonicalIngredientRegistry registry;

      await tester.runAsync(() async {
        tempDirectory = await Directory.systemTemp.createTemp(
          'kinraidee_real_data_test_',
        );
        Hive.init(tempDirectory.path);
        pantryBox = await Hive.openBox<dynamic>(StorageService.pantryBoxName);
        inventoryRepository = HiveInventoryCommitRepository();
        startupRecovery = await inventoryRepository
            .recoverPendingTransactions();
      });
      addTearDown(() async {
        await pantryBox.close();
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final loadedRegistry = await IngredientCatalog(
        unitConversionEngine: unitEngine,
      ).loadRegistry();
      registry = loadedRegistry;

      CanonicalIngredientMigrationResult? migration;
      if (startupRecovery.allowsMutation) {
        migration =
            CanonicalIngredientMigration(
              registry: registry,
              unitEngine: unitEngine,
            ).migrate(
              pantry: startupRecovery.snapshot.pantry,
              history: startupRecovery.snapshot.history,
            );
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryCommitRepositoryProvider.overrideWithValue(
              inventoryRepository,
            ),
            inventoryStartupRecoveryProvider.overrideWithValue(startupRecovery),
            unitConversionEngineProvider.overrideWithValue(unitEngine),
            canonicalIngredientRegistryProvider.overrideWithValue(registry),
            canonicalIngredientMigrationReportProvider.overrideWithValue(
              migration,
            ),
          ],
          child: const KinRaiDeeApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'app boot');

      // Bottom nav: Recipe tab.
      await tester.tap(find.text('Recipe'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Recipe tab');

      // "สูตรทั้งหมด" -> full unrestricted recipe list, independent of
      // Pantry-based recommendation state (a fresh test pantry has no
      // recommendable hero ingredient, so this is the reliable way to
      // reach a real recipe).
      await tester.tap(
        find.byKey(const ValueKey<String>('browse-all-recipes-button')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'All Recipes list');

      final allRecipeTiles = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('all-recipe-'),
      );
      expect(
        allRecipeTiles,
        findsWidgets,
        reason:
            'bundled recipe assets must have parsed into at least one '
            'recipe for this test to be meaningful',
      );
      final firstRecipeTile = allRecipeTiles.first;

      await tester.tap(firstRecipeTile);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Recipe Detail push');

      final recipe = tester
          .widget<RecipeDetailPage>(find.byType(RecipeDetailPage))
          .recipe;
      final recipeName = recipe.name;
      expect(recipe.ingredients, isNotEmpty, reason: 'real recipe ingredients');
      expect(recipe.steps, isNotEmpty, reason: 'real recipe cooking steps');
      final realIngredientName = recipe.ingredients.first.name;

      // Recipe Detail must show the real recipe name.
      expect(find.text(recipeName), findsWidgets);

      await tester.tap(find.byKey(const ValueKey<String>('start-cooking-cta')));

      for (var elapsed = 0; elapsed <= 320; elapsed += 16) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          tester.takeException(),
          isNull,
          reason: 'no exception at ${elapsed}ms into the wizard push',
        );
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'wizard settled');

      expect(
        find.text(recipeName),
        findsWidgets,
        reason: 'recipe name must render in Serving Selection body',
      );
      expect(
        find.text('สำหรับกี่คน?'),
        findsOneWidget,
        reason: 'serving selector heading must render',
      );
      expect(find.byType(ServingSelector), findsOneWidget);
      expect(find.text('ต่อไป'), findsOneWidget, reason: 'bottom CTA');
      expect(
        find.text('2'),
        findsOneWidget,
        reason: 'default serving count must be visible',
      );
      _expectVisibleWithCta(
        tester,
        body: find.byKey(const ValueKey<String>('wizard-serving-body')),
        reason: 'Serving Selection',
      );

      final plusButton = find.byIcon(Icons.add);
      expect(plusButton, findsOneWidget, reason: 'serving plus button');
      expect(
        plusButton.hitTestable(),
        findsOneWidget,
        reason: 'serving plus button must receive real pointer input',
      );
      await tester.tap(plusButton);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'increment servings');
      expect(
        find.text('3'),
        findsOneWidget,
        reason: 'serving count must change after incrementing',
      );

      await tester.tap(find.text('ต่อไป'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'to review step');

      expect(find.text('ตรวจสอบวัตถุดิบ'), findsOneWidget);
      expect(
        find.textContaining('ความพร้อมจาก Pantry'),
        findsOneWidget,
        reason: 'readiness summary must render',
      );
      expect(
        find.text('วัตถุดิบที่ขาด'),
        findsOneWidget,
        reason:
            'at least one ingredient section (missing) must be visible '
            'for a fresh pantry with no seeded ingredients',
      );
      expect(
        find.text(realIngredientName),
        findsOneWidget,
        reason:
            'a canonical ingredient from the selected real recipe must '
            'render in Ingredient Review',
      );
      _expectVisibleWithCta(
        tester,
        body: find.byKey(const ValueKey<String>('wizard-review-body')),
        reason: 'Ingredient Review',
      );
      _expectInsideWizardViewport(
        tester,
        finder: find.text(realIngredientName),
        reason: 'real ingredient name',
      );

      await tester.tap(find.text('ต่อไป'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'to confirm step');

      expect(find.text('พร้อมทำอาหาร!'), findsOneWidget);
      expect(find.text(recipeName), findsWidgets);
      expect(find.textContaining('สำหรับ 3 คน'), findsOneWidget);
      expect(find.text('เริ่มทำอาหาร'), findsOneWidget);
      _expectVisibleWithCta(
        tester,
        body: find.byKey(const ValueKey<String>('wizard-confirm-body')),
        reason: 'Ready Confirmation',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('wizard-primary-cta')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'start Cooking Mode');
      expect(
        find.text('ขั้นตอนที่ 1 / ${recipe.steps.length}'),
        findsOneWidget,
      );
      expect(find.text(recipe.steps.first), findsOneWidget);
      final cookingScaffold = tester.widget<Scaffold>(
        find.byKey(const ValueKey<String>('wizard-cooking-scaffold')),
      );
      expect(cookingScaffold.backgroundColor, AppColors.cookingBackground);
      _expectInsideWizardViewport(
        tester,
        finder: find.byKey(const ValueKey<String>('wizard-cooking-body')),
        scaffoldKey: 'wizard-cooking-scaffold',
        reason: 'Cooking Mode body',
      );
    },
  );
}

void _expectVisibleWithCta(
  WidgetTester tester, {
  required Finder body,
  required String reason,
}) {
  final cta = find.byKey(const ValueKey<String>('wizard-primary-cta'));
  expect(body, findsOneWidget, reason: '$reason body exists');
  expect(cta, findsOneWidget, reason: '$reason CTA exists');

  final bodyBox = tester.renderObject<RenderBox>(body);
  final ctaBox = tester.renderObject<RenderBox>(cta);
  expect(bodyBox.hasSize, isTrue, reason: '$reason body was laid out');
  expect(ctaBox.hasSize, isTrue, reason: '$reason CTA was laid out');
  expect(bodyBox.size.width, greaterThan(0), reason: '$reason body width');
  expect(bodyBox.size.height, greaterThan(0), reason: '$reason body height');
  expect(ctaBox.size.width, greaterThan(0), reason: '$reason CTA width');
  expect(ctaBox.size.height, greaterThan(0), reason: '$reason CTA height');

  final viewport = tester.getRect(
    find.byKey(const ValueKey<String>('wizard-scaffold')),
  );
  final bodyRect = bodyBox.localToGlobal(Offset.zero) & bodyBox.size;
  final ctaRect = ctaBox.localToGlobal(Offset.zero) & ctaBox.size;
  _expectRectInside(bodyRect, viewport, '$reason body');
  _expectRectInside(ctaRect, viewport, '$reason CTA');
  expect(
    bodyRect.overlaps(ctaRect),
    isFalse,
    reason: '$reason body and CTA must be visible without covering each other',
  );
}

void _expectInsideWizardViewport(
  WidgetTester tester, {
  required Finder finder,
  required String reason,
  String scaffoldKey = 'wizard-scaffold',
}) {
  expect(finder, findsOneWidget, reason: '$reason exists');
  final box = tester.renderObject<RenderBox>(finder);
  expect(box.hasSize, isTrue, reason: '$reason was laid out');
  expect(box.size.width, greaterThan(0), reason: '$reason width');
  expect(box.size.height, greaterThan(0), reason: '$reason height');
  final rect = box.localToGlobal(Offset.zero) & box.size;
  final viewport = tester.getRect(find.byKey(ValueKey<String>(scaffoldKey)));
  _expectRectInside(rect, viewport, reason);
}

void _expectRectInside(Rect rect, Rect viewport, String reason) {
  expect(
    rect.left,
    greaterThanOrEqualTo(viewport.left),
    reason: '$reason left',
  );
  expect(rect.top, greaterThanOrEqualTo(viewport.top), reason: '$reason top');
  expect(
    rect.right,
    lessThanOrEqualTo(viewport.right),
    reason: '$reason right',
  );
  expect(
    rect.bottom,
    lessThanOrEqualTo(viewport.bottom),
    reason: '$reason bottom',
  );
}
