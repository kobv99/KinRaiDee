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
import '../../domain/entities/shopping_item_status.dart';
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
  _UndoAction? _lastUndo;

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
        title: const Text('Shopping'),
        actions: [
          IconButton(
            key: const ValueKey<String>('shopping-undo-action'),
            tooltip: 'Undo recent action',
            onPressed: _lastUndo == null || _isMutating
                ? null
                : () => _undo(_lastUndo!),
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            key: const ValueKey<String>('shopping-generate-action'),
            tooltip: 'Generate from recipes',
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
        title: 'Your shopping list is empty',
        description:
            'Choose recipes and KinRaiDee will combine what you need, '
            'then subtract what is already in your Pantry.',
        actionLabel: 'Generate from recipes',
        onActionPressed: () => _openGenerator(null),
      );
    }

    final list = _selectedList(lists)!;
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
    final purchasedCount = list.items
        .where((item) => item.status == ShoppingItemStatus.purchased)
        .length;
    final archivedCount = list.items
        .where((item) => item.status == ShoppingItemStatus.archived)
        .length;

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
                    list: list,
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
                if (projection.active.isNotEmpty)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      AppSpacing.lg,
                      horizontal,
                      AppSpacing.sm,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _SectionTitle(
                        title: 'Active items',
                        count: projection.active.length,
                      ),
                    ),
                  ),
                _itemSliver(
                  projection.active,
                  list,
                  projector,
                  pantry,
                  at,
                  recipeNames,
                  horizontal,
                ),
                if (projection.completed.isNotEmpty)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      AppSpacing.lg,
                      horizontal,
                      AppSpacing.sm,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _SectionTitle(
                        title: 'Completed items',
                        count: projection.completed.length,
                        action: purchasedCount > 0
                            ? TextButton.icon(
                                key: const ValueKey<String>(
                                  'shopping-archive-completed',
                                ),
                                onPressed: _isMutating
                                    ? null
                                    : () => _archiveCompleted(list),
                                icon: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 18,
                                ),
                                label: const Text('Archive completed'),
                              )
                            : archivedCount > 0
                            ? TextButton.icon(
                                key: const ValueKey<String>(
                                  'shopping-restore-archived',
                                ),
                                onPressed: _isMutating
                                    ? null
                                    : () => _restoreArchived(list),
                                icon: const Icon(Icons.restore, size: 18),
                                label: const Text('Restore archived'),
                              )
                            : null,
                      ),
                    ),
                  ),
                _itemSliver(
                  projection.completed,
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
    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
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
            onToggle: () => _toggle(list, item),
            onEdit: () => _editQuantity(list, item),
            onDelete: () => _deleteItem(list, item),
            onRestore: () => _restoreArchived(list),
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
    _showMessage('Shopping list generated without duplicate items.');
  }

  Future<void> _toggle(ShoppingList list, ShoppingItem item) async {
    final now = ref.read(appClockProvider).now();
    if (item.status == ShoppingItemStatus.active) {
      await _execute(
        label: '${item.displayName} purchased and added to Pantry.',
        itemId: item.id,
        command: ShoppingMutation.markPurchased(
          listId: list.id,
          expectedListRevision: list.revision,
          itemId: item.id,
          createdAt: now,
        ),
        undo: _UndoAction(
          label: 'Purchase undone.',
          listId: list.id,
          build: (current, createdAt) => ShoppingMutation.markUnpurchased(
            listId: current.id,
            expectedListRevision: current.revision,
            itemId: item.id,
            createdAt: createdAt,
          ),
        ),
      );
      return;
    }
    if (item.status == ShoppingItemStatus.purchased) {
      await _execute(
        label: '${item.displayName} moved back to active.',
        itemId: item.id,
        command: ShoppingMutation.markUnpurchased(
          listId: list.id,
          expectedListRevision: list.revision,
          itemId: item.id,
          createdAt: now,
        ),
        undo: _UndoAction(
          label: 'Item checked again.',
          listId: list.id,
          build: (current, createdAt) => ShoppingMutation.markPurchased(
            listId: current.id,
            expectedListRevision: current.revision,
            itemId: item.id,
            createdAt: createdAt,
          ),
        ),
      );
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
    await _execute(
      label: '${item.displayName} quantity updated.',
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
        label: 'Quantity restored.',
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
        title: const Text('Delete shopping item?'),
        content: Text(
          '${item.displayName} will be removed from this list. '
          'Your Pantry will not change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep item'),
          ),
          FilledButton(
            key: const ValueKey<String>('shopping-confirm-delete'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _execute(
      label: '${item.displayName} deleted.',
      itemId: item.id,
      command: ShoppingMutation.removeItem(
        listId: list.id,
        expectedListRevision: list.revision,
        itemId: item.id,
        createdAt: ref.read(appClockProvider).now(),
      ),
      undo: _UndoAction(
        label: '${item.displayName} restored.',
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

  Future<void> _archiveCompleted(ShoppingList list) async {
    await _execute(
      label: 'Completed items archived.',
      command: ShoppingMutation.archiveCompleted(
        listId: list.id,
        expectedListRevision: list.revision,
        createdAt: ref.read(appClockProvider).now(),
      ),
    );
  }

  Future<void> _restoreArchived(ShoppingList list) async {
    await _execute(
      label: 'Archived items restored.',
      command: ShoppingMutation.restoreArchived(
        listId: list.id,
        expectedListRevision: list.revision,
        createdAt: ref.read(appClockProvider).now(),
      ),
    );
  }

  Future<void> _execute({
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
      setState(() => _lastUndo = undo);
      _showMessage(label, undo: undo);
    } on Object {
      if (mounted) {
        _showError('The action failed safely. No partial change was shown.');
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

  Future<void> _undo(_UndoAction undo) async {
    setState(() => _isMutating = true);
    try {
      final lists = await ref.read(shoppingListsProvider.future);
      final current = lists.where((list) => list.id == undo.listId).firstOrNull;
      if (current == null) {
        if (mounted) {
          _showError('This list no longer exists, so the action cannot undo.');
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
      setState(() => _lastUndo = null);
      _showMessage(undo.label);
    } on Object {
      if (mounted) {
        _showError('Undo could not be completed safely.');
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

  void _showMessage(String message, {_UndoAction? undo}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: undo == null
            ? null
            : SnackBarAction(label: 'Undo', onPressed: () => _undo(undo)),
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
      title: Text('Edit ${widget.item.displayName}'),
      content: TextField(
        key: const ValueKey<String>('shopping-quantity-field'),
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Quantity',
          suffixText: shoppingUnitLabel(widget.item.unitId),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
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
          child: const Text('Save'),
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
    final active = list.items
        .where((item) => item.status == ShoppingItemStatus.active)
        .length;
    final completed = list.items.length - active;
    final progress = list.items.isEmpty ? 0.0 : completed / list.items.length;
    return AppCard(
      backgroundColor: AppColors.shopping.withValues(alpha: 0.08),
      borderColor: AppColors.shopping.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                            '$active active • $completed completed',
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
                label: const Text('Generate'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surface,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShoppingControls extends ConsumerWidget {
  const _ShoppingControls({
    required this.list,
    required this.view,
    required this.recipeNames,
    required this.searchController,
  });

  final ShoppingList list;
  final ShoppingViewState view;
  final Map<String, String> recipeNames;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewNotifier = ref.read(shoppingViewProvider.notifier);
    final categories = list.items.map((item) => item.category).toSet().toList()
      ..sort((first, second) => first.index.compareTo(second.index));
    final recipeIds =
        list.items.expand((item) => item.sourceReferenceIds).toSet().toList()
          ..sort(
            (first, second) => (recipeNames[first] ?? first).compareTo(
              recipeNames[second] ?? second,
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey<String>('shopping-search-field'),
          controller: searchController,
          onChanged: viewNotifier.setQuery,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search ingredients, aliases, or local names',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: view.query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      searchController.clear();
                      viewNotifier.setQuery('');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<ShoppingCompletionFilter>(
            key: const ValueKey<String>('shopping-completion-filter'),
            segments: const [
              ButtonSegment(
                value: ShoppingCompletionFilter.all,
                label: Text('All'),
              ),
              ButtonSegment(
                value: ShoppingCompletionFilter.active,
                label: Text('Active'),
              ),
              ButtonSegment(
                value: ShoppingCompletionFilter.completed,
                label: Text('Completed'),
              ),
            ],
            selected: <ShoppingCompletionFilter>{view.completion},
            onSelectionChanged: (values) =>
                viewNotifier.setCompletion(values.single),
            showSelectedIcon: false,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _FilterDropdown<ShoppingCategory?>(
              key: const ValueKey<String>('shopping-category-filter'),
              value: view.category,
              hint: 'All categories',
              items: <DropdownMenuItem<ShoppingCategory?>>[
                const DropdownMenuItem(
                  value: null,
                  child: Text('All categories'),
                ),
                ...categories.map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Text(shoppingCategoryLabel(category)),
                  ),
                ),
              ],
              onChanged: viewNotifier.setCategory,
            ),
            _FilterDropdown<String?>(
              key: const ValueKey<String>('shopping-recipe-filter'),
              value: view.recipeId,
              hint: 'All recipes',
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem(value: null, child: Text('All recipes')),
                ...recipeIds.map(
                  (id) => DropdownMenuItem(
                    value: id,
                    child: Text(recipeNames[id] ?? id),
                  ),
                ),
              ],
              onChanged: viewNotifier.setRecipe,
            ),
            _FilterDropdown<ShoppingSortOption>(
              key: const ValueKey<String>('shopping-sort'),
              value: view.sort,
              hint: 'Sort',
              items: const [
                DropdownMenuItem(
                  value: ShoppingSortOption.category,
                  child: Text('Category'),
                ),
                DropdownMenuItem(
                  value: ShoppingSortOption.alphabetical,
                  child: Text('Alphabetical'),
                ),
                DropdownMenuItem(
                  value: ShoppingSortOption.recipeSource,
                  child: Text('Recipe source'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  viewNotifier.setSort(value);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    super.key,
  });

  final T value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
        ),
        hint: Text(hint),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count, this.action});

  final String title;
  final int count;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text('$title  $count', style: AppTextStyles.titleLarge),
        ),
        ?action,
      ],
    );
  }
}

class _ShoppingLoadingState extends StatelessWidget {
  const _ShoppingLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        key: ValueKey<String>('shopping-loading-state'),
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: AppSpacing.md),
          Text('Loading your offline shopping list…'),
        ],
      ),
    );
  }
}

class _ShoppingErrorState extends StatelessWidget {
  const _ShoppingErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          key: const ValueKey<String>('shopping-error-state'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52, color: AppColors.error),
            const SizedBox(height: AppSpacing.sm),
            Text('Shopping list unavailable', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your local data was not changed. Try loading it again.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatchingItems extends StatelessWidget {
  const _NoMatchingItems({required this.hasFilters, required this.onClear});

  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
        const SizedBox(height: AppSpacing.sm),
        Text(
          hasFilters ? 'No items match these filters' : 'No items to show',
          style: AppTextStyles.titleMedium,
        ),
        if (hasFilters)
          TextButton(onPressed: onClear, child: const Text('Clear filters')),
      ],
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
  final ShoppingMutation Function(ShoppingList, DateTime) build;
}

String _friendlyTransactionError(InventoryTransactionResult result) {
  return switch (result.code) {
    'stale_inventory_revision' || 'stale_shopping_list_revision' =>
      'The list changed before this action finished. Refresh and try again.',
    'shopping_undo_panry_conflict' || 'shopping_undo_pantry_conflict' =>
      'Pantry changed after purchase, so undo was stopped to protect it.',
    'invalid_shopping_quantity' => 'Enter a quantity greater than zero.',
    'recovery_required' =>
      'Local recovery must finish before Shopping can change.',
    _ =>
      'The action failed safely (${result.code}). '
          'No partial change was shown.',
  };
}
