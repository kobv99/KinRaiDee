import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../pantry/application/inventory_transaction_providers.dart';
import '../../../pantry/domain/models/pantry_quantity_transaction.dart';
import '../../domain/entities/cooking_session.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/recipe_step.dart';
import '../../domain/services/pantry_deduction_planner.dart';
import '../../domain/services/recipe_serving_calculator.dart';
import '../providers/cooking_session_provider.dart';
import '../widgets/pantry_deduction_sheet.dart';

enum CookingStage { summary, checklist, steps, complete }

class CookingModePage extends ConsumerStatefulWidget {
  const CookingModePage({
    super.key,
    required this.recipe,
    required this.servings,
  });

  final Recipe recipe;
  final int servings;

  @override
  ConsumerState<CookingModePage> createState() => _CookingModePageState();
}

class _CookingModePageState extends ConsumerState<CookingModePage> {
  CookingStage _stage = CookingStage.summary;
  int _stepIndex = 0;
  bool _isFinishing = false;

  List<RecipeStep> get _steps => widget.recipe.instructions;

  bool get _canExitWithoutConfirmation =>
      _stage == CookingStage.summary || _stage == CookingStage.complete;

  @override
  Widget build(BuildContext context) {
    final servingPlan = const RecipeServingCalculator().calculate(
      recipe: widget.recipe,
      pantry: ref.watch(pantryProvider),
      servings: widget.servings,
      registry: ref.watch(canonicalIngredientRegistryProvider),
    );

    return PopScope(
      canPop: _canExitWithoutConfirmation,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('โหมดทำอาหาร'),
          leading: IconButton(
            key: const ValueKey<String>('cooking-mode-exit-button'),
            tooltip: 'ออกจากโหมดทำอาหาร',
            onPressed: () async {
              if (_canExitWithoutConfirmation) {
                Navigator.of(context).pop();
                return;
              }
              await _confirmExit();
            },
            icon: const Icon(Icons.close),
          ),
        ),
        body: SafeArea(child: _buildStage(servingPlan)),
      ),
    );
  }

  Widget _buildStage(RecipeServingPlan servingPlan) {
    return switch (_stage) {
      CookingStage.summary => _SummaryStage(
        recipe: widget.recipe,
        servings: widget.servings,
        onStart: _startSession,
      ),
      CookingStage.checklist => _ChecklistStage(
        servingPlan: servingPlan,
        onBack: () => setState(() => _stage = CookingStage.summary),
        onNext: () => setState(() => _stage = CookingStage.steps),
      ),
      CookingStage.steps => _StepsStage(
        recipe: widget.recipe,
        stepIndex: _stepIndex,
        isFinishing: _isFinishing,
        onPrevious: _stepIndex == 0
            ? () => setState(() => _stage = CookingStage.checklist)
            : () => setState(() => _stepIndex -= 1),
        onNext: _stepIndex + 1 < _steps.length
            ? () => setState(() => _stepIndex += 1)
            : null,
        onFinish: _isFinishing ? null : () => _finishCooking(servingPlan),
      ),
      CookingStage.complete => _CompleteStage(
        session: ref.watch(cookingSessionProvider),
        now: ref.read(appClockProvider).now(),
        onClose: () => Navigator.of(context).pop(),
      ),
    };
  }

  void _startSession() {
    ref
        .read(cookingSessionProvider.notifier)
        .start(recipe: widget.recipe, servings: widget.servings);
    setState(() {
      _stage = CookingStage.checklist;
      _stepIndex = 0;
    });
  }

  Future<void> _confirmExit() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ออกจากโหมดทำอาหาร?'),
        content: const Text('ความคืบหน้าการทำอาหารจะหายไป'),
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
    if (shouldLeave != true || !mounted) {
      return;
    }
    ref.read(cookingSessionProvider.notifier).abandon();
    Navigator.of(context).pop();
  }

  Future<void> _finishCooking(RecipeServingPlan servingPlan) async {
    if (_isFinishing) {
      return;
    }

    final planner = const PantryDeductionPlanner();
    final deductionPlan = planner.build(
      servingPlan: servingPlan,
      pantry: ref.read(pantryProvider),
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
      _completeSession();
      return;
    }

    final selection = await showModalBottomSheet<PantryDeductionSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PantryDeductionSheet(plan: deductionPlan),
    );
    if (selection == null || !mounted) {
      return;
    }

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
      if (!mounted) {
        return;
      }

      _completeSession();

      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'หักวัตถุดิบ ${committedTransaction.changedIngredientCount} รายการจาก Pantry แล้ว',
          ),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'ย้อนกลับ',
            onPressed: () => _undoTransaction(committedTransaction),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isFinishing = false);
      }
    }
  }

  void _completeSession() {
    ref.read(cookingSessionProvider.notifier).complete();
    if (mounted) {
      setState(() => _stage = CookingStage.complete);
    }
  }

  Future<void> _undoTransaction(PantryQuantityTransaction transaction) async {
    final restored = await ref
        .read(pantryProvider.notifier)
        .undoQuantityTransaction(transaction);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          restored > 0
              ? 'คืนวัตถุดิบ $restored รายการกลับเข้า Pantry แล้ว'
              : 'ย้อนกลับไม่ได้ เพราะปริมาณวัตถุดิบถูกแก้ไขหลังจากนั้น',
        ),
      ),
    );
  }
}

class _SummaryStage extends StatelessWidget {
  const _SummaryStage({
    required this.recipe,
    required this.servings,
    required this.onStart,
  });

  final Recipe recipe;
  final int servings;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            children: [
              Text(
                recipe.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _SummaryRow(
                icon: Icons.groups_2_outlined,
                label: 'จำนวนคน',
                value: '$servings คน',
              ),
              _SummaryRow(
                icon: Icons.schedule,
                label: 'เวลาทำอาหาร',
                value: recipe.cookTimeMinutes > 0
                    ? '${recipe.cookTimeMinutes} นาที'
                    : 'ไม่ระบุ',
              ),
              _SummaryRow(
                icon: Icons.menu_book_outlined,
                label: 'ขั้นตอน',
                value: '${recipe.instructions.length} ขั้นตอน',
              ),
              const SizedBox(height: 16),
              Text(
                'โหมดทำอาหารจะแสดงเฉพาะสิ่งที่ต้องทำ ไม่มีคำแนะนำเมนูหรือแดชบอร์ดมารบกวน',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        _StageActions(
          primaryLabel: 'เริ่มทำอาหาร',
          primaryKey: const ValueKey<String>('cooking-start-button'),
          onPrimary: onStart,
        ),
      ],
    );
  }
}

class _ChecklistStage extends StatelessWidget {
  const _ChecklistStage({
    required this.servingPlan,
    required this.onBack,
    required this.onNext,
  });

  final RecipeServingPlan servingPlan;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final required = servingPlan.ingredients
        .where(
          (item) =>
              item.ingredient.required &&
              item.status == PantryQuantityStatus.enough,
        )
        .toList(growable: false);
    final missing = servingPlan.ingredients
        .where(
          (item) =>
              item.ingredient.required &&
              item.status != PantryQuantityStatus.enough,
        )
        .toList(growable: false);
    final optional = servingPlan.ingredients
        .where((item) => !item.ingredient.required)
        .toList(growable: false);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            children: [
              Text(
                'ตรวจวัตถุดิบก่อนลงมือ',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _ChecklistGroup(title: 'วัตถุดิบที่ต้องใช้', items: required),
              _ChecklistGroup(title: 'วัตถุดิบที่ขาด', items: missing),
              _ChecklistGroup(title: 'วัตถุดิบเสริม', items: optional),
              if (missing.isNotEmpty)
                const RecipeInfoBox(
                  icon: Icons.info_outline_rounded,
                  text:
                      'คุณยังทำอาหารต่อได้ วัตถุดิบที่ขาดจะไม่ถูกหักจาก Pantry',
                ),
            ],
          ),
        ),
        _StageActions(
          secondaryLabel: 'ย้อนกลับ',
          onSecondary: onBack,
          primaryLabel: 'ถัดไป',
          primaryKey: const ValueKey<String>('cooking-checklist-next-button'),
          onPrimary: onNext,
        ),
      ],
    );
  }
}

class _ChecklistGroup extends StatelessWidget {
  const _ChecklistGroup({required this.title, required this.items});

  final String title;
  final List<ScaledRecipeIngredient> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...items.map(
            (item) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.circle_outlined, size: 18),
              title: Text(item.ingredient.name),
              trailing: Text(
                formatRecipeQuantity(
                  item.requiredQuantity,
                  item.ingredient.unit,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsStage extends StatelessWidget {
  const _StepsStage({
    required this.recipe,
    required this.stepIndex,
    required this.isFinishing,
    required this.onPrevious,
    required this.onNext,
    required this.onFinish,
  });

  final Recipe recipe;
  final int stepIndex;
  final bool isFinishing;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    final steps = recipe.instructions;
    final colors = Theme.of(context).colorScheme;
    if (steps.isEmpty) {
      return Column(
        children: [
          const Expanded(
            child: Center(child: Text('สูตรนี้ยังไม่มีข้อมูลขั้นตอนการทำ')),
          ),
          _StageActions(
            secondaryLabel: 'ย้อนกลับ',
            onSecondary: onPrevious,
            primaryLabel: 'ทำอาหารเสร็จแล้ว',
            primaryKey: const ValueKey<String>('cooking-finish-button'),
            onPrimary: onFinish,
          ),
        ],
      );
    }

    final step = steps[stepIndex];
    final remaining = _remainingMinutes(recipe, steps, stepIndex);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ขั้นตอน ${stepIndex + 1} / ${steps.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (remaining != null)
                    Text(
                      'เหลืออีกประมาณ $remaining นาที',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  key: const ValueKey<String>('cooking-progress-bar'),
                  value: (stepIndex + 1) / steps.length,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            children: [
              Text(
                step.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                step.accessibleInstruction,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (step.tip?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 16),
                RecipeInfoBox(
                  icon: Icons.lightbulb_outline,
                  text: step.tip!.trim(),
                ),
              ],
            ],
          ),
        ),
        _StageActions(
          secondaryLabel: stepIndex == 0 ? 'ย้อนกลับ' : 'ขั้นตอนก่อนหน้า',
          onSecondary: onPrevious,
          primaryLabel: isFinishing
              ? 'กำลังอัปเดต Pantry'
              : (onNext == null ? 'ทำอาหารเสร็จแล้ว' : 'ขั้นตอนถัดไป'),
          primaryKey: onNext == null
              ? const ValueKey<String>('cooking-finish-button')
              : const ValueKey<String>('cooking-next-step-button'),
          onPrimary: onNext ?? onFinish,
        ),
      ],
    );
  }

  static int? _remainingMinutes(
    Recipe recipe,
    List<RecipeStep> steps,
    int stepIndex,
  ) {
    var total = 0;
    var hasDuration = false;
    for (var index = stepIndex; index < steps.length; index++) {
      final duration = steps[index].durationMinutes;
      if (duration != null && duration > 0) {
        hasDuration = true;
        total += duration;
      }
    }
    if (hasDuration) {
      return total;
    }
    if (recipe.cookTimeMinutes <= 0) {
      return null;
    }
    final perStep = recipe.cookTimeMinutes / steps.length;
    return (perStep * (steps.length - stepIndex)).ceil();
  }
}

class _CompleteStage extends StatelessWidget {
  const _CompleteStage({
    required this.session,
    required this.now,
    required this.onClose,
  });

  final CookingSession? session;
  final DateTime now;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final elapsed = session?.elapsedAt(now);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 12),
            children: [
              Icon(Icons.celebration_outlined, size: 72, color: colors.primary),
              const SizedBox(height: 16),
              Text(
                'ทำอาหารเสร็จแล้ว 🎉',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (session != null) ...[
                const SizedBox(height: 10),
                Text(
                  '${session!.recipeName} สำหรับ ${session!.servings} คน',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              if (elapsed != null) ...[
                const SizedBox(height: 6),
                Text(
                  'ใช้เวลาไป ${elapsed.inMinutes} นาที',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const RecipeInfoBox(
                icon: Icons.upcoming_outlined,
                text:
                    'เร็ว ๆ นี้: บันทึกเมนูโปรด ประวัติการทำอาหาร และให้คะแนน',
              ),
            ],
          ),
        ),
        _StageActions(
          primaryLabel: 'เสร็จสิ้น',
          primaryKey: const ValueKey<String>('cooking-close-button'),
          onPrimary: onClose,
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _StageActions extends StatelessWidget {
  const _StageActions({
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryKey,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final Key? primaryKey;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          if (secondaryLabel != null) ...[
            Expanded(
              child: OutlinedButton(
                key: const ValueKey<String>('cooking-previous-button'),
                onPressed: onSecondary,
                child: Text(secondaryLabel!),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: FilledButton(
              key: primaryKey,
              onPressed: onPrimary,
              child: Text(primaryLabel),
            ),
          ),
        ],
      ),
    );
  }
}
