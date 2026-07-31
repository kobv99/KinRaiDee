import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/navigation/app_navigation_provider.dart';
import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/responsive_content.dart';
import '../../../../core/design_system/design_tokens/app_colors.dart';
import '../../../../core/design_system/design_tokens/app_spacing.dart';
import '../../../../core/design_system/design_tokens/app_typography.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../application/recipe_missing_shopping_controller.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/services/recipe_serving_calculator.dart';
import '../providers/favorite_recipe_ids_provider.dart';
import '../providers/recipe_shopping_provider.dart';
import '../widgets/recipe_detail_header.dart';
import '../widgets/recipe_ingredient_list.dart';
import 'cooking_wizard_page.dart';

class RecipeDetailPage extends ConsumerStatefulWidget {
  const RecipeDetailPage({super.key, required this.recipe});

  final Recipe recipe;

  @override
  ConsumerState<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends ConsumerState<RecipeDetailPage> {
  late final int _servings;
  bool _isAddingMissing = false;

  @override
  void initState() {
    super.initState();
    _servings = widget.recipe.servings > 0 ? widget.recipe.servings : 1;
  }

  @override
  Widget build(BuildContext context) {
    // Uses the same RecipeServingCalculator the cooking wizard uses (rather
    // than recipeReadinessProvider), which tolerates a not-yet-ready
    // canonical ingredient registry instead of returning null outright —
    // this was a real bug: ingredient names failed to show at all whenever
    // the registry provider hadn't resolved yet.
    final servingPlan = const RecipeServingCalculator().calculate(
      recipe: widget.recipe,
      pantry: ref.watch(pantryProvider),
      servings: _servings,
      registry: ref.watch(canonicalIngredientRegistryProvider),
    );
    final hasMissing = servingPlan.ingredients.any((item) => !item.isEnough);
    final missingInShoppingIds = ref.watch(
      recipeIngredientIdsInShoppingProvider(widget.recipe.id),
    );
    final missingInShoppingCount = servingPlan.ingredients
        .where(
          (item) =>
              !item.isEnough &&
              missingInShoppingIds.contains(
                item.ingredient.canonicalIngredientId,
              ),
        )
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: ResponsiveContent(
          child: ListView(
            children: [
              RecipeDetailHeader(
                recipe: widget.recipe,
                servingPlan: servingPlan,
                onBack: () => Navigator.of(context).maybePop(),
                onAddMissing: hasMissing ? _addMissingIngredients : null,
                isAddingMissing: _isAddingMissing,
                isFavorite: ref
                    .watch(favoriteRecipeIdsProvider)
                    .contains(widget.recipe.id),
                onToggleFavorite: () => ref
                    .read(favoriteRecipeIdsProvider.notifier)
                    .toggle(widget.recipe.id),
                onStartCooking: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => CookingWizardPage(recipe: widget.recipe),
                  ),
                ),
                missingInShoppingCount: missingInShoppingCount,
                onGoToShopping: missingInShoppingCount > 0
                    ? () => ref
                          .read(appNavigationProvider.notifier)
                          .openShopping()
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              RecipeIngredientList(servingPlan: servingPlan),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addMissingIngredients() async {
    if (_isAddingMissing) {
      return;
    }
    final controller = ref.read(recipeMissingShoppingControllerProvider);
    if (controller == null) {
      _showMessage(
        'ยังตรวจ Pantry ไม่สำเร็จ คุณยังเริ่มทำอาหารได้และเพิ่มรายการภายหลังได้',
      );
      return;
    }
    setState(() => _isAddingMissing = true);
    try {
      final result = await controller.addMissingIngredients(
        recipe: widget.recipe,
        servings: _servings,
      );
      if (!mounted) {
        return;
      }
      if (result.outcome == RecipeMissingShoppingOutcome.committed) {
        await _showAddedToShoppingConfirmation();
        return;
      }
      final message = switch (result.outcome) {
        RecipeMissingShoppingOutcome.committed => '',
        RecipeMissingShoppingOutcome.noMissingIngredients =>
          'Pantry พร้อมสำหรับสูตรนี้แล้ว',
        RecipeMissingShoppingOutcome.unchanged =>
          'วัตถุดิบที่แนะนำมีอยู่ใน Shopping แล้ว',
        RecipeMissingShoppingOutcome.notCandidateRecipe =>
          'ยังไม่พบวัตถุดิบหลักของสูตรนี้ใน Pantry คุณยังเริ่มทำอาหารได้และวางแผนซื้อภายหลังได้',
        RecipeMissingShoppingOutcome.failed =>
          'เพิ่มรายการไม่สำเร็จ ข้อมูลเดิมยังคงปลอดภัย',
      };
      _showMessage(message);
    } on Object {
      if (mounted) {
        _showMessage('เพิ่มรายการไม่สำเร็จ ข้อมูลเดิมยังคงปลอดภัย');
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingMissing = false);
      }
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// After missing ingredients are successfully added to Shopping, the
  /// person must be able to jump there directly instead of navigating
  /// there manually. "ทำต่อ" just dismisses and keeps them on Recipe
  /// Detail; "ไปที่ Shopping" switches the main tab (handled by
  /// MainShell), matching the same pattern used by the cooking wizard.
  Future<void> _showAddedToShoppingConfirmation() async {
    final goToShopping = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'เพิ่มวัตถุดิบที่ขาดเข้า Shopping แล้ว',
                style: AppTypography.title,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'ทำต่อ',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      key: const ValueKey<String>(
                        'added-to-shopping-confirmation-go-to-shopping',
                      ),
                      label: 'ไปที่ Shopping',
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (goToShopping == true && mounted) {
      ref.read(appNavigationProvider.notifier).openShopping();
    }
  }
}
