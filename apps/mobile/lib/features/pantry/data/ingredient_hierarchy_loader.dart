import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/domain/ingredients/canonical_ingredient.dart';
import '../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../domain/models/ingredient_hierarchy.dart';

class IngredientHierarchyLoader {
  IngredientHierarchyLoader({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<IngredientHierarchy> load({
    required CanonicalIngredientRegistry registry,
    String assetPath = 'assets/ingredients/ingredient_hierarchy.json',
  }) async {
    final source = jsonDecode(await _bundle.loadString(assetPath));
    if (source is! Map<String, dynamic>) {
      throw const FormatException('Ingredient hierarchy must be an object.');
    }

    final rootData = _map(source['root'], 'root');
    final categories = _list(source['categories'], 'categories');
    final families = _list(source['families'], 'families');
    final assigned = <String>{};

    final familyNodes = <String, List<IngredientHierarchyNode>>{};
    for (final family in families) {
      final familyId = _requiredString(family, 'id');
      final members = _strings(family['memberIds']);
      assigned.addAll(members);
      final genericId = family['genericCanonicalId']?.toString();
      final children = <IngredientHierarchyNode>[];
      for (final memberId in members) {
        final ingredient = registry.byId(memberId);
        if (ingredient == null) {
          continue;
        }
        children.add(
          _ingredientNode(
            ingredient,
            parentId: familyId,
            id: memberId == genericId ? 'general_$memberId' : memberId,
            displayName: memberId == genericId
                ? family['genericLocalizedDisplayName']?.toString()
                : null,
          ),
        );
      }
      familyNodes
          .putIfAbsent(
            _requiredString(family, 'parentId'),
            () => <IngredientHierarchyNode>[],
          )
          .add(_configuredNode(family, children: children));
    }

    final categoryNodes = <IngredientHierarchyNode>[];
    for (final category in categories) {
      final id = _requiredString(category, 'id');
      final included = _strings(category['includeIds']).toSet();
      final sourceCategories = _strings(category['sourceCategories']).toSet();
      final excluded = _strings(category['excludeIds']).toSet();
      final children = <IngredientHierarchyNode>[...?familyNodes[id]];
      for (final ingredient in registry.ingredients) {
        final explicitlyIncluded = included.contains(ingredient.id);
        final categoryIncluded = sourceCategories.contains(ingredient.category);
        if (assigned.contains(ingredient.id) ||
            excluded.contains(ingredient.id) ||
            (!explicitlyIncluded && !categoryIncluded)) {
          continue;
        }
        assigned.add(ingredient.id);
        children.add(_ingredientNode(ingredient, parentId: id));
      }
      children.sort(_compareNodes);
      categoryNodes.add(_configuredNode(category, children: children));
    }
    categoryNodes.sort(_compareNodes);

    final root = _configuredNode(rootData, children: categoryNodes);
    _validate(root, registry);
    return IngredientHierarchy(root);
  }

  IngredientHierarchyNode _ingredientNode(
    CanonicalIngredient ingredient, {
    required String parentId,
    String? id,
    String? displayName,
  }) {
    return IngredientHierarchyNode(
      id: id ?? ingredient.id,
      parentId: parentId,
      nodeType: IngredientNodeType.ingredient,
      canonicalName: ingredient.canonicalName,
      localizedDisplayName: displayName ?? ingredient.displayName(),
      aliases: ingredient.aliases,
      selectable: true,
      sortOrder: 100,
      canonicalIngredientId: ingredient.id,
      emoji: ingredient.emoji,
    );
  }

  IngredientHierarchyNode _configuredNode(
    Map<String, dynamic> data, {
    required List<IngredientHierarchyNode> children,
  }) {
    return IngredientHierarchyNode(
      id: _requiredString(data, 'id'),
      parentId: data['parentId']?.toString(),
      nodeType: IngredientNodeType.values.byName(
        _requiredString(data, 'nodeType'),
      ),
      canonicalName: _requiredString(data, 'canonicalName'),
      localizedDisplayName: _requiredString(data, 'localizedDisplayName'),
      aliases: _strings(data['aliases']),
      selectable: data['selectable'] == true,
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      children: children,
    );
  }

  void _validate(
    IngredientHierarchyNode root,
    CanonicalIngredientRegistry registry,
  ) {
    final ids = <String>{};
    void visit(IngredientHierarchyNode node) {
      if (!ids.add(node.id)) {
        throw FormatException('Duplicate hierarchy node: ${node.id}');
      }
      if (node.selectable != (node.nodeType == IngredientNodeType.ingredient)) {
        throw FormatException('Invalid selectable node: ${node.id}');
      }
      if (node.selectable &&
          registry.byId(node.canonicalIngredientId ?? '') == null) {
        throw FormatException('Invalid canonical leaf: ${node.id}');
      }
      for (final child in node.children) {
        if (child.parentId != node.id) {
          throw FormatException('Invalid parent for ${child.id}');
        }
        visit(child);
      }
    }

    visit(root);
  }

  static int _compareNodes(
    IngredientHierarchyNode a,
    IngredientHierarchyNode b,
  ) {
    final order = a.sortOrder.compareTo(b.sortOrder);
    return order != 0
        ? order
        : a.localizedDisplayName.compareTo(b.localizedDisplayName);
  }

  static Map<String, dynamic> _map(Object? value, String field) {
    if (value is Map<String, dynamic>) return value;
    throw FormatException('$field must be an object.');
  }

  static List<Map<String, dynamic>> _list(Object? value, String field) {
    if (value is! List) throw FormatException('$field must be a list.');
    return value.map((entry) => _map(entry, field)).toList(growable: false);
  }

  static String _requiredString(Map<String, dynamic> data, String field) {
    final value = data[field]?.toString().trim() ?? '';
    if (value.isEmpty) throw FormatException('$field is required.');
    return value;
  }

  static List<String> _strings(Object? value) {
    if (value is! List) return const [];
    return value.map((entry) => entry.toString()).toList(growable: false);
  }
}
