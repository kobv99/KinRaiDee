import '../../../../core/domain/ingredients/canonical_ingredient.dart';

enum IngredientNodeType { root, category, family, ingredient }

class IngredientHierarchyNode {
  IngredientHierarchyNode({
    required this.id,
    required this.parentId,
    required this.nodeType,
    required this.canonicalName,
    required this.localizedDisplayName,
    required List<String> aliases,
    required this.selectable,
    required this.sortOrder,
    this.canonicalIngredientId,
    this.emoji = '',
    List<IngredientHierarchyNode> children = const [],
  }) : aliases = List.unmodifiable(aliases),
       children = List.unmodifiable(children);

  final String id;
  final String? parentId;
  final IngredientNodeType nodeType;
  final String canonicalName;
  final String localizedDisplayName;
  final List<String> aliases;
  final bool selectable;
  final int sortOrder;
  final String? canonicalIngredientId;
  final String emoji;
  final List<IngredientHierarchyNode> children;

  IngredientHierarchyNode copyWith({List<IngredientHierarchyNode>? children}) {
    return IngredientHierarchyNode(
      id: id,
      parentId: parentId,
      nodeType: nodeType,
      canonicalName: canonicalName,
      localizedDisplayName: localizedDisplayName,
      aliases: aliases,
      selectable: selectable,
      sortOrder: sortOrder,
      canonicalIngredientId: canonicalIngredientId,
      emoji: emoji,
      children: children ?? this.children,
    );
  }

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    return normalized.isNotEmpty &&
        <String>[
          canonicalName,
          localizedDisplayName,
          ...aliases,
        ].any((value) => value.toLowerCase().contains(normalized));
  }
}

class IngredientHierarchySearchResult {
  const IngredientHierarchySearchResult({
    required this.ingredient,
    required this.path,
  });

  final IngredientHierarchyNode ingredient;
  final List<IngredientHierarchyNode> path;

  String get localizedPath =>
      path.map((node) => node.localizedDisplayName).join(' > ');
}

class IngredientHierarchy {
  IngredientHierarchy(this.root)
    : _byId = {for (final node in _flatten(root)) node.id: node};

  final IngredientHierarchyNode root;
  final Map<String, IngredientHierarchyNode> _byId;

  List<IngredientHierarchyNode> get topLevel => root.children;

  IngredientHierarchyNode? byId(String id) => _byId[id];

  List<IngredientHierarchySearchResult> search(String query) {
    final results = <IngredientHierarchySearchResult>[];
    for (final node in _byId.values) {
      if (!node.selectable || !node.matches(query)) {
        continue;
      }
      results.add(
        IngredientHierarchySearchResult(
          ingredient: node,
          path: pathTo(node.id),
        ),
      );
    }
    results.sort((a, b) => a.localizedPath.compareTo(b.localizedPath));
    return List.unmodifiable(results);
  }

  List<IngredientHierarchyNode> pathTo(String id) {
    final reversed = <IngredientHierarchyNode>[];
    IngredientHierarchyNode? current = _byId[id];
    while (current != null && current.nodeType != IngredientNodeType.root) {
      reversed.add(current);
      current = current.parentId == null ? null : _byId[current.parentId!];
    }
    return reversed.reversed.toList(growable: false);
  }

  static Iterable<IngredientHierarchyNode> _flatten(
    IngredientHierarchyNode node,
  ) sync* {
    yield node;
    for (final child in node.children) {
      yield* _flatten(child);
    }
  }
}

class IngredientHierarchySelection {
  const IngredientHierarchySelection({
    required this.node,
    required this.canonicalIngredient,
    required this.path,
  });

  final IngredientHierarchyNode node;
  final CanonicalIngredient canonicalIngredient;
  final String path;
}
