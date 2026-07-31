import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../../core/presentation/unit_presentation.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/models/cooking_history_entry.dart';
import '../../domain/models/pantry_quantity_transaction.dart';
import '../../domain/services/cooking_history_adjustment_planner.dart';
import '../providers/cooking_history_provider.dart';

class CookingHistoryPage extends ConsumerStatefulWidget {
  const CookingHistoryPage({super.key});

  @override
  ConsumerState<CookingHistoryPage> createState() => _CookingHistoryPageState();
}

class _CookingHistoryPageState extends ConsumerState<CookingHistoryPage> {
  String? _processingEntryId;
  bool _clearingHistory = false;

  Future<void> _deleteEntry(CookingHistoryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ลบประวัติรายการนี้?'),
        content: Text(
          'รายการ ${entry.recipeName} จะถูกลบออกจากประวัติ '
          'โดยจำนวนวัตถุดิบใน Pantry จะไม่เปลี่ยนแปลง',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('เก็บไว้'),
          ),
          FilledButton(
            key: const ValueKey<String>('history-confirm-delete'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ลบประวัติ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _processingEntryId = entry.id);
    try {
      await ref.read(pantryProvider.notifier).deleteHistoryEntry(entry.id);
      if (mounted) {
        _showRetentionMessage('ลบประวัติ ${entry.recipeName} แล้ว');
      }
    } on Object {
      if (mounted) {
        _showRetentionMessage(
          'ไม่สามารถลบประวัติได้ ข้อมูลเดิมยังคงปลอดภัย',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingEntryId = null);
      }
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ล้างประวัติทั้งหมด?'),
        content: const Text(
          'ประวัติการทำอาหารทั้งหมดจะถูกลบอย่างถาวร '
          'โดยจำนวนวัตถุดิบใน Pantry จะไม่เปลี่ยนแปลง',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            key: const ValueKey<String>('history-confirm-clear'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ล้างทั้งหมด'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _clearingHistory = true);
    try {
      await ref.read(pantryProvider.notifier).clearCookingHistory();
      if (mounted) {
        _showRetentionMessage('ล้างประวัติการทำอาหารทั้งหมดแล้ว');
      }
    } on Object {
      if (mounted) {
        _showRetentionMessage(
          'ไม่สามารถล้างประวัติได้ ข้อมูลเดิมยังคงปลอดภัย',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _clearingHistory = false);
      }
    }
  }

  void _showRetentionMessage(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _editEntry(CookingHistoryEntry entry) async {
    final quantities = await showModalBottomSheet<Map<String, double>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditConsumedQuantitySheet(entry: entry),
    );
    if (quantities == null || !mounted) {
      return;
    }

    await _applyAdjustment(
      entry: entry,
      consumedQuantities: quantities,
      kind: InventoryTransactionKind.adjustCookingHistory,
      successMessage: 'แก้ไขปริมาณที่ใช้จริงแล้ว',
    );
  }

  Future<void> _cancelEntry(CookingHistoryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ยกเลิกรายการทำอาหาร?'),
        content: Text(
          'ระบบจะคืนวัตถุดิบจาก ${entry.recipeName} กลับเข้า Pantry ตามจำนวนที่บันทึกไว้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ไม่ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ยืนยันคืนวัตถุดิบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final zeroQuantities = <String, double>{
      for (final change in entry.changes) change.ingredientId: 0,
    };
    await _applyAdjustment(
      entry: entry,
      consumedQuantities: zeroQuantities,
      kind: InventoryTransactionKind.cancelCookingHistory,
      successMessage: 'ยกเลิกรายการและคืนวัตถุดิบเข้า Pantry แล้ว',
    );
  }

  Future<void> _applyAdjustment({
    required CookingHistoryEntry entry,
    required Map<String, double> consumedQuantities,
    required InventoryTransactionKind kind,
    required String successMessage,
  }) async {
    setState(() {
      _processingEntryId = entry.id;
    });

    try {
      final pantry = ref.read(pantryProvider);
      final plan = const CookingHistoryAdjustmentPlanner().adjust(
        entry: entry,
        pantry: pantry,
        consumedQuantityByIngredientId: consumedQuantities,
      );

      await ref
          .read(pantryProvider.notifier)
          .applyHistoryAdjustment(plan: plan, kind: kind);

      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(successMessage),
          duration: const Duration(seconds: 4),
          showCloseIcon: true,
        ),
      );
    } on CookingHistoryAdjustmentException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ปรับปริมาณไม่ได้ กรุณาตรวจข้อมูลแล้วลองอีกครั้ง'),
          duration: Duration(seconds: 6),
          showCloseIcon: true,
        ),
      );
    } on Object {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ไม่สามารถบันทึกการเปลี่ยนแปลงได้ ข้อมูลเดิมยังคงปลอดภัย',
          ),
          duration: Duration(seconds: 6),
          showCloseIcon: true,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingEntryId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(cookingHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติการทำอาหาร'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              key: const ValueKey<String>('history-clear-all'),
              tooltip: 'ล้างประวัติทั้งหมด',
              onPressed: _clearingHistory || _processingEntryId != null
                  ? null
                  : _clearHistory,
              icon: _clearingHistory
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: history.isEmpty
          ? const _EmptyHistoryView()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: history.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = history[index];
                return _HistoryCard(
                  entry: entry,
                  processing: _processingEntryId == entry.id,
                  onEdit: () => _editEntry(entry),
                  onCancel: () => _cancelEntry(entry),
                  onDelete: () => _deleteEntry(entry),
                );
              },
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.entry,
    required this.processing,
    required this.onEdit,
    required this.onCancel,
    required this.onDelete,
  });

  final CookingHistoryEntry entry;
  final bool processing;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: entry.isCancelled
                      ? colors.surfaceContainerHighest
                      : colors.primaryContainer,
                  child: Icon(
                    entry.isCancelled
                        ? Icons.undo_rounded
                        : Icons.soup_kitchen_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.recipeName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_formatDateTime(entry.createdAt)} · ${entry.servings} คน',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HistoryStatusChip(status: entry.status),
                    IconButton(
                      key: ValueKey<String>('history-delete-${entry.id}'),
                      tooltip: 'ลบประวัติรายการนี้',
                      onPressed: processing ? null : onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...entry.changes.map(
              (change) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Expanded(child: Text(change.ingredientName)),
                    Text(
                      entry.isCancelled
                          ? 'คืนแล้ว ${_formatQuantity(change.originalConsumedQuantity, change.unit)}'
                          : 'ใช้ ${_formatQuantity(change.consumedQuantity, change.unit)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: entry.isCancelled
                            ? colors.onSurfaceVariant
                            : colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (entry.status == CookingHistoryStatus.adjusted) ...[
              const SizedBox(height: 4),
              Text(
                'แก้ไขล่าสุด ${_formatDateTime(entry.updatedAt)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
            if (entry.canEdit) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: processing ? null : onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('แก้ไขปริมาณ'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: processing ? null : onCancel,
                      icon: processing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.undo_rounded),
                      label: const Text('ยกเลิกรายการ'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
    );
  }
}

class _HistoryStatusChip extends StatelessWidget {
  const _HistoryStatusChip({required this.status});

  final CookingHistoryStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, icon, background, foreground) = switch (status) {
      CookingHistoryStatus.completed => (
        'สำเร็จ',
        Icons.check_circle_outline,
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      CookingHistoryStatus.adjusted => (
        'แก้ไขแล้ว',
        Icons.tune_rounded,
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      CookingHistoryStatus.cancelled => (
        'ยกเลิกแล้ว',
        Icons.undo_rounded,
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditConsumedQuantitySheet extends StatefulWidget {
  const _EditConsumedQuantitySheet({required this.entry});

  final CookingHistoryEntry entry;

  @override
  State<_EditConsumedQuantitySheet> createState() =>
      _EditConsumedQuantitySheetState();
}

class _EditConsumedQuantitySheetState
    extends State<_EditConsumedQuantitySheet> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    for (final change in widget.entry.changes) {
      _controllers[change.ingredientId] = TextEditingController(
        text: _formatNumber(change.consumedQuantity),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final quantities = <String, double>{};
    for (final change in widget.entry.changes) {
      final raw = _controllers[change.ingredientId]?.text.trim() ?? '';
      final quantity = double.tryParse(raw.replaceAll(',', '.'));
      if (quantity == null ||
          quantity < 0 ||
          quantity > change.beforeQuantity + 0.000001) {
        setState(() {
          _errorMessage =
              '${change.ingredientName} ต้องอยู่ระหว่าง 0 ถึง ${_formatQuantity(change.beforeQuantity, change.unit)}';
        });
        return;
      }
      quantities[change.ingredientId] = quantity;
    }

    Navigator.of(context).pop(Map<String, double>.unmodifiable(quantities));
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final colors = Theme.of(context).colorScheme;

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
                      'แก้ไขปริมาณที่ใช้จริง',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.entry.recipeName} · ${widget.entry.servings} คน',
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  children: [
                    ...widget.entry.changes.map(
                      (change) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: _controllers[change.ingredientId],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: change.ingredientName,
                            helperText:
                                'บันทึกเดิม ${_formatQuantity(change.consumedQuantity, change.unit)}',
                            suffixText: UnitPresentation.label(
                              change.canonicalUnitId.isEmpty
                                  ? change.unit
                                  : change.canonicalUnitId,
                            ),
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
                    ),
                    if (_errorMessage != null)
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: colors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                        onPressed: _submit,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('บันทึกและปรับ Pantry'),
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
}

class _EmptyHistoryView extends StatelessWidget {
  const _EmptyHistoryView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded, size: 64),
            const SizedBox(height: 14),
            Text(
              'ยังไม่มีประวัติการทำอาหาร',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'เมื่อทำเมนูเสร็จและหักวัตถุดิบ ระบบจะเก็บรายการไว้ให้แก้ไขย้อนหลัง',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year;
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

String _formatQuantity(double value, String unit) {
  return UnitPresentation.quantity(value, unit, maximumFractionDigits: 2);
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
