import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../pantry/application/inventory_transaction_providers.dart';
import '../../../recipe/domain/entities/recipe.dart';
import '../../../recipe/presentation/providers/recipe_provider.dart';
import '../../application/shopping_providers.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/entities/shopping_item_status.dart';
import '../../domain/entities/shopping_list.dart';
import '../../domain/models/shopping_mutation.dart';
import '../../domain/services/shopping_draft_builder.dart';
import '../../domain/services/shopping_engine.dart';
import '../providers/shopping_view_provider.dart';

class ShoppingGenerationSheet extends ConsumerStatefulWidget {
  const ShoppingGenerationSheet({required this.existingList, super.key});

  final ShoppingList? existingList;

  @override
  ConsumerState<ShoppingGenerationSheet> createState() =>
      _ShoppingGenerationSheetState();
}

class _ShoppingGenerationSheetState
    extends ConsumerState<ShoppingGenerationSheet> {
  final Map<String, int> _servings = <String, int>{};
  ShoppingGenerationResult? _preview;
  bool _isSaving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(recipesProvider);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          top: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _preview == null
                            ? 'เลือกเมนู'
                            : 'ตรวจสอบรายการก่อนบันทึก',
                        style: AppTextStyles.headlineMedium,
                      ),
                      Text(
                        _preview == null
                            ? 'เลือกหนึ่งเมนูขึ้นไป ระบบจะหักจำนวนที่มีใน Pantry อัตโนมัติ'
                            : 'ตรวจสอบการเปลี่ยนแปลงก่อนยืนยันบันทึก',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'ปิด',
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _InlineError(message: _error!),
            ],
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: _preview == null
                  ? recipes.when(
                      data: _buildRecipeSelection,
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          key: ValueKey<String>('shopping-recipes-loading'),
                        ),
                      ),
                      error: (error, stackTrace) => _GenerationError(
                        onRetry: () => ref.invalidate(recipesProvider),
                      ),
                    )
                  : _buildPreview(_preview!),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_preview == null)
              FilledButton.icon(
                key: const ValueKey<String>('shopping-preview-button'),
                onPressed: _servings.isEmpty ? null : _createPreview,
                icon: const Icon(Icons.visibility_outlined),
                label: Text(
                  _servings.isEmpty
                      ? 'เลือกเมนูเพื่อดูตัวอย่าง'
                      : 'ดูตัวอย่าง ${_servings.length} เมนู',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey<String>(
                        'shopping-preview-back-button',
                      ),
                      onPressed: _isSaving
                          ? null
                          : () => setState(() {
                              _preview = null;
                              _error = null;
                            }),
                      child: const Text('ย้อนกลับ'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      key: const ValueKey<String>('shopping-confirm-button'),
                      onPressed: _isSaving ? null : _confirm,
                      icon: _isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        _isSaving ? 'กำลังบันทึก…' : 'ยืนยันรายการซื้อของ',
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeSelection(List<Recipe> recipes) {
    if (recipes.isEmpty) {
      return const Center(child: Text('ไม่มีข้อมูลเมนูในอุปกรณ์นี้'));
    }
    return ListView.separated(
      key: const ValueKey<String>('shopping-recipe-selection'),
      itemCount: recipes.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        final selected = _servings.containsKey(recipe.id);
        final servings = _servings[recipe.id] ?? recipe.servings;
        return CheckboxListTile(
          key: ValueKey<String>('shopping-recipe-${recipe.id}'),
          value: selected,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (value) {
            setState(() {
              _preview = null;
              _error = null;
              if (value ?? false) {
                _servings[recipe.id] = recipe.servings > 0
                    ? recipe.servings
                    : 1;
              } else {
                _servings.remove(recipe.id);
              }
            });
          },
          title: Text(recipe.name, style: AppTextStyles.titleMedium),
          subtitle: Text(
            '${recipe.cookTimeMinutes} นาที • ${recipe.category}',
            style: AppTextStyles.bodySmall,
          ),
          secondary: selected
              ? _ServingStepper(
                  value: servings,
                  onChanged: (value) {
                    setState(() {
                      _servings[recipe.id] = value;
                      _preview = null;
                    });
                  },
                )
              : CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Text(recipe.emoji),
                ),
        );
      },
    );
  }

  Widget _buildPreview(ShoppingGenerationResult preview) {
    final active = preview.list.items
        .where((item) => item.status == ShoppingItemStatus.active)
        .toList(growable: false);
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.secondaryLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              _PreviewMetric(value: '${preview.recipeCount}', label: 'เมนู'),
              _PreviewMetric(
                value: '${preview.aggregatedIngredientCount}',
                label: 'วัตถุดิบ',
              ),
              _PreviewMetric(
                value: '${preview.missingIngredientCount}',
                label: 'ต้องซื้อ',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: active.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.kitchen_outlined,
                        size: 48,
                        color: AppColors.success,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text('วัตถุดิบใน Pantry เพียงพอสำหรับเมนูเหล่านี้แล้ว'),
                    ],
                  ),
                )
              : ListView.separated(
                  key: const ValueKey<String>('shopping-generation-preview'),
                  itemCount: active.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = active[index];
                    final change = _changeFor(item);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: change.color.withValues(alpha: 0.12),
                        child: Icon(change.icon, color: change.color),
                      ),
                      title: Text(item.displayName),
                      subtitle: Text(
                        item.sourceReferenceIds.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${formatShoppingQuantity(item.quantity)} '
                            '${shoppingUnitLabel(item.unitId)}',
                            style: AppTextStyles.labelLarge,
                          ),
                          Text(
                            change.label,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: change.color,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _createPreview() {
    final engine = ref.read(shoppingEngineProvider);
    if (engine == null) {
      setState(() => _error = 'กำลังโหลดข้อมูลวัตถุดิบ กรุณาลองอีกครั้ง');
      return;
    }
    final recipes = ref.read(recipesProvider).value ?? const <Recipe>[];
    final byId = <String, Recipe>{
      for (final recipe in recipes) recipe.id: recipe,
    };
    try {
      final now = ref.read(appClockProvider).now().toUtc();
      final existing = widget.existingList;
      final preview = engine.generate(
        listId: existing?.id ?? 'primary-shopping-list',
        name: existing?.name ?? 'รายการซื้อของของฉัน',
        recipes: _servings.entries
            .map(
              (entry) => ShoppingRecipeRequest(
                recipe: byId[entry.key]!,
                servings: entry.value,
              ),
            )
            .toList(growable: false),
        pantry: ref.read(pantryProvider),
        generatedAt: now,
        existingList: existing,
      );
      setState(() {
        _preview = preview;
        _error = null;
      });
    } on ShoppingDomainException catch (error) {
      setState(() => _error = error.message);
    } on Object {
      setState(() => _error = 'Could not generate a preview.');
    }
  }

  Future<void> _confirm() async {
    final preview = _preview;
    if (preview == null) {
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(shoppingMutationControllerProvider)
          .execute(
            ShoppingMutation.upsert(
              list: preview.list,
              createdAt: ref.read(appClockProvider).now(),
            ),
          );
      if (!mounted) {
        return;
      }
      if (!result.isSuccess) {
        setState(() {
          _isSaving = false;
          _error = _transactionError(result.code);
        });
        return;
      }
      Navigator.of(context).pop(true);
    } on Object {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = 'ไม่สามารถบันทึกรายการได้ ข้อมูลเดิมไม่ถูกเปลี่ยนแปลง';
        });
      }
    }
  }

  _PreviewChange _changeFor(ShoppingItem item) {
    final existing = widget.existingList?.items
        .where(
          (current) =>
              current.status == ShoppingItemStatus.active &&
              current.canonicalIngredientId == item.canonicalIngredientId,
        )
        .firstOrNull;
    if (existing == null) {
      return const _PreviewChange(
        label: 'เพิ่ม',
        icon: Icons.add,
        color: AppColors.success,
      );
    }
    if (existing.quantity == item.quantity && existing.unitId == item.unitId) {
      return const _PreviewChange(
        label: 'คงเดิม',
        icon: Icons.check,
        color: AppColors.info,
      );
    }
    return const _PreviewChange(
      label: 'อัปเดต',
      icon: Icons.sync,
      color: AppColors.warning,
    );
  }
}

class _ServingStepper extends StatelessWidget {
  const _ServingStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'ลดจำนวนที่เสิร์ฟ',
          visualDensity: VisualDensity.compact,
          onPressed: value <= 1 ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$value', style: AppTextStyles.labelLarge),
        IconButton(
          tooltip: 'เพิ่มจำนวนที่เสิร์ฟ',
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.headlineMedium),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenerationError extends StatelessWidget {
  const _GenerationError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: AppSpacing.sm),
          const Text('ไม่สามารถโหลดข้อมูลเมนูได้'),
          TextButton(onPressed: onRetry, child: const Text('ลองอีกครั้ง')),
        ],
      ),
    );
  }
}

class _PreviewChange {
  const _PreviewChange({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

String _transactionError(String code) {
  return switch (code) {
    'stale_inventory_revision' || 'stale_shopping_list_revision' =>
      'รายการมีการเปลี่ยนแปลง กรุณาปิดตัวอย่างแล้วลองอีกครั้ง',
    'invalid_shopping_unit_conversion' =>
      'มีจำนวนอย่างน้อยหนึ่งรายการที่ไม่สามารถแปลงหน่วยได้อย่างปลอดภัย',
    'recovery_required' => 'ต้องกู้คืนข้อมูลในเครื่องให้เสร็จก่อนแก้ไขรายการ',
    _ => 'ไม่สามารถบันทึกรายการได้ ($code) ข้อมูลเดิมไม่ถูกเปลี่ยนแปลง',
  };
}
