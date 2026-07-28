import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/recipe_missing_shopping_controller.dart';
import '../../domain/entities/recipe.dart';
import '../providers/recipe_provider.dart';
import '../providers/recipe_shopping_provider.dart';
import '../widgets/recipe_readiness_panel.dart';
import 'recipe_detail_legacy.dart' as legacy;

class RecipeDetailPage extends ConsumerStatefulWidget {
  const RecipeDetailPage({super.key, required this.recipe});

  final Recipe recipe;

  @override
  ConsumerState<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends ConsumerState<RecipeDetailPage> {
  late final int _servings;
  bool _expanded = true;
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
    final panelTop = MediaQuery.paddingOf(context).top + kToolbarHeight + 8;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: legacy.RecipeDetailPage(recipe: widget.recipe),
          ),
          Positioned(
            top: panelTop,
            left: 12,
            right: 12,
            child: RecipeReadinessPanel(
              readiness: readiness,
              expanded: _expanded,
              isAddingMissing: _isAddingMissing,
              onToggle: () => setState(() => _expanded = !_expanded),
              onAddMissing:
                  readiness == null || readiness.missingIngredients.isEmpty
                  ? null
                  : _addMissingIngredients,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addMissingIngredients() async {
    if (_isAddingMissing) {
      return;
    }
    final controller = ref.read(recipeMissingShoppingControllerProvider);
    if (controller == null) {
      _showMessage('ข้อมูล Pantry ยังไม่พร้อม กรุณาลองอีกครั้ง');
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
          'วัตถุดิบใน Pantry เพียงพอสำหรับสูตรนี้แล้ว',
        RecipeMissingShoppingOutcome.unchanged =>
          'วัตถุดิบที่ขาดอยู่ใน Shopping แล้ว',
        RecipeMissingShoppingOutcome.notCandidateRecipe =>
          'สูตรนี้ยังไม่สัมพันธ์กับวัตถุดิบหลักใน Pantry จึงยังสร้าง Shopping ไม่ได้',
        RecipeMissingShoppingOutcome.failed =>
          'เพิ่มรายการไม่ได้ ข้อมูลเดิมไม่ถูกเปลี่ยนแปลง',
      };
      _showMessage(message);
    } on Object {
      if (mounted) {
        _showMessage('เพิ่มรายการไม่ได้ ข้อมูลเดิมไม่ถูกเปลี่ยนแปลง');
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
