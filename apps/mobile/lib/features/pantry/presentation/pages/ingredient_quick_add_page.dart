import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/models/ingredient.dart';
import '../../../../core/providers/pantry_provider.dart';

/// The direct search-to-pantry path: tapping a search result opens this
/// single-item quantity/unit editor instead of joining the Browse
/// multi-select draft. Uses the same [PantryNotifier.addIngredientsBatch]
/// atomic-commit path as Browse (with a batch of exactly one), so success
/// is still exactly one inventory transaction, and a failure leaves the
/// entered values in place for retry.
class IngredientQuickAddPage extends ConsumerStatefulWidget {
  const IngredientQuickAddPage({super.key, required this.canonicalId});

  final String canonicalId;

  @override
  ConsumerState<IngredientQuickAddPage> createState() =>
      _IngredientQuickAddPageState();
}

class _IngredientQuickAddPageState
    extends ConsumerState<IngredientQuickAddPage> {
  late final TextEditingController _quantityController;
  late String _unitId;
  bool _isCommitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final registry = ref.read(canonicalIngredientRegistryProvider);
    final canonical = registry?.byId(widget.canonicalId);
    _quantityController = TextEditingController(
      text: _formatQuantity(canonical?.defaultPantryQuantity ?? 1.0),
    );
    _unitId = canonical?.defaultPantryUnitId ?? '';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  static String _formatQuantity(double quantity) {
    return quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();
  }

  Future<void> _commit() async {
    final registry = ref.read(canonicalIngredientRegistryProvider);
    final unitEngine = ref.read(unitConversionEngineProvider);
    final canonical = registry?.byId(widget.canonicalId);
    if (canonical == null) {
      setState(() => _errorMessage = 'ไม่พบวัตถุดิบในระบบ');
      return;
    }

    // Defensive re-check: if this canonical id is already in the pantry —
    // whether because the user reached this page before it was added
    // elsewhere, or a concurrent change — never create a silent duplicate.
    final alreadyOwned = ref
        .read(pantryProvider)
        .any((i) => i.canonicalIngredientId == canonical.id);
    if (alreadyOwned) {
      setState(() => _errorMessage = 'มีวัตถุดิบนี้ในคลังแล้ว');
      return;
    }

    final quantity = double.tryParse(_quantityController.text.trim());
    if (quantity == null || !quantity.isFinite || quantity <= 0) {
      setState(() => _errorMessage = 'กรุณาใส่จำนวนที่มากกว่า 0');
      return;
    }
    final resolvedUnitId = unitEngine.resolveUnitId(_unitId);
    if (resolvedUnitId == null) {
      setState(() => _errorMessage = 'หน่วยไม่ถูกต้อง กรุณาเลือกใหม่');
      return;
    }

    setState(() {
      _isCommitting = true;
      _errorMessage = null;
    });
    final now = DateTime.now();
    try {
      await ref.read(pantryProvider.notifier).addIngredientsBatch(<Ingredient>[
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
      ]);
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
    final registry = ref.watch(canonicalIngredientRegistryProvider);
    final unitEngine = ref.watch(unitConversionEngineProvider);
    final canonical = registry?.byId(widget.canonicalId);
    final breadcrumb = registry == null
        ? const <String>[]
        : registry
              .ancestorChainFor(widget.canonicalId)
              .map((id) => registry.byId(id)?.displayName() ?? id)
              .toList(growable: false);
    final unitOptions =
        (canonical != null && canonical.recommendedUnitIds.isNotEmpty)
        ? canonical.recommendedUnitIds
        : <String>[_unitId];

    return Scaffold(
      appBar: AppBar(title: const Text('เพิ่มวัตถุดิบ')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                canonical?.displayName() ?? widget.canonicalId,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (breadcrumb.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Text(
                    key: const ValueKey<String>(
                      'ingredient-quick-add-breadcrumb',
                    ),
                    <String>[
                      ...breadcrumb,
                      canonical?.displayName() ?? widget.canonicalId,
                    ].join(' › '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              if (_errorMessage != null)
                Container(
                  key: const ValueKey<String>('ingredient-quick-add-error'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey<String>(
                        'ingredient-quick-add-quantity',
                      ),
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'จำนวน'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  DropdownButton<String>(
                    key: const ValueKey<String>('ingredient-quick-add-unit'),
                    value: unitOptions.contains(_unitId)
                        ? _unitId
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
                        setState(() => _unitId = value);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey<String>('ingredient-quick-add-cancel'),
                  onPressed: _isCommitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('ยกเลิก'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const ValueKey<String>('ingredient-quick-add-commit'),
                  onPressed: _isCommitting ? null : _commit,
                  child: _isCommitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('เพิ่มเข้า Pantry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
