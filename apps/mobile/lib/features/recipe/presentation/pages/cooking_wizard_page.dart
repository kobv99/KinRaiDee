import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/app_icon_button.dart';
import '../../../../core/design_system/design_tokens/app_colors.dart';
import '../../../../core/design_system/design_tokens/app_spacing.dart';
import '../../../../core/design_system/design_tokens/app_typography.dart';
import '../../../../core/design_system/feature_components/cooking_step_card.dart';
import '../../../../core/design_system/feature_components/pantry_readiness_card.dart';
import '../../../../core/design_system/feature_components/serving_selector.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/services/pantry_deduction_planner.dart';
import '../../domain/services/recipe_serving_calculator.dart';
import 'recipe_detail_legacy.dart' show DeductionConfirmationSheet, DeductionSelection;

enum _WizardPhase { serving, review, confirm, cooking }

/// New Sprint 5.5 cooking flow: a full-screen step-by-step wizard matching
/// the design mockup, instead of the single scrolling page with an inline
/// checklist.
///
/// IMPORTANT: the actual Pantry-deduction logic (building the deduction
/// plan, letting the person confirm exactly what gets deducted, committing
/// the transaction, and offering undo) is copied verbatim from
/// `recipe_detail_legacy.dart`'s `_finishCooking` — this file only changes
/// how the person gets to that point. Nothing about inventory correctness
/// was rewritten.
class CookingWizardPage extends ConsumerStatefulWidget {
  const CookingWizardPage({super.key, required this.recipe});

  final Recipe recipe;

  @override
  ConsumerState<CookingWizardPage> createState() => _CookingWizardPageState();
}

class _CookingWizardPageState extends ConsumerState<CookingWizardPage> {
  late int _servings;
  _WizardPhase _phase = _WizardPhase.serving;
  int _cookingStepIndex = 0;
  bool _isFinishing = false;

  @override
  void initState() {
    super.initState();
    final base = widget.recipe.servings > 0 ? widget.recipe.servings : 2;
    _servings = base.clamp(1, 12);
  }

  @override
  Widget build(BuildContext context) {
    final pantry = ref.watch(pantryProvider);
    final registry = ref.watch(canonicalIngredientRegistryProvider);
    final servingPlan = const RecipeServingCalculator().calculate(
      recipe: widget.recipe,
      pantry: pantry,
      servings: _servings,
      registry: registry,
    );

    if (_phase == _WizardPhase.cooking) {
      return _buildCookingMode(context, servingPlan);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: AppIconButton(
          icon: Icons.arrow_back,
          semanticLabel: 'ย้อนกลับ',
          onPressed: () {
            if (_phase == _WizardPhase.serving) {
              Navigator.of(context).pop();
            } else {
              setState(() => _phase = _previousPhase(_phase));
            }
          },
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(_phaseLabel(_phase), style: AppTypography.title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: switch (_phase) {
            _WizardPhase.serving => _ServingStep(
                recipe: widget.recipe,
                servings: _servings,
                onChanged: (value) => setState(() => _servings = value),
              ),
            _WizardPhase.review => _ReviewStep(servingPlan: servingPlan),
            _WizardPhase.confirm => _ConfirmStep(servingPlan: servingPlan),
            _WizardPhase.cooking => const SizedBox.shrink(), // handled above
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: AppButton(
          label: _phase == _WizardPhase.confirm ? 'เริ่มทำอาหาร' : 'ต่อไป',
          onPressed: () => setState(() => _phase = _nextPhase(_phase)),
        ),
      ),
    );
  }

  Widget _buildCookingMode(BuildContext context, RecipeServingPlan servingPlan) {
    final steps = widget.recipe.steps;
    final totalSteps = steps.isEmpty ? 1 : steps.length;
    final isLastStep = _cookingStepIndex >= totalSteps - 1;

    return Scaffold(
      backgroundColor: AppColors.cookingBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppIconButton(
                    icon: Icons.close,
                    semanticLabel: 'ปิดโหมดทำอาหาร',
                    background: AppColors.cookingSurface,
                    foreground: AppColors.cookingTextPrimary,
                    onPressed: () => _confirmExitCookingMode(context),
                  ),
                  const Icon(Icons.timer_outlined, color: AppColors.cookingTextSecondary),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: CookingStepCard(
                  stepIndex: _cookingStepIndex + 1,
                  totalSteps: totalSteps,
                  instruction: steps.isEmpty
                      ? 'สูตรนี้ยังไม่มีขั้นตอนโดยละเอียด — ทำตามส่วนผสมที่เตรียมไว้ได้เลย'
                      : steps[_cookingStepIndex],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: _isFinishing
                  ? const SizedBox(
                      height: 56,
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  : CookingNavigationBar(
                      previousLabel: 'ย้อนกลับ',
                      nextLabel: isLastStep ? 'เสร็จแล้ว' : 'ถัดไป',
                      onPrevious: _cookingStepIndex > 0
                          ? () => setState(() => _cookingStepIndex--)
                          : null,
                      onNext: () {
                        if (isLastStep) {
                          _finishCooking(servingPlan);
                        } else {
                          setState(() => _cookingStepIndex++);
                        }
                      },
                    ),
            ),
            if (!_isFinishing)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(totalSteps, (index) {
                    final isCurrent = index == _cookingStepIndex;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isCurrent ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppColors.primary
                            : AppColors.cookingTextSecondary.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmExitCookingMode(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ออกจากโหมดทำอาหาร?'),
        content: const Text('ความคืบหน้าขั้นตอนจะไม่ถูกบันทึก ยังไม่มีการหักวัตถุดิบใดๆ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ทำต่อ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ออก'),
          ),
        ],
      ),
    );
    if (shouldExit == true && mounted) {
      setState(() {
        _phase = _WizardPhase.confirm;
        _cookingStepIndex = 0;
      });
    }
  }

  // -------------------------------------------------------------------
  // Below this line: copied logic from recipe_detail_legacy.dart's
  // `_finishCooking` / `_undoTransaction`, unchanged. This is the part
  // that actually deducts Pantry quantities — deliberately not
  // rewritten so the tested behavior is preserved exactly.
  // -------------------------------------------------------------------
  Future<void> _finishCooking(RecipeServingPlan servingPlan) async {
    if (_isFinishing) return;

    final pantry = ref.read(pantryProvider);
    final planner = const PantryDeductionPlanner();
    final deductionPlan = planner.build(
      servingPlan: servingPlan,
      pantry: pantry,
      registry: ref.read(canonicalIngredientRegistryProvider),
    );

    if (!deductionPlan.canDeduct) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('ทำอาหารเสร็จแล้ว 🎉'),
          content: const Text(
            'ไม่พบวัตถุดิบที่ระบบสามารถหักได้อัตโนมัติ เครื่องปรุงและรายการที่หน่วยไม่ตรงจะไม่ถูกเปลี่ยนแปลง',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('รับทราบ'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final selection = await showModalBottomSheet<DeductionSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DeductionConfirmationSheet(plan: deductionPlan),
    );
    if (selection == null || !mounted) return;

    setState(() => _isFinishing = true);

    try {
      final transaction = planner.createTransaction(
        plan: deductionPlan,
        selectedLineKeys: selection.selectedLineKeys,
        quantitiesByLineKey: selection.quantitiesByLineKey,
      );

      if (!transaction.hasChanges) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่มีวัตถุดิบที่เลือกให้หักออกจาก Pantry')),
        );
        return;
      }

      final committedTransaction = await ref
          .read(pantryProvider.notifier)
          .applyQuantityTransaction(transaction);
      if (!mounted) return;

      Navigator.of(context).pop();

      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'ทำอาหารเสร็จแล้ว และหักวัตถุดิบ ${committedTransaction.changedIngredientCount} รายการ',
          ),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'ย้อนกลับ',
            onPressed: () async {
              final restored = await ref
                  .read(pantryProvider.notifier)
                  .undoQuantityTransaction(committedTransaction);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    restored > 0
                        ? 'คืนวัตถุดิบ $restored รายการกลับเข้า Pantry แล้ว'
                        : 'ย้อนกลับไม่ได้ เพราะปริมาณวัตถุดิบถูกแก้ไขหลังจากนั้น',
                  ),
                ),
              );
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isFinishing = false);
    }
  }
}

_WizardPhase _nextPhase(_WizardPhase phase) => switch (phase) {
      _WizardPhase.serving => _WizardPhase.review,
      _WizardPhase.review => _WizardPhase.confirm,
      _WizardPhase.confirm => _WizardPhase.cooking,
      _WizardPhase.cooking => _WizardPhase.cooking,
    };

_WizardPhase _previousPhase(_WizardPhase phase) => switch (phase) {
      _WizardPhase.serving => _WizardPhase.serving,
      _WizardPhase.review => _WizardPhase.serving,
      _WizardPhase.confirm => _WizardPhase.review,
      _WizardPhase.cooking => _WizardPhase.confirm,
    };

String _phaseLabel(_WizardPhase phase) => switch (phase) {
      _WizardPhase.serving => 'เลือกจำนวนคน',
      _WizardPhase.review => 'ตรวจสอบวัตถุดิบ',
      _WizardPhase.confirm => 'พร้อมทำอาหาร',
      _WizardPhase.cooking => 'โหมดทำอาหาร',
    };

class _ServingStep extends StatelessWidget {
  const _ServingStep({
    required this.recipe,
    required this.servings,
    required this.onChanged,
  });

  final Recipe recipe;
  final int servings;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xxl),
        AppCard(
          child: Row(
            children: [
              Text(recipe.emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.name, style: AppTypography.title),
                    Text(
                      '${recipe.cookTimeMinutes} นาที · ${recipe.difficulty}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.giant),
        Text('สำหรับกี่คน?', style: AppTypography.title, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        ServingSelector(value: servings, onChanged: onChanged),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.servingPlan});

  final RecipeServingPlan servingPlan;

  @override
  Widget build(BuildContext context) {
    final total = servingPlan.ingredients.length;
    final haveCount = servingPlan.enoughCount;
    final missing = servingPlan.ingredients.where((item) => !item.isEnough).toList(growable: false);
    final readyPercent = total == 0 ? 100 : ((haveCount / total) * 100).round();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PantryReadinessCard(
            readyPercent: readyPercent,
            haveCount: haveCount,
            totalCount: total,
            missingCount: missing.length,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('มีครบแล้ว', style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          for (final item in servingPlan.ingredients.where((i) => i.isEnough))
            _ChecklistRow(label: item.ingredient.name, checked: true),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('วัตถุดิบที่ขาด', style: AppTypography.label),
            const SizedBox(height: AppSpacing.sm),
            for (final item in missing)
              _ChecklistRow(label: item.ingredient.name, checked: false),
          ],
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label, required this.checked});
  final String label;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: checked ? AppColors.success : AppColors.textDisabled,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTypography.body.copyWith(
              color: checked ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({required this.servingPlan});

  final RecipeServingPlan servingPlan;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🍳', style: TextStyle(fontSize: 56)),
        const SizedBox(height: AppSpacing.lg),
        Text('คุณพร้อมทำ', style: AppTypography.body, textAlign: TextAlign.center),
        Text(
          servingPlan.recipe.name,
          style: AppTypography.headline,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'สำหรับ ${servingPlan.servings} คน · ใช้เวลาโดยประมาณ ${servingPlan.recipe.cookTimeMinutes} นาที',
          style: AppTypography.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
