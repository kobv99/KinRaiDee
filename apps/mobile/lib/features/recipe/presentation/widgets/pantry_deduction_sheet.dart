import 'package:flutter/material.dart';

import '../../../../core/presentation/unit_presentation.dart';
import '../../domain/services/pantry_deduction_planner.dart';

class PantryDeductionSelection {
  const PantryDeductionSelection({
    required this.selectedLineKeys,
    required this.quantitiesByLineKey,
  });

  final Set<String> selectedLineKeys;
  final Map<String, double> quantitiesByLineKey;
}

class PantryDeductionSheet extends StatefulWidget {
  const PantryDeductionSheet({super.key, required this.plan});

  final PantryDeductionPlan plan;

  @override
  State<PantryDeductionSheet> createState() => _PantryDeductionSheetState();
}

class _PantryDeductionSheetState extends State<PantryDeductionSheet> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Set<String> _selectedKeys = <String>{};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    for (final line in widget.plan.lines) {
      _controllers[line.key] = TextEditingController(
        text: formatRecipeNumber(line.deductibleQuantity),
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
              '${line.ingredient.name} หักได้สูงสุด ${formatRecipeQuantity(line.deductibleQuantity, line.unit)}';
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
      PantryDeductionSelection(
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
                      RecipeInfoBox(
                        icon: Icons.info_outline_rounded,
                        text:
                            'เครื่องปรุง ${widget.plan.skippedStapleCount} รายการจะไม่ถูกหักอัตโนมัติ',
                      ),
                    ],
                    if (widget.plan.skippedUnavailableCount > 0) ...[
                      const SizedBox(height: 8),
                      RecipeInfoBox(
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
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
              title: Text(
                line.ingredient.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                line.isPartial
                    ? 'ต้องใช้ ${formatRecipeQuantity(line.targetQuantity, line.unit)} · ใน Pantry หักได้ ${formatRecipeQuantity(line.deductibleQuantity, line.unit)}'
                    : 'ต้องใช้ ${formatRecipeQuantity(line.targetQuantity, line.unit)}',
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
                          _controllers[line.key]?.text = formatRecipeNumber(
                            line.deductibleQuantity,
                          );
                        }
                      : null,
                  child: Text(
                    line.ingredient.required ? 'ตามสูตร' : 'ใช้ของเสริม',
                    style: TextStyle(color: colors.primary),
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

class RecipeInfoBox extends StatelessWidget {
  const RecipeInfoBox({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
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

String formatRecipeQuantity(double quantity, String unit) {
  final normalizedUnit = UnitPresentation.label(unit);
  if (normalizedUnit == 'กรัม' && quantity >= 1000) {
    return '${formatRecipeNumber(quantity / 1000)} กิโลกรัม';
  }
  if (normalizedUnit == 'มิลลิลิตร' && quantity >= 1000) {
    return '${formatRecipeNumber(quantity / 1000)} ลิตร';
  }
  return UnitPresentation.quantity(
    quantity,
    normalizedUnit,
    maximumFractionDigits: 2,
  );
}

String formatRecipeNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  if ((value * 10).roundToDouble() == value * 10) {
    return value.toStringAsFixed(1);
  }
  return value.toStringAsFixed(2);
}
