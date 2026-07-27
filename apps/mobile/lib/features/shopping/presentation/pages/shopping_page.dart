import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/models/ingredient.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../pantry/application/inventory_transaction_coordinator.dart';
import '../../../pantry/application/inventory_transaction_providers.dart';
import '../../../recipe/domain/entities/recipe.dart';
import '../../../recipe/presentation/providers/recipe_provider.dart';
import '../../application/shopping_providers.dart';
import '../../domain/entities/shopping_category.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/entities/shopping_list.dart';
import '../../domain/models/shopping_mutation.dart';
import '../providers/shopping_view_provider.dart';
import '../widgets/shopping_generation_sheet.dart';
import '../widgets/shopping_item_card.dart';

class ShoppingPage extends ConsumerStatefulWidget {
  const ShoppingPage({super.key});

  @override
  ConsumerState<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends ConsumerState<ShoppingPage> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedListId;
  String? _busyItemId;
  bool _isMutating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(shoppingListsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการซื้อของ'),
        actions: [
          IconButton(
            key: const ValueKey<String>('shopping-generate-action'),
            tooltip: 'สร้างรายการจากเมนู',
            onPressed: _isMutating
                ? null
                : () => _openGenerator(_selectedList(lists.value)),
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: [
          if (_isMutating)
            const LinearProgressIndicator(
              key: ValueKey<String>('shopping-mutation-progress'),
              minHeight: 2,
            ),
          Expanded(
            child: lists.when(
              data: _buildContent,
              loading: () => const _ShoppingLoadingState(),
              error: (error, stackTrace) => _ShoppingErrorState(
                onRetry: () => ref.invalidate(shoppingListsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<ShoppingList> lists) {
    if (lists.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_basket_outlined,
        title: 'ยังไม่มีรายการซื้อของ',
        description:
            'เลือกเมนูที่ต้องการ แล้ว KinRaiDee จะรวมวัตถุดิบและหักจำนวน'
            'ที่มีอยู่ใน Pantry ให้อัตโนมัติ',
        actionLabel: 'สร้างรายการจากเมนู',
        onActionPressed: () => _openGenerator(null),
      );
    }

    final list = _selectedList(lists)!;
    if (list.items.isEmpty) {
      return EmptyState(
        key: const ValueKey<String>('shopping-complete-empty-state'),
        icon: Icons.celebration_outlined,
        title: '🎉 ไม่มีรายการที่ต้องซื้อแล้ว',
        description: 'พร้อมทำอาหารได้เลย',
        actionLabel: 'สร้างรายการใหม่',
        onActionPressed: () => _openGenerator(list),
      );
    }

    final view = ref.watch(shoppingViewProvider);
    final recipes = ref.watch(recipesProvider).value ?? const <Recipe>[];
    final recipeNames = <String, String>{
      for (final recipe in recipes) recipe.id: recipe.name,
    };
    final projector = ShoppingViewProjector(
      registry: ref.watch(canonicalIngredientRegistryProvider),
      unitEngine: ref.watch(unitConversionEngineProvider),
    );
    final projection = projector.project(
      list.items,
      view,
      recipeNames: recipeNames,
    );
    final pantry = ref.watch(pantryProvider);
    final at = ref.watch(appClockProvider).now().toUtc();

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth > 920
            ? (constraints.maxWidth - 880) / 2
            : AppSpacing.md;
        return RefreshIndicator(
          onRefresh: () => ref.refresh(shoppingListsProvider.future),
          child: CustomScrollView(
            key: const ValueKey<String>('shopping-list-scroll'),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  AppSpacing.sm,
                  horizontal,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _ShoppingOverview(
                    list: list,
                    lists: lists,
                    selectedListId: list.id,
                    onListChanged: (value) =>
                        setState(() => _selectedListId = value),
                    onGenerate: () => _openGenerator(list),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  AppSpacing.md,
                  horizontal,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _ShoppingControls(
                    view: view,
                    recipeNames: recipeNames,
                    searchController: _searchController,
                  ),
                ),
              ),
              if (projection.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    AppSpacing.xl,
                    horizontal,
                    AppSpacing.xl,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _NoMatchingItems(
                      hasFilters: view.hasFilters,
                      onClear: _clearFilters,
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    AppSpacing.lg,
                    horizontal,
                    AppSpacing.sm,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _SectionTitle(
                      title: 'รายการที่ต้องซื้อ',
                      count: projection.items.length,
                    ),
                  ),
                ),
                _itemSliver(
                  projection.items,
                  list,
                  projector,
                  pantry,
                  at,
                  recipeNames,
                  horizontal,
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            ],
          ),
        );
      },
    );
  }

  Widget _itemSliver(
    List<ShoppingItem> items,
    ShoppingList list,
    ShoppingViewProjector projector,
    List<Ingredient> pantry,
    DateTime at,
    Map<String, String> recipeNames,
    double horizontal,
  ) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontal),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final item = items[index];
          return ShoppingItemCard(
            item: item,
            pantryAvailability: projector.pantryAvailability(
              item,
              pantry,
              at: at,
            ),
            recipeNames: recipeNames,
            isBusy: _isMutating || _busyItemId == item.id,
            onComplete: () => _completeItem(list, item),
            onEdit: () => _editQuantity(list, item),
            onDelete: () => _deleteItem(list, item),
          );
        },
      ),
    );
  }

  ShoppingList? _selectedList(List<ShoppingList>? lists) {
    if (lists == null || lists.isEmpty) {
      return null;
    }
    return lists.where((list) => list.id == _selectedListId).firstOrNull ??
        lists.first;
  }

  Future<void> _openGenerator(ShoppingList? existingList) async {
    final generated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: ShoppingGenerationSheet(existingList: existingList),
      ),
    );
    if (!mounted || generated != true) {
      return;
    }
    _showMessage('สร้างรายการซื้อของแล้ว โดยไม่มีรายการซ้ำ');
  }

  Future<void> _completeItem(ShoppingList list, ShoppingItem item) async {
    setState(() {
      _isMutating = true;
      _busyItemId = item.id;
    });
    try {
      final result = await ref
          .read(shoppingCompletionControllerProvider)
          .complete(
            listId: list.id,
            expectedListRevision: list.revision,
            itemId: item.id,
            createdAt: ref.read(appClockProvider).now(),
          );
      if (!mounted) {
        return;
      }
      if (!result.isSuccess) {
        _showError(_friendlyTransactionError(result));
        return;
      }
      final purchaseTransactionId = result.transaction?.transactionId;
      _showMessage(
        '✓ เพิ่มเข้าตู้แล้ว',
        duration: const Duration(seconds: 7),
        onUndo: purchaseTransactionId == null || purchaseTransactionId.isEmpty
            ? null
            : () => _undoCompletion(purchaseTransactionId),
      );
    } on Object {
      if (mounted) {
        _showError('ทำรายการไม่สำเร็จ ข้อมูลเดิมยังคงปลอดภัย');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
          _busyItemId = null;
        });
      }
    }
  }

  Future<void> _undoCompletion(String purchaseTransactionId) async {
    setState(() => _isMutating = true);
    try {
      final result = await ref
          .read(shoppingCompletionControllerProvider)
          .undo(
            purchaseTransactionId: purchaseTransactionId,
            createdAt: ref.read(appClockProvider).now(),
          );
      if (!mounted) {
        return;
      }
      if (!result.isSuccess) {
        _showError(_friendlyTransactionError(result));
        return;
      }
      _showMessage('คืนรายการและจำนวนใน Pantry แล้ว');
    } on Object {
      if (mounted) {
        _showError('ไม่สามารถย้อนกลับรายการได้อย่างปลอดภัย');
      }
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  Future<void> _editQuantity(ShoppingList list, ShoppingItem item) async {
    final quantity = await showDialog<double>(
      context: context,
      builder: (context) => _QuantityDialog(item: item),
    );
    if (quantity == null || quantity == item.quantity || !mounted) {
      return;
    }
    await _executeMutation(
      label: 'แก้ไขจำนวน ${item.displayName} แล้ว',
      itemId: item.id,
      command: ShoppingMutation.updateQuantity(
        listId: list.id,
        expectedListRevision: list.revision,
        itemId: item.id,
        quantity: quantity,
        unitId: item.unitId,
        createdAt: ref.read(appClockProvider).now(),
      ),
      undo: _UndoAction(
        label: 'คืนค่าจำนวนเดิมแล้ว',
        listId: list.id,
        build: (current, createdAt) => ShoppingMutation.updateQuantity(
          listId: current.id,
          expectedListRevision: current.revision,
          itemId: item.id,
          quantity: item.quantity,
          unitId: item.unitId,
          createdAt: createdAt,
        ),
      ),
    );
  }

  Future<void> _deleteItem(ShoppingList list, ShoppingItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบรายการนี้?'),
        content: Text(
          '${item.displayName} จะถูกลบออกจากรายการซื้อของ '
          'โดยจำนวนใน Pantry จะไม่เปลี่ยนแปลง',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('เก็บไว้'),
          ),
          FilledButton(
            key: const ValueKey<String>('shopping-confirm-delete'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _executeMutation(
      label: 'ลบ ${item.displayName} แล้ว',
      itemId: item.id,
      command: ShoppingMutation.removeItem(
        listId: list.id,
        expectedListRevision: list.revision,
        itemId: item.id,
        createdAt: ref.read(appClockProvider).now(),
      ),
      undo: _UndoAction(
        label: 'กู้คืน ${item.displayName} แล้ว',
        listId: list.id,
        build: (current, createdAt) => ShoppingMutation.addItem(
          listId: current.id,
          expectedListRevision: current.revision,
          item: item,
          createdAt: createdAt,
        ),
      ),
    );
  }

  Future<void> _executeMutation({
    required String label,
    required ShoppingMutation command,
    String? itemId,
    _UndoAction? undo,
  }) async {
    setState(() {
      _isMutating = true;
      _busyItemId = itemId;
    });
    try {
      final result = await ref
          .read(shoppingMutationControllerProvider)
          .execute(command);
      if (!mounted) {
        return;
      }
      if (!result.isSuccess) {
        _showError(_friendlyTransactionError(result));
        return;
      }
      _showMessage(
        label,
        onUndo: undo == null ? null : () => _undoMutation(undo),
      );
    } on Object {
      if (mounted) {
        _showError('ทำรายการไม่สำเร็จ ข้อมูลเดิมยังคงปลอดภัย');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
          _busyItemId = null;
        });
      }
    }
  }

  Future<void> _undoMutation(_UndoAction undo) async {
    setState(() => _isMutating = true);
    try {
      final lists = await ref.read(shoppingListsProvider.future);
      final current = lists.where((list) => list.id == undo.listId).firstOrNull;
      if (current == null) {
        if (mounted) {
          _showError('รายการนี้ไม่มีอยู่แล้ว จึงไม่สามารถย้อนกลับได้');
        }
        return;
      }
      final result = await ref
          .read(shoppingMutationControllerProvider)
          .execute(undo.build(current, ref.read(appClockProvider).now()));
      if (!mounted) {
        return;
      }
      if (!result.isSuccess) {
        _showError(_friendlyTransactionError(result));
        return;
      }
      _showMessage(undo.label);
    } on Object {
      if (mounted) {
        _showError('ไม่สามารถย้อนกลับรายการได้อย่างปลอดภัย');
      }
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  void _clearFilters() {
    _searchController.clear();
    ref.read(shoppingViewProvider.notifier).clear();
  }

  void _showMessage(
    String message, {
    VoidCallback? onUndo,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: onUndo == null
            ? null
            : SnackBarAction(label: 'ย้อนกลับ', onPressed: onUndo),
      ),
    );
  }

  void _showError(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        showCloseIcon: true,
      ),
    );
  }
}

class _UndoAction {
  const _UndoAction({
    required this.label,
    required this.listId,
    required this.build,
  });

  final String label;
  final String listId;
  final ShoppingMutation Function(ShoppingList list, DateTime createdAt) build;
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.item});

  final ShoppingItem item;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: formatShoppingQuantity(widget.item.quantity),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('แก้ไข ${widget.item.displayName}'),
      content: TextField(
        key: const ValueKey<String>('shopping-quantity-field'),
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'จำนวน',
          suffixText: shoppingUnitLabel(widget.item.unitId),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          key: const ValueKey<String>('shopping-save-quantity'),
          onPressed: () {
            final value = double.tryParse(_controller.text.trim());
            if (value == null || !value.isFinite || value <= 0) {
              return;
            }
            Navigator.of(context).pop(value);
          },
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}

class _ShoppingOverview extends StatelessWidget {
  const _ShoppingOverview({
    required this.list,
    required this.lists,
    required this.selectedListId,
    required this.onListChanged,
    required this.onGenerate,
  });

  final ShoppingList list;
  final List<ShoppingList> lists;
  final String selectedListId;
  final ValueChanged<String> onListChanged;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.shopping.withValues(alpha: 0.08),
      borderColor: AppColors.shopping.withValues(alpha: 0.2),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.shopping,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_basket_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: lists.length == 1
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(list.name, style: AppTextStyles.titleLarge),
                      Text(
                        'ต้องซื้อ ${list.items.length} รายการ',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedListId,
                      isExpanded: true,
                      items: lists
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value.id,
                              child: Text(value.name),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          onListChanged(value);
                        }
                      },
                    ),
                  ),
          ),
          FilledButton.icon(
            key: const ValueKey<String>('shopping-generate-button'),
            onPressed: onGenerate,
            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: const Text('สร้างรายการ'),
          ),
        ],
      ),
    );
  }
}

class _ShoppingControls extends ConsumerWidget {
  const _ShoppingControls({
    required this.view,
    required this.recipeNames,
    required this.searchController,
  });

  final ShoppingViewState view;
  final Map<String, String> recipeNames;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(shoppingViewProvider.notifier);
    final recipes = recipeNames.entries.toList()
      ..sort((first, second) => first.value.compareTo(second.value));
    return AppCard(
      child: Column(
        children: [
          TextField(
            key: const ValueKey<String>('shopping-search-field'),
            controller: searchController,
            onChanged: notifier.setQuery,
            decoration: InputDecoration(
              labelText: 'ค้นหารายการ',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: view.query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'ล้างคำค้น',
                      onPressed: () {
                        searchController.clear();
                        notifier.setQuery('');
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<ShoppingCategory?>(
                  key: const ValueKey<String>('shopping-category-filter'),
                  initialValue: view.category,
                  decoration: const InputDecoration(labelText: 'หมวดหมู่'),
                  items: <DropdownMenuItem<ShoppingCategory?>>[
                    const DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                    ...ShoppingCategory.values.map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(shoppingCategoryLabel(category)),
                      ),
                    ),
                  ],
                  onChanged: notifier.setCategory,
                ),
              ),
              if (recipes.isNotEmpty)
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String?>(
                    key: const ValueKey<String>('shopping-recipe-filter'),
                    initialValue: view.recipeId,
                    decoration: const InputDecoration(labelText: 'จากเมนู'),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem(
                        value: null,
                        child: Text('ทุกเมนู'),
                      ),
                      ...recipes.map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      ),
                    ],
                    onChanged: notifier.setRecipe,
                  ),
                ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<ShoppingSortOption>(
                  key: const ValueKey<String>('shopping-sort-filter'),
                  initialValue: view.sort,
                  decoration: const InputDecoration(labelText: 'เรียงตาม'),
                  items: const [
                    DropdownMenuItem(
                      value: ShoppingSortOption.category,
                      child: Text('หมวดหมู่'),
                    ),
                    DropdownMenuItem(
                      value: ShoppingSortOption.alphabetical,
                      child: Text('ชื่อ'),
                    ),
                    DropdownMenuItem(
                      value: ShoppingSortOption.recipeSource,
                      child: Text('เมนูต้นทาง'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      notifier.setSort(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTextStyles.titleLarge)),
        Text('$count รายการ', style: AppTextStyles.bodyMedium),
      ],
    );
  }
}

class _NoMatchingItems extends StatelessWidget {
  const _NoMatchingItems({
    required this.hasFilters,
    required this.onClear,
  });

  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.filter_alt_off_outlined,
      title: 'ไม่พบรายการตามตัวกรอง',
      description: 'ลองเปลี่ยนคำค้น หมวดหมู่ หรือเมนูต้นทาง',
      actionLabel: hasFilters ? 'ล้างตัวกรอง' : null,
      onActionPressed: hasFilters ? onClear : null,
    );
  }
}

class _ShoppingLoadingState extends StatelessWidget {
  const _ShoppingLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: ValueKey<String>('shopping-loading-state'),
      child: CircularProgressIndicator(),
    );
  }
}

class _ShoppingErrorState extends StatelessWidget {
  const _ShoppingErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      key: const ValueKey<String>('shopping-error-state'),
      icon: Icons.cloud_off_outlined,
      title: 'เปิดรายการซื้อของไม่ได้',
      description: 'ข้อมูลในเครื่องยังคงปลอดภัย กรุณาลองโหลดอีกครั้ง',
      actionLabel: 'ลองอีกครั้ง',
      onActionPressed: onRetry,
    );
  }
}

String _friendlyTransactionError(InventoryTransactionResult result) {
  return switch (result.code) {
    'shopping_unit_conversion_required' =>
      'หน่วยของรายการนี้ยังรวมกับ Pantry ไม่ได้ กรุณาแปลงหน่วยก่อน',
    'unknown_canonical_shopping_ingredient' =>
      'ไม่พบวัตถุดิบมาตรฐานของรายการนี้ จึงยังเก็บเข้าตู้ไม่ได้',
    'stale_shopping_list_revision' || 'stale_inventory_revision' =>
      'รายการมีการเปลี่ยนแปลง กรุณาลองใหม่อีกครั้ง',
    'purchase_pantry_state_changed' =>
      'Pantry ถูกแก้ไขหลังการซื้อ จึงย้อนกลับอัตโนมัติไม่ได้',
    'shopping_item_already_recreated' =>
      'รายการนี้ถูกสร้างขึ้นใหม่แล้ว จึงย้อนกลับซ้ำไม่ได้',
    _ => 'ทำรายการไม่สำเร็จอย่างปลอดภัย (${result.code})',
  };
}
