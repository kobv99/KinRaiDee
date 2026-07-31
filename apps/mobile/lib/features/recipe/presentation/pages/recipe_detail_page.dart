import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/responsive_content.dart';
import '../../../../core/design_system/design_tokens/app_colors.dart';
import '../../application/recipe_missing_shopping_controller.dart';
import '../../domain/entities/recipe.dart';
import '../providers/recipe_provider.dart';
import '../providers/recipe_shopping_provider.dart';
import '../widgets/recipe_detail_header.dart';
import 'cooking_wizard_page.dart';
import 'recipe_detail_legacy.dart' as legacy;

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
    final readiness = ref.watch(
      recipeReadinessProvider(
        RecipeReadinessRequest(recipe: widget.recipe, servings: _servings),
      ),
    );
    final theme = Theme.of(context);
    final isNarrow = MediaQuery.sizeOf(context).width <= 360;
    final embeddedTheme = theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(toolbarHeight: 0),
      textTheme: isNarrow
          ? theme.textTheme.copyWith(
              bodySmall: theme.textTheme.bodySmall?.copyWith(fontSize: 9.5),
            )
          : theme.textTheme,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: ResponsiveContent(
          child: Column(
            children: [
              RecipeDetailHeader(
                recipe: widget.recipe,
                readiness: readiness,
                onBack: () => Navigator.of(context).maybePop(),
                onAddMissing:
                    readiness == null || readiness.missingIngredients.isEmpty
                    ? null
                    : _addMissingIngredients,
                onStartCooking: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => CookingWizardPage(recipe: widget.recipe),
                  ),
                ),
              ),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: Theme(
                    data: embeddedTheme,
                    child: legacy.RecipeDetailPage(recipe: widget.recipe),
                  ),
                ),
              ),
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
