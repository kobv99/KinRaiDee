import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../../core/presentation/unit_presentation.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../pantry/domain/models/pantry_quantity_transaction.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/services/pantry_deduction_planner.dart';
import '../../domain/services/recipe_serving_calculator.dart';
import '../providers/recipe_provider.dart';
import '../widgets/recipe_image.dart';

class RecipeDetailPage extends ConsumerStatefulWidget {
  const RecipeDetailPage({super.key, required this.recipe});

  final Recipe recipe;

  @override
  ConsumerState<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends ConsumerState<RecipeDetailPage> {
  final GlobalKey _stepsKey = GlobalKey();
  final Set<int> _completedSteps = <int>{};

  late int _selectedServings;
  bool _cookingMode = false;
  bool _isFinishing = false;

  bool get _allStepsCompleted {
    return widget.recipe.steps.isEmpty ||
        _completedSteps.length == widget.recipe.steps.length;
  }

  @override
  void initState() {
    super.initState();
    final baseServings = widget.recipe.servings > 0
        ? widget.recipe.servings
        : 2;
    _selectedServings = baseServings.clamp(1, 12).toInt();
  }

  void _setServings(int servings) {
    final safeServings = servings.clamp(1, 12).toInt();
    if (safeServings == _selectedServings) {
      return;
    }

    setState(() {
      _selectedServings = safeServings;
      _cookingMode = false;
      _completedSteps.clear();
    });
  }

  void _startCooking() {
    setState(() {
      _cookingMode = true;
      _completedSteps.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stepsContext = _stepsKey.currentContext;
      if (stepsContext != null) {
        Scrollable.ensureVisible(
          stepsContext,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          alignment: 0.08,
        );
      }
    });
  }

  Future<void> _finishCooking(RecipeServingPlan servingPlan) async {
    if (_isFinishing) {
      return;
    }

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
      if (mounted) {
        setState(() {
          _cookingMode = false;
          _completedSteps.clear();
        });
      }
      return;
    }

    final selection = await showModalBottomSheet<_DeductionSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DeductionConfirmationSheet(plan: deductionPlan),
    );
    if (selection == null || !mounted) {
      return;
    }

    setState(() {
      _isFinishing = true;
    });

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

      setState(() {
        _cookingMode = false;
        _completedSteps.clear();
      });

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
        setState(() {
          _isFinishing = false;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    final pantry = ref.watch(pantryProvider);
    final servingPlan = const RecipeServingCalculator().calculate(
      recipe: widget.recipe,
      pantry: pantry,
      servings: _selectedServings,
      registry: ref.watch(canonicalIngredientRegistryProvider),
    );
    final colors = Theme.of(context).colorScheme;
    final completedCount = _completedSteps.length;
    final totalSteps = widget.recipe.steps.length;

    return Scaffold(
      appBar: AppBar(title: const Text('สูตรอาหาร')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: FilledButton.icon(
          onPressed: _bottomButtonEnabled
              ? () {
                  if (_cookingMode) {
                    _finishCooking(servingPlan);
                  } else {
                    _startCooking();
                  }
                }
              : null,
          icon: _isFinishing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _cookingMode
                      ? Icons.check_circle_outline_rounded
                      : Icons.play_arrow_rounded,
                ),
          label: Text(
            _bottomButtonLabel(
              completedCount: completedCount,
              totalSteps: totalSteps,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          _RecipeHeader(recipe: widget.recipe),
          const SizedBox(height: AppSpacing.md),
          const _SectionTitle(
            icon: Icons.groups_2_outlined,
            title: 'เลือกจำนวนคน',
            subtitle: 'ระบบจะคำนวณปริมาณวัตถุดิบให้ใหม่ทันที',
          ),
          const SizedBox(height: AppSpacing.sm),
          _ServingSelector(
            servings: _selectedServings,
            onChanged: _setServings,
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(
            icon: Icons.inventory_2_outlined,
            title: 'วัตถุดิบสำหรับ $_selectedServings คน',
            subtitle: servingPlan.hasEnoughRequiredIngredients
                ? 'วัตถุดิบหลักใน Pantry เพียงพอสำหรับสูตรนี้'
                : 'ยังขาดวัตถุดิบหลัก ${servingPlan.missingRequiredCount} รายการ',
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: AppRadius.largeCard,
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < servingPlan.ingredients.length;
                  index++
                ) ...[
                  _ScaledIngredientTile(item: servingPlan.ingredients[index]),
                  if (index < servingPlan.ingredients.length - 1)
                    Divider(height: 1, color: colors.outlineVariant),
                ],
              ],
            ),
          ),
          if (!servingPlan.hasEnoughRequiredIngredients) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: AppRadius.card,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: colors.onErrorContainer),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'คุณยังเปิดดูสูตรและเริ่มทำได้ แต่ควรตรวจวัตถุดิบที่ขาดก่อนลงมือ',
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Container(
            key: _stepsKey,
            child: _SectionTitle(
              icon: Icons.menu_book_outlined,
              title: _cookingMode ? 'โหมดทำอาหาร' : 'วิธีทำ',
              subtitle: _cookingMode
                  ? 'ทำทีละขั้น แล้วกด “ทำเสร็จแล้ว” เพื่ออัปเดต Pantry'
                  : '${widget.recipe.steps.length} ขั้นตอน',
            ),
          ),
          const SizedBox(height: 12),
          if (_cookingMode)
            _CookingChecklist(
              steps: widget.recipe.steps,
              completedSteps: _completedSteps,
              onChanged: (index, completed) {
                setState(() {
                  if (completed) {
                    _completedSteps.add(index);
                  } else {
                    _completedSteps.remove(index);
                  }
                });

                if (_allStepsCompleted && widget.recipe.steps.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'ทำครบทุกขั้นตอนแล้ว 🎉 กด “ทำเสร็จแล้ว” เพื่อตรวจปริมาณก่อนหัก Pantry',
                      ),
                    ),
                  );
                }
              },
            )
          else
            _RecipeSteps(steps: widget.recipe.steps),
          const SizedBox(height: 24),
          _RecipeMetadata(recipe: widget.recipe),
        ],
      ),
    );
  }

  bool get _bottomButtonEnabled {
    if (_isFinishing) {
      return false;
    }
    if (!_cookingMode) {
      return true;
    }
    return _allStepsCompleted;
  }

  String _bottomButtonLabel({
    required int completedCount,
    required int totalSteps,
  }) {
    if (_isFinishing) {
      return 'กำลังอัปเดต Pantry';
    }
    if (!_cookingMode) {
      return 'เริ่มทำอาหารสำหรับ $_selectedServings คน';
    }
    if (!_allStepsCompleted) {
      return 'ทำแล้ว $completedCount จาก $totalSteps ขั้นตอน';
    }
    return 'ทำเสร็จแล้ว · ตรวจและหัก Pantry';
  }
}

class _DeductionSelection {
  const _DeductionSelection({
    required this.selectedLineKeys,
    required this.quantitiesByLineKey,
  });

  final Set<String> selectedLineKeys;
  final Map<String, double> quantitiesByLineKey;
}

class _DeductionConfirmationSheet extends StatefulWidget {
  const _DeductionConfirmationSheet({required this.plan});

  final PantryDeductionPlan plan;

  @override
  State<_DeductionConfirmationSheet> createState() =>
      _DeductionConfirmationSheetState();
}

class _DeductionConfirmationSheetState
    extends State<_DeductionConfirmationSheet> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Set<String> _selectedKeys = <String>{};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    for (final line in widget.plan.lines) {
      _controllers[line.key] = TextEditingController(
        text: _formatNumber(line.deductibleQuantity),
      );
      if (line.defaultSelected) {
        _selectedKeys.add(line.key);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _confirm() {
    final quantities = <String, double>{};

    for (final line in widget.plan.lines) {
      if (!_selectedKeys.contains(line.key)) {
        continue;
      }

      final raw = _controllers[line.key]?.text.trim() ?? '';
      final quantity = double.tryParse(raw.replaceAll(',', '.'));
      if (quantity == null || quantity <= 0) {
        setState(() {
          _errorMessage = 'กรุณาระบุปริมาณที่มากกว่า 0';
        });
        return;
      }
      if (quantity > line.deductibleQuantity + 0.000001) {
        setState(() {
          _errorMessage =
              '${line.ingredient.name} หักได้สูงสุด ${_formatQuantity(line.deductibleQuantity, line.unit)}';
        });
        return;
      }

      quantities[line.key] = quantity;
    }

    if (quantities.isEmpty) {
      setState(() {
        _errorMessage = 'เลือกวัตถุดิบอย่างน้อย 1 รายการ';
      });
      return;
    }

    Navigator.of(context).pop(
      _DeductionSelection(
        selectedLineKeys: Set<String>.unmodifiable(_selectedKeys),
        quantitiesByLineKey: Map<String, double>.unmodifiable(quantities),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.82),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ตรวจปริมาณก่อนหัก Pantry',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.plan.servingPlan.recipe.name} สำหรับ ${widget.plan.servingPlan.servings} คน',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  children: [
                    ...widget.plan.lines.map(_buildLine),
                    if (widget.plan.skippedStapleCount > 0) ...[
                      const SizedBox(height: 8),
                      _InfoBox(
                        icon: Icons.info_outline_rounded,
                        text:
                            'เครื่องปรุง ${widget.plan.skippedStapleCount} รายการจะไม่ถูกหักอัตโนมัติ',
                      ),
                    ],
                    if (widget.plan.skippedUnavailableCount > 0) ...[
                      const SizedBox(height: 8),
                      _InfoBox(
                        icon: Icons.compare_arrows_rounded,
                        text:
                            'มี ${widget.plan.skippedUnavailableCount} รายการที่ไม่มีใน Pantry หรือหน่วยเทียบกันไม่ได้',
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: colors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('ยกเลิก'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _confirm,
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('ยืนยันและหักวัตถุดิบ'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLine(PantryDeductionLine line) {
    final selected = _selectedKeys.contains(line.key);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
        child: Column(
          children: [
            CheckboxListTile(
              value: selected,
              onChanged: (value) {
                setState(() {
                  _errorMessage = null;
                  if (value ?? false) {
                    _selectedKeys.add(line.key);
                  } else {
                    _selectedKeys.remove(line.key);
                  }
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(line.ingredient.name, style: AppTextStyles.labelLarge),
              subtitle: Text(
                line.isPartial
                    ? 'ต้องใช้ ${_formatQuantity(line.targetQuantity, line.unit)} · ใน Pantry หักได้ ${_formatQuantity(line.deductibleQuantity, line.unit)}'
                    : 'ต้องใช้ ${_formatQuantity(line.targetQuantity, line.unit)}',
              ),
            ),
            Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: TextField(
                    controller: _controllers[line.key],
                    enabled: selected,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'ปริมาณที่จะหัก',
                      suffixText: UnitPresentation.label(line.unit),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      if (_errorMessage != null) {
                        setState(() {
                          _errorMessage = null;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: selected
                      ? () {
                          _controllers[line.key]?.text = _formatNumber(
                            line.deductibleQuantity,
                          );
                        }
                      : null,
                  child: Text(
                    line.ingredient.required ? 'ตามสูตร' : 'ใช้ของเสริม',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: colors.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class _RecipeHeader extends ConsumerWidget {
  const _RecipeHeader({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(
      favoriteRecipeIdsProvider.select((ids) => ids.contains(recipe.id)),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppRadius.largeCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RecipeImage(recipe: recipe, size: 66, borderRadius: AppRadius.card),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.name, style: AppTextStyles.headlineMedium),
                if (recipe.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(recipe.description, style: AppTextStyles.bodyMedium),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (recipe.cookTimeMinutes > 0)
                      _HeaderChip(
                        icon: Icons.schedule,
                        label: '${recipe.cookTimeMinutes} นาที',
                      ),
                    _HeaderChip(
                      icon: Icons.restaurant_menu,
                      label: _difficultyLabel(recipe.difficulty),
                    ),
                    _HeaderChip(
                      icon: Icons.groups_2_outlined,
                      label: 'สูตรตั้งต้น ${recipe.servings} คน',
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey<String>('recipe-detail-favorite-${recipe.id}'),
            tooltip: isFavorite ? 'เอาออกจากรายการโปรด' : 'เพิ่มในรายการโปรด',
            onPressed: () =>
                ref.read(favoriteRecipeIdsProvider.notifier).toggle(recipe.id),
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServingSelector extends StatelessWidget {
  const _ServingSelector({required this.servings, required this.onChanged});

  final int servings;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _ServingRangeChip(
                label: '1–2 คน',
                selected: servings <= 2,
                onSelected: () => onChanged(2),
              ),
              _ServingRangeChip(
                label: '3–4 คน',
                selected: servings >= 3 && servings <= 4,
                onSelected: () => onChanged(4),
              ),
              _ServingRangeChip(
                label: '5–6 คน',
                selected: servings >= 5 && servings <= 6,
                onSelected: () => onChanged(6),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: 'ลดจำนวนคน',
                onPressed: servings > 1 ? () => onChanged(servings - 1) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 130,
                child: Column(
                  children: [
                    Text(
                      '$servings คน',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'ปรับได้ 1–12 คน',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'เพิ่มจำนวนคน',
                onPressed: servings < 12 ? () => onChanged(servings + 1) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServingRangeChip extends StatelessWidget {
  const _ServingRangeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _ScaledIngredientTile extends StatelessWidget {
  const _ScaledIngredientTile({required this.item});

  final ScaledRecipeIngredient item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusStyle = _statusStyle(item.status, colors);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: CircleAvatar(
        backgroundColor: statusStyle.backgroundColor,
        foregroundColor: statusStyle.foregroundColor,
        child: Icon(statusStyle.icon, size: 21),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.ingredient.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (!item.ingredient.required)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Chip(
                visualDensity: VisualDensity.compact,
                label: Text('เสริม'),
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(_pantryStatusLabel(item)),
      ),
      trailing: Text(
        _formatQuantity(item.requiredQuantity, item.ingredient.unit),
        textAlign: TextAlign.end,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _CookingChecklist extends StatelessWidget {
  const _CookingChecklist({
    required this.steps,
    required this.completedSteps,
    required this.onChanged,
  });

  final List<String> steps;
  final Set<int> completedSteps;
  final void Function(int index, bool completed) onChanged;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const _EmptySteps();
    }

    return Column(
      children: steps.indexed
          .map(
            (entry) => AppCard(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: EdgeInsets.zero,
              child: CheckboxListTile(
                value: completedSteps.contains(entry.$1),
                onChanged: (value) => onChanged(entry.$1, value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'ขั้นตอน ${entry.$1 + 1}',
                  style: AppTextStyles.labelLarge,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Text(entry.$2, style: AppTextStyles.bodyMedium),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _RecipeSteps extends StatelessWidget {
  const _RecipeSteps({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const _EmptySteps();
    }

    return Column(
      children: steps.indexed
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 16, child: Text('${entry.$1 + 1}')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(entry.$2),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _EmptySteps extends StatelessWidget {
  const _EmptySteps();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Text(
        'สูตรนี้ยังไม่มีข้อมูลขั้นตอนการทำ',
        style: AppTextStyles.bodyMedium,
      ),
    );
  }
}

class _RecipeMetadata extends StatelessWidget {
  const _RecipeMetadata({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(label: Text(recipe.category)),
        ...recipe.cookingMethods.map((method) => Chip(label: Text(method))),
        ...recipe.tags.take(3).map((tag) => Chip(label: Text(tag))),
      ],
    );
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
}

_StatusStyle _statusStyle(PantryQuantityStatus status, ColorScheme colors) {
  switch (status) {
    case PantryQuantityStatus.enough:
      return _StatusStyle(
        icon: Icons.check_rounded,
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
      );
    case PantryQuantityStatus.insufficient:
      return _StatusStyle(
        icon: Icons.warning_amber_rounded,
        backgroundColor: colors.tertiaryContainer,
        foregroundColor: colors.onTertiaryContainer,
      );
    case PantryQuantityStatus.missing:
      return _StatusStyle(
        icon: Icons.shopping_basket_outlined,
        backgroundColor: colors.errorContainer,
        foregroundColor: colors.onErrorContainer,
      );
    case PantryQuantityStatus.incompatibleUnit:
      return _StatusStyle(
        icon: Icons.compare_arrows_rounded,
        backgroundColor: colors.secondaryContainer,
        foregroundColor: colors.onSecondaryContainer,
      );
  }
}

String _pantryStatusLabel(ScaledRecipeIngredient item) {
  switch (item.status) {
    case PantryQuantityStatus.enough:
      return 'มี ${_formatQuantity(item.pantryQuantityInRecipeUnit ?? 0, item.ingredient.unit)} • เพียงพอ';
    case PantryQuantityStatus.insufficient:
      return 'มี ${_formatQuantity(item.pantryQuantityInRecipeUnit ?? 0, item.ingredient.unit)} • ขาด ${_formatQuantity(item.shortageQuantity, item.ingredient.unit)}';
    case PantryQuantityStatus.missing:
      return item.ingredient.required
          ? 'ยังไม่มีใน Pantry'
          : 'ยังไม่มีใน Pantry • ไม่ใส่ก็ได้';
    case PantryQuantityStatus.incompatibleUnit:
      final pantryQuantity = item.pantryDisplayQuantity ?? 0;
      final pantryUnit = UnitPresentation.label(item.pantryDisplayUnit ?? '');
      return 'มี ${_formatNumber(pantryQuantity)} $pantryUnit • หน่วยไม่ตรง กรุณาตรวจจำนวนเอง';
  }
}

String _formatQuantity(double quantity, String unit) {
  final normalizedUnit = UnitPresentation.label(unit);
  if (normalizedUnit == 'กรัม' && quantity >= 1000) {
    return '${_formatNumber(quantity / 1000)} กิโลกรัม';
  }
  if (normalizedUnit == 'มิลลิลิตร' && quantity >= 1000) {
    return '${_formatNumber(quantity / 1000)} ลิตร';
  }
  return UnitPresentation.quantity(
    quantity,
    normalizedUnit,
    maximumFractionDigits: 2,
  );
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  if ((value * 10).roundToDouble() == value * 10) {
    return value.toStringAsFixed(1);
  }
  return value.toStringAsFixed(2);
}

String _difficultyLabel(String difficulty) {
  return switch (difficulty.toLowerCase()) {
    'easy' => 'ง่าย',
    'medium' => 'ปานกลาง',
    'hard' => 'ยาก',
    _ => difficulty,
  };
}
