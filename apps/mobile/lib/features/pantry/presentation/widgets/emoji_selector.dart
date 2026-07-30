import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../data/ingredient_hierarchy_loader.dart';
import '../../domain/models/ingredient_hierarchy.dart';

typedef IngredientSelectedCallback =
    void Function(
      String category,
      String name,
      String emoji,
      String canonicalIngredientId,
    );

class EmojiSelector extends ConsumerStatefulWidget {
  const EmojiSelector({
    super.key,
    required this.onSelected,
    this.initialName,
    this.initialSearchQuery,
    this.loader,
    this.initialHierarchy,
  });

  final IngredientSelectedCallback onSelected;
  final String? initialName;
  final String? initialSearchQuery;
  final IngredientHierarchyLoader? loader;
  final IngredientHierarchy? initialHierarchy;

  @override
  ConsumerState<EmojiSelector> createState() => _EmojiSelectorState();
}

class _EmojiSelectorState extends ConsumerState<EmojiSelector> {
  late final TextEditingController _searchController;
  late Future<IngredientHierarchy> _hierarchy;
  final Set<String> _expandedNodeIds = <String>{};
  String? _selectedNodeId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.initialSearchQuery?.trim() ?? '';
    _searchController = TextEditingController(text: _query);
    _hierarchy = widget.initialHierarchy == null
        ? _load()
        : Future<IngredientHierarchy>.value(widget.initialHierarchy);
  }

  Future<IngredientHierarchy> _load() async {
    final registry = ref.read(canonicalIngredientRegistryProvider);
    if (registry == null) {
      throw StateError('Canonical ingredient registry is unavailable.');
    }
    final hierarchy = await (widget.loader ?? IngredientHierarchyLoader()).load(
      registry: registry,
    );
    final initialName = widget.initialName?.trim();
    if (initialName != null && initialName.isNotEmpty) {
      for (final result in hierarchy.search(initialName)) {
        if (result.ingredient.localizedDisplayName == initialName ||
            result.ingredient.canonicalIngredientId == initialName) {
          _selectedNodeId = result.ingredient.id;
          _expandedNodeIds.addAll(
            result.path
                .where((node) => !node.selectable)
                .map((node) => node.id),
          );
          break;
        }
      }
    }
    return hierarchy;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleExpanded(String id) {
    setState(() {
      if (!_expandedNodeIds.add(id)) {
        _expandedNodeIds.remove(id);
      }
    });
  }

  void _select(IngredientHierarchy hierarchy, IngredientHierarchyNode node) {
    if (!node.selectable || node.canonicalIngredientId == null) return;
    final registry = ref.read(canonicalIngredientRegistryProvider);
    final canonical = registry?.byId(node.canonicalIngredientId!);
    if (canonical == null) return;
    final path = hierarchy.pathTo(node.id);
    final category = path.length > 1
        ? path.first.localizedDisplayName
        : canonical.category;
    setState(() {
      _selectedNodeId = node.id;
    });
    widget.onSelected(
      category,
      canonical.displayName(),
      canonical.emoji,
      canonical.id,
    );
  }

  void _selectSearchResult(
    IngredientHierarchy hierarchy,
    IngredientHierarchySearchResult result,
  ) {
    setState(() {
      _query = '';
      _searchController.clear();
      _expandedNodeIds.addAll(
        result.path.where((node) => !node.selectable).map((node) => node.id),
      );
    });
    _select(hierarchy, result.ingredient);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IngredientHierarchy>(
      future: _hierarchy,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'ไม่สามารถโหลดรายการวัตถุดิบได้',
            key: const Key('ingredient-hierarchy-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        }
        final hierarchy = snapshot.data;
        if (hierarchy == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildSelector(context, hierarchy);
      },
    );
  }

  Widget _buildSelector(BuildContext context, IngredientHierarchy hierarchy) {
    final results = hierarchy.search(_query).take(20).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('ingredient-hierarchy-search'),
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            labelText: 'ค้นหาวัตถุดิบ',
            hintText: 'เช่น หมูสามชั้น น้ำปลา มะนาว',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'ล้างคำค้นหา',
                    onPressed: () => setState(() {
                      _query = '';
                      _searchController.clear();
                    }),
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        if (_query.trim().isNotEmpty)
          _buildSearchResults(context, hierarchy, results)
        else ...[
          Text(
            'เลือกตามหมวดหมู่',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          for (final category in hierarchy.topLevel)
            _TreeNodeRow(
              key: Key('ingredient-node-${category.id}'),
              node: category,
              depth: 0,
              expandedNodeIds: _expandedNodeIds,
              selectedNodeId: _selectedNodeId,
              onToggleExpanded: _toggleExpanded,
              onSelected: (node) => _select(hierarchy, node),
            ),
        ],
      ],
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    IngredientHierarchy hierarchy,
    List<IngredientHierarchySearchResult> results,
  ) {
    if (results.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        child: Text('ไม่พบ “$_query” ในรายการวัตถุดิบ'),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: results.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final result = results[index];
          return ListTile(
            key: Key('ingredient-search-${result.ingredient.id}'),
            dense: true,
            leading: Text(result.ingredient.emoji),
            title: Text(result.ingredient.localizedDisplayName),
            subtitle: Text(result.localizedPath),
            trailing: const Icon(Icons.add_circle_outline_rounded),
            onTap: () => _selectSearchResult(hierarchy, result),
          );
        },
      ),
    );
  }
}

class _TreeNodeRow extends StatelessWidget {
  const _TreeNodeRow({
    super.key,
    required this.node,
    required this.depth,
    required this.expandedNodeIds,
    required this.selectedNodeId,
    required this.onToggleExpanded,
    required this.onSelected,
  });

  final IngredientHierarchyNode node;
  final int depth;
  final Set<String> expandedNodeIds;
  final String? selectedNodeId;
  final ValueChanged<String> onToggleExpanded;
  final ValueChanged<IngredientHierarchyNode> onSelected;

  @override
  Widget build(BuildContext context) {
    final hasChildren = node.children.isNotEmpty;
    final expanded = expandedNodeIds.contains(node.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 20.0),
          child: Row(
            children: [
              if (hasChildren)
                IconButton(
                  key: Key('expand-${node.id}'),
                  tooltip: expanded ? 'ยุบ' : 'ขยาย',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onToggleExpanded(node.id),
                  icon: Icon(
                    expanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_right_rounded,
                  ),
                )
              else
                const SizedBox(width: 40),
              if (node.selectable)
                Checkbox(
                  key: Key('select-${node.id}'),
                  value: selectedNodeId == node.id,
                  onChanged: (_) => onSelected(node),
                )
              else
                Icon(
                  node.nodeType == IngredientNodeType.category
                      ? Icons.folder_outlined
                      : Icons.account_tree_outlined,
                  size: 20,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.localizedDisplayName,
                  key: Key('label-${node.id}'),
                ),
              ),
            ],
          ),
        ),
        if (hasChildren && expanded)
          for (final child in node.children)
            _TreeNodeRow(
              key: Key('ingredient-node-${child.id}'),
              node: child,
              depth: depth + 1,
              expandedNodeIds: expandedNodeIds,
              selectedNodeId: selectedNodeId,
              onToggleExpanded: onToggleExpanded,
              onSelected: onSelected,
            ),
      ],
    );
  }
}
