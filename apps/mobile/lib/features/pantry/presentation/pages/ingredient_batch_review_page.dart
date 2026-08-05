import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/models/ingredient.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../providers/ingredient_picker_providers.dart';

class _DraftRow {
  _DraftRow({
    required this.canonicalId,
    required this.quantityController,
    required this.unitId,
  });

  final String canonicalId;
  final TextEditingController quantityController;
  String unitId;
}

/// The mandatory step before any pantry write: every selected canonical id
/// is shown with its registry-suggested quantity/unit, both editable, and
/// nothing is written until the user explicitly commits. On success, all
/// rows are added in exactly one inventory transaction; on failure, the
/// draft is preserved so retry doesn't require re-selecting anything.
class IngredientBatchReviewPage extends ConsumerStatefulWidget {
  const IngredientBatchReviewPage({super.key});

  @override
  ConsumerState<IngredientBatchReviewPage> createState() =>
      _IngredientBatchReviewPageState();
}

class _IngredientBatchReviewPageState
    extends ConsumerState<IngredientBatchReviewPage> {
  late List<_DraftRow> _rows;
  bool _isCommitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final registry = ref.read(canonicalIngredientRegistryProvider);
    final orderedIds = ref.read(ingredientPickerSelectionProvider).toList()
      ..sort((a, b) {
        final nameA = registry?.byId(a)?.displayName() ?? a;
        final nameB = registry?.byId(b)?.displayName() ?? b;
        return nameA.compareTo(nameB);
      });
    _rows = orderedIds.map((id) {
      final canonical = registry?.byId(id);
      final quantity = canonical?.defaultPantryQuantity ?? 1.0;
      final unitId = canonical?.defaultPantryUnitId ?? '';
      return _DraftRow(
        canonicalId: id,
        quantityController: TextEditingController(
          text: _formatQuantity(quantity),
        ),
        unitId: unitId,
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.quantityController.dispose();
    }
    super.dispose();
  }

  static String _formatQuantity(double quantity) {
    return quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();
  }

  void _removeRow(_DraftRow row) {
    setState(() {
      row.quantityController.dispose();
      _rows.remove(row);
    });
  }

  Future<void> _commit() async {
    final registry = ref.read(canonicalIngredientRegistryProvider);
    final unitEngine = ref.read(unitConversionEngineProvider);
    final seenIds = <String>{};
    final toAdd = <Ingredient>[];
    final now = DateTime.now();

    for (final row in _rows) {
      if (!seenIds.add(row.canonicalId)) {
        setState(() => _errorMessage = 'พบวัตถุดิบซ้ำในรายการ');
        return;
      }
      final quantity = double.tryParse(row.quantityController.text.trim());
      if (quantity == null || !quantity.isFinite || quantity <= 0) {
        setState(() => _errorMessage = 'กรุณาใส่จำนวนที่มากกว่า 0');
        return;
      }
      final resolvedUnitId = unitEngine.resolveUnitId(row.unitId);
      if (resolvedUnitId == null) {
        setState(() => _errorMessage = 'หน่วยไม่ถูกต้อง กรุณาเลือกใหม่');
        return;
      }
      final canonical = registry?.byId(row.canonicalId);
      if (canonical == null) {
        setState(() => _errorMessage = 'ไม่พบวัตถุดิบในระบบ');
        return;
      }
      toAdd.add(
        Ingredient(
          id: '${canonical.id}-${now.microsecondsSinceEpoch}',
          name: canonical.displayName(),
          category: canonical.category,
          emoji: canonical.emoji,
          quantity: quantity,
          unit:
              unitEngine.resolveUnit(resolvedUnitId)?.displayName ??
              resolvedUnitId,
          createdAt: now,
          updatedAt: now,
          canonicalIngredientId: canonical.id,
          canonicalUnitId: resolvedUnitId,
          canonicalMappingStatus: CanonicalMappingStatus.mapped,
        ),
      );
    }

    setState(() {
      _isCommitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(pantryProvider.notifier).addIngredientsBatch(toAdd);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCommitting = false;
        _errorMessage = 'เพิ่มวัตถุดิบไม่สำเร็จ กรุณาลองใหม่';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตรวจสอบก่อนเพิ่ม')),
      body: SafeArea(
        child: Column(
          children: [
            if (_errorMessage != null)
              Container(
                key: const ValueKey<String>('ingredient-review-error'),
                width: double.infinity,
                color: Theme.of(context).colorScheme.errorContainer,
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            Expanded(
              child: _rows.isEmpty
                  ? const Center(child: Text('ไม่มีวัตถุดิบให้ตรวจสอบ'))
                  : ListView.builder(
                      key: const ValueKey<String>('ingredient-review-list'),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: _rows.length,
                      itemBuilder: (context, index) => _ReviewRowCard(
                        row: _rows[index],
                        onRemove: () => _removeRow(_rows[index]),
                        onUnitChanged: (unitId) =>
                            setState(() => _rows[index].unitId = unitId),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: FilledButton(
            key: const ValueKey<String>('ingredient-review-commit-button'),
            onPressed: (_rows.isEmpty || _isCommitting) ? null : _commit,
            child: _isCommitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('เพิ่มทั้งหมด ${_rows.length} รายการ'),
          ),
        ),
      ),
    );
  }
}

class _ReviewRowCard extends ConsumerWidget {
  const _ReviewRowCard({
    required this.row,
    required this.onRemove,
    required this.onUnitChanged,
  });

  final _DraftRow row;
  final VoidCallback onRemove;
  final ValueChanged<String> onUnitChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(canonicalIngredientRegistryProvider);
    final unitEngine = ref.watch(unitConversionEngineProvider);
    final canonical = registry?.byId(row.canonicalId);
    final breadcrumb = registry == null
        ? const <String>[]
        : registry
              .ancestorChainFor(row.canonicalId)
              .map((id) => registry.byId(id)?.displayName() ?? id)
              .toList(growable: false);
    final unitOptions =
        (canonical != null && canonical.recommendedUnitIds.isNotEmpty)
        ? canonical.recommendedUnitIds
        : <String>[row.unitId];

    return Card(
      key: ValueKey<String>('ingredient-review-row-${row.canonicalId}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canonical?.displayName() ?? row.canonicalId,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (breadcrumb.isNotEmpty)
                        Text(
                          breadcrumb.join(' › '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey<String>(
                    'ingredient-review-remove-${row.canonicalId}',
                  ),
                  icon: const Icon(Icons.close),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey<String>(
                      'ingredient-review-quantity-${row.canonicalId}',
                    ),
                    controller: row.quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'จำนวน'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                DropdownButton<String>(
                  key: ValueKey<String>(
                    'ingredient-review-unit-${row.canonicalId}',
                  ),
                  value: unitOptions.contains(row.unitId)
                      ? row.unitId
                      : unitOptions.first,
                  items: unitOptions
                      .map(
                        (unitId) => DropdownMenuItem<String>(
                          value: unitId,
                          child: Text(
                            unitEngine.resolveUnit(unitId)?.displayName ??
                                unitId,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      onUnitChanged(value);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
