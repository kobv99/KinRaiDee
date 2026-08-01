import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/navigation/app_navigation_provider.dart';
import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/app_icon_button.dart';
import '../../../../core/design_system/components/responsive_content.dart';
import '../../../../core/design_system/components/responsive_cta.dart';
import '../../../../core/design_system/design_tokens/app_colors.dart';
import '../../../../core/design_system/design_tokens/app_radius.dart';
import '../../../../core/design_system/design_tokens/app_spacing.dart';
import '../../../../core/design_system/design_tokens/app_typography.dart';
import '../../../../core/design_system/feature_components/cooking_step_card.dart';
import '../../../../core/design_system/feature_components/ingredient_status_chip.dart';
import '../../../../core/design_system/feature_components/pantry_readiness_card.dart';
import '../../../../core/design_system/feature_components/serving_selector.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../profile/presentation/providers/default_servings_provider.dart';
import '../../../shopping/application/shopping_providers.dart';
import '../../application/recipe_missing_shopping_controller.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/recipe_ingredient.dart';
import '../../domain/services/pantry_deduction_planner.dart';
import '../../domain/services/recipe_serving_calculator.dart';
import '../providers/recipe_shopping_provider.dart';
import '../recipe_difficulty_label.dart';
import 'recipe_detail_legacy.dart'
    show DeductionConfirmationSheet, DeductionSelection;

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
  bool _isAddingMissing = false;

  @override
  void initState() {
    super.initState();
    final preferredDefault = ref.read(defaultServingsProvider);
    final base =
        preferredDefault ??
        (widget.recipe.servings > 0 ? widget.recipe.servings : 2);
    _servings = base.clamp(1, 12);
  }

  @override
  Widget build(BuildContext context) {
    // Everything below depends on this computation succeeding. If it ever
    // throws (bad recipe data, a unit-conversion edge case, anything
    // unanticipated), the wizard must show an explicit error state with
    // working Retry/Exit actions instead of leaving a blank body behind a
    // still-enabled Continue button — see the Round 4 "blank screen" fix.
    RecipeServingPlan? servingPlan;
    Object? computeError;
    try {
      final pantry = ref.watch(pantryProvider);
      final registry = ref.watch(canonicalIngredientRegistryProvider);
      servingPlan = const RecipeServingCalculator().calculate(
        recipe: widget.recipe,
        pantry: pantry,
        servings: _servings,
        registry: registry,
      );
    } on Object catch (error, stackTrace) {
      computeError = error;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'cooking_wizard_page',
          context: ErrorDescription(
            'building the serving plan for recipe ${widget.recipe.id}',
          ),
        ),
      );
    }

    if (computeError != null || servingPlan == null) {
      return WizardErrorScaffold(
        phaseLabel: _phaseLabel(_phase),
        onRetry: () => setState(() {}),
        onExit: () => Navigator.of(context).pop(),
      );
    }

    if (_phase == _WizardPhase.cooking) {
      return _buildCookingMode(context, servingPlan);
    }

    final missingInShoppingCount = _missingInShoppingCount(servingPlan);

    return PopScope(
      canPop: _phase == _WizardPhase.serving,
      onPopInvokedWithResult: (didPop, _) {
        // System/hardware back must mean the same thing as the AppBar back
        // arrow (previous wizard step), not an unconditional pop — only
        // the serving step (nothing to step back to) allows a real pop.
        if (!didPop) {
          setState(() => _phase = _previousPhase(_phase));
        }
      },
      child: Scaffold(
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
          actions: [
            TextButton(
              key: const ValueKey<String>('wizard-exit-action'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ออก'),
            ),
          ],
        ),
        body: SafeArea(
          child: ResponsiveContent(
            maxWidth: 560,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: switch (_phase) {
                _WizardPhase.serving => _ServingStep(
                  recipe: widget.recipe,
                  servings: _servings,
                  onChanged: (value) => setState(() => _servings = value),
                ),
                _WizardPhase.review => _ReviewStep(
                  servingPlan: servingPlan,
                  isAddingMissing: _isAddingMissing,
                  missingInShoppingCount: missingInShoppingCount,
                  onAddMissing: _addMissingIngredients,
                  onGoToShopping: missingInShoppingCount > 0
                      ? () => ref
                            .read(appNavigationProvider.notifier)
                            .openShopping()
                      : null,
                ),
                _WizardPhase.confirm => _ConfirmStep(servingPlan: servingPlan),
                _WizardPhase.cooking =>
                  const SizedBox.shrink(), // handled above
              },
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Align(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ResponsiveCta(
                alignment: Alignment.center,
                child: AppButton(
                  label: _phase == _WizardPhase.confirm
                      ? 'เริ่มทำอาหาร'
                      : 'ต่อไป',
                  onPressed: () => setState(() => _phase = _nextPhase(_phase)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCookingMode(
    BuildContext context,
    RecipeServingPlan servingPlan,
  ) {
    final steps = widget.recipe.steps;
    final totalSteps = steps.isEmpty ? 1 : steps.length;
    final isLastStep = _cookingStepIndex >= totalSteps - 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _confirmExitCookingMode(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.cookingBackground,
        body: SafeArea(
          child: ResponsiveContent(
            maxWidth: 560,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      AppIconButton(
                        icon: Icons.close,
                        semanticLabel: 'ปิดโหมดทำอาหาร',
                        background: AppColors.cookingSurface,
                        foreground: AppColors.cookingTextPrimary,
                        onPressed: () => _confirmExitCookingMode(context),
                      ),
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
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
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
                                : AppColors.cookingTextSecondary.withValues(
                                    alpha: 0.4,
                                  ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmExitCookingMode(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ออกจากโหมดทำอาหาร?'),
        content: const Text(
          'ความคืบหน้าขั้นตอนจะไม่ถูกบันทึก ยังไม่มีการหักวัตถุดิบใดๆ',
        ),
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

  /// Missing ingredients already sent to Shopping for this recipe, so the
  /// Ingredient Review step can mark them instead of offering to add them
  /// again — reactive, so it updates immediately after a successful add or
  /// after returning from Shopping.
  ///
  /// Computed from the already-watched [shoppingListsProvider] via a plain
  /// function rather than a `Provider.family` keyed on the recipe id: this
  /// page and `RecipeDetailPage` underneath it (the wizard is pushed on
  /// top, not instead of it) both need this set for the same recipe at the
  /// same time, and a shared family instance would mean two independently
  /// paused/resumed widget subscriptions to it across the same Navigator
  /// transition — see recipe_shopping_provider.dart for the full reasoning.
  int _missingInShoppingCount(RecipeServingPlan servingPlan) {
    final lists = ref.watch(shoppingListsProvider).value ?? const [];
    final idsInShopping = recipeIngredientIdsInShopping(
      lists,
      widget.recipe.id,
    );
    return servingPlan.ingredients
        .where(
          (item) =>
              !item.isEnough &&
              idsInShopping.contains(item.ingredient.canonicalIngredientId),
        )
        .length;
  }

  Future<void> _addMissingIngredients() async {
    if (_isAddingMissing) return;
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
      if (!mounted) return;
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
      if (mounted) _showMessage('เพิ่มรายการไม่สำเร็จ ข้อมูลเดิมยังคงปลอดภัย');
    } finally {
      if (mounted) setState(() => _isAddingMissing = false);
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// After missing ingredients are successfully added to Shopping, the
  /// person must be able to jump there directly instead of backing out
  /// through wizard steps first. "ทำต่อ" just dismisses and keeps them on
  /// the current wizard step; "ไปที่ Shopping" switches the main tab and
  /// unwinds this whole pushed route stack (handled by MainShell).
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
          const SnackBar(
            content: Text('ไม่มีวัตถุดิบที่เลือกให้หักออกจาก Pantry'),
          ),
        );
        return;
      }

      final committedTransaction = await ref
          .read(pantryProvider.notifier)
          .applyQuantityTransaction(transaction);
      if (!mounted) return;

      // Capture stable references BEFORE popping this route. Once popped,
      // this widget disposes and `ref`/`context` become unsafe to use --
      // the undo action below runs later, from the SnackBar, after that
      // has already happened.
      final pantryNotifier = ref.read(pantryProvider.notifier);
      final messenger = ScaffoldMessenger.of(context);

      Navigator.of(context).pop();

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
              final restored = await pantryNotifier.undoQuantityTransaction(
                committedTransaction,
              );
              messenger.showSnackBar(
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

/// Full-scaffold fallback shown when building the serving plan for this
/// wizard fails for any reason. Keeps its own AppBar (with the exit action
/// still working) and offers a real Retry, matching the AppBar/CTA-visible
/// shape that a blank body must never be shown in instead. Not private, so
/// it can be exercised directly by widget tests.
class WizardErrorScaffold extends StatelessWidget {
  const WizardErrorScaffold({
    super.key,
    required this.phaseLabel,
    required this.onRetry,
    required this.onExit,
  });

  final String phaseLabel;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(phaseLabel, style: AppTypography.title),
        actions: [
          TextButton(
            key: const ValueKey<String>('wizard-exit-action'),
            onPressed: onExit,
            child: const Text('ออก'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.warning,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'โหลดข้อมูลสูตรนี้ไม่สำเร็จ',
                  style: AppTypography.title,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'ข้อมูล Pantry เดิมของคุณยังปลอดภัย ลองอีกครั้งได้',
                  style: AppTypography.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppButton(
                      key: const ValueKey<String>('wizard-error-exit'),
                      label: 'ออก',
                      variant: AppButtonVariant.secondary,
                      expand: false,
                      onPressed: onExit,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    AppButton(
                      key: const ValueKey<String>('wizard-error-retry'),
                      label: 'ลองอีกครั้ง',
                      expand: false,
                      onPressed: onRetry,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: AppRadius.mediumRadius,
                ),
                child: Text(recipe.emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.name, style: AppTypography.title),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          '${recipe.cookTimeMinutes} นาที',
                          style: AppTypography.caption,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const Icon(
                          Icons.local_fire_department_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          recipeDifficultyLabel(recipe.difficulty),
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.huge),
        Text(
          'สำหรับกี่คน?',
          style: AppTypography.title,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        ServingSelector(value: servings, onChanged: onChanged),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.servingPlan,
    required this.isAddingMissing,
    required this.missingInShoppingCount,
    required this.onAddMissing,
    required this.onGoToShopping,
  });

  final RecipeServingPlan servingPlan;
  final bool isAddingMissing;
  final int missingInShoppingCount;
  final VoidCallback onAddMissing;
  final VoidCallback? onGoToShopping;

  static const int _availableCollapseThreshold = 6;

  @override
  Widget build(BuildContext context) {
    final total = servingPlan.ingredients.length;
    final haveCount = servingPlan.enoughCount;
    final missing = servingPlan.ingredients
        .where(
          (item) =>
              !item.isEnough &&
              item.ingredient.effectiveRole() != RecipeIngredientRole.optional,
        )
        .toList(growable: false);
    final optional = servingPlan.ingredients
        .where(
          (item) =>
              item.ingredient.effectiveRole() == RecipeIngredientRole.optional,
        )
        .toList(growable: false);
    final available = servingPlan.ingredients
        .where((i) => i.isEnough)
        .toList(growable: false);
    final readyPercent = total == 0 ? 100 : ((haveCount / total) * 100).round();
    final visibleAvailable = available.length > _availableCollapseThreshold
        ? available.sublist(0, _availableCollapseThreshold)
        : available;
    final hiddenAvailableCount = available.length - visibleAvailable.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PantryReadinessCard(
            readyPercent: readyPercent,
            haveCount: haveCount,
            totalCount: total,
            missingCount: missing.length,
            onAddMissingIngredients: onAddMissing,
            isAddingMissing: isAddingMissing,
            missingInShoppingCount: missingInShoppingCount,
            onGoToShopping: onGoToShopping,
          ),
          if (available.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Text('มีครบแล้ว', style: AppTypography.label),
            const SizedBox(height: AppSpacing.sm),
            for (final item in visibleAvailable)
              _ChecklistRow(label: item.ingredient.name, checked: true),
            if (hiddenAvailableCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  '+$hiddenAvailableCount รายการ',
                  style: AppTypography.caption,
                ),
              ),
          ],
          if (missing.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('วัตถุดิบที่ขาด', style: AppTypography.label),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final item in missing)
                  IngredientStatusChip(
                    name: item.ingredient.name,
                    status: IngredientStatus.missing,
                  ),
              ],
            ),
          ],
          if (optional.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('วัตถุดิบเสริม (ไม่บังคับ)', style: AppTypography.label),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final item in optional)
                  IngredientStatusChip(
                    name: item.ingredient.name,
                    status: item.isEnough
                        ? IngredientStatus.available
                        : IngredientStatus.missing,
                  ),
              ],
            ),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              servingPlan.recipe.emoji,
              style: const TextStyle(fontSize: 44),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'พร้อมทำอาหาร!',
            style: AppTypography.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'คุณพร้อมทำ',
            style: AppTypography.body,
            textAlign: TextAlign.center,
          ),
          Text(
            servingPlan.recipe.name,
            style: AppTypography.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'สำหรับ ${servingPlan.servings} คน · ใช้เวลาโดยประมาณ ${servingPlan.recipe.cookTimeMinutes} นาที',
            style: AppTypography.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
