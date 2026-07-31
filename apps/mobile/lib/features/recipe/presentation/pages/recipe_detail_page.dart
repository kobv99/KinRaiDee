import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../core/design_system/components/responsive_content.dart';
import '../../../../core/design_system/design_tokens/app_colors.dart';
import '../../../../core/design_system/design_tokens/app_spacing.dart';
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
                isFavorite: ref.watch(favoriteRecipeIdsProvider).contains(widget.recipe.id),
                onToggleFavorite: () =>
                    ref.read(favoriteRecipeIdsProvider.notifier).toggle(widget.recipe.id),
                onStartCooking: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => CookingWizardPage(recipe: widget.recipe),
                  ),
                ),
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
      final message = switch (result.outcome) {
        RecipeMissingShoppingOutcome.committed =>
          'เพิ่มวัตถุดิบที่ขาด ${result.changedItemCount} รายการไป Shopping แล้ว',
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
}
