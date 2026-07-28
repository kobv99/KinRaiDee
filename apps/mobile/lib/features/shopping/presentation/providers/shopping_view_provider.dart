import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../../../../core/domain/units/unit_contract.dart';
import '../../../../core/models/ingredient.dart';
import '../../../../core/presentation/unit_presentation.dart';
import '../../domain/entities/shopping_category.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/entities/shopping_item_status.dart';

enum ShoppingSortOption { category, alphabetical, recipeSource }

class ShoppingViewState {
  const ShoppingViewState({
    this.query = '',
    this.sort = ShoppingSortOption.category,
    this.category,
    this.recipeId,
  });

  final String query;
  final ShoppingSortOption sort;
  final ShoppingCategory? category;
  final String? recipeId;

  bool get hasFilters =>
      query.trim().isNotEmpty || category != null || recipeId != null;

  ShoppingViewState copyWith({
    String? query,
    ShoppingSortOption? sort,
    ShoppingCategory? category,
    String? recipeId,
    bool clearCategory = false,
    bool clearRecipe = false,
  }) {
    return ShoppingViewState(
      query: query ?? this.query,
      sort: sort ?? this.sort,
      category: clearCategory ? null : category ?? this.category,
      recipeId: clearRecipe ? null : recipeId ?? this.recipeId,
    );
  }
}

class ShoppingViewNotifier extends Notifier<ShoppingViewState> {
  @override
  ShoppingViewState build() => const ShoppingViewState();

  void setQuery(String value) => state = state.copyWith(query: value);

  void setSort(ShoppingSortOption value) => state = state.copyWith(sort: value);

  void setCategory(ShoppingCategory? value) {
    state = state.copyWith(category: value, clearCategory: value == null);
  }

  void setRecipe(String? value) {
    state = state.copyWith(recipeId: value, clearRecipe: value == null);
  }

  void clear() => state = const ShoppingViewState();
}

final shoppingViewProvider =
    NotifierProvider<ShoppingViewNotifier, ShoppingViewState>(
      ShoppingViewNotifier.new,
    );

class ShoppingViewProjection {
  const ShoppingViewProjection({required this.items});

  final List<ShoppingItem> items;

  bool get isEmpty => items.isEmpty;
}

class ShoppingViewProjector {
  const ShoppingViewProjector({
    required this.registry,
    required this.unitEngine,
  });

  final CanonicalIngredientRegistry? registry;
  final UnitConversionEngine unitEngine;

  ShoppingViewProjection project(
    Iterable<ShoppingItem> items,
    ShoppingViewState view, {
    Map<String, String> recipeNames = const <String, String>{},
  }) {
    final query = normalizeIngredientKey(view.query);
    final visible = items
        .where((item) {
          if (item.status != ShoppingItemStatus.active) {
            return false;
          }
          if (view.category != null && item.category != view.category) {
            return false;
          }
          if (view.recipeId != null &&
              !item.sourceReferenceIds.contains(view.recipeId)) {
            return false;
          }
          return query.isEmpty || _matches(item, query);
        })
        .toList(growable: false);

    int compare(ShoppingItem first, ShoppingItem second) {
      final result = switch (view.sort) {
        ShoppingSortOption.category => first.category.index.compareTo(
          second.category.index,
        ),
        ShoppingSortOption.alphabetical => _name(
          first,
        ).compareTo(_name(second)),
        ShoppingSortOption.recipeSource => _recipeSortKey(
          first,
          recipeNames,
        ).compareTo(_recipeSortKey(second, recipeNames)),
      };
      if (result != 0) {
        return result;
      }
      final byName = _name(first).compareTo(_name(second));
      return byName != 0 ? byName : first.id.compareTo(second.id);
    }

    visible.sort(compare);
    return ShoppingViewProjection(
      items: List<ShoppingItem>.unmodifiable(visible),
    );
  }

  double pantryAvailability(
    ShoppingItem item,
    Iterable<Ingredient> pantry, {
    required DateTime at,
  }) {
    final canonicalId =
        registry?.canonicalIdFor(item.canonicalIngredientId) ??
        registry?.resolve(item.canonicalIngredientId).ingredient?.id ??
        registry?.resolve(item.displayName).ingredient?.id ??
        item.canonicalIngredientId;
    var total = 0.0;
    for (final lot in pantry) {
      if (lot.quantity <= 0 || lot.isExpiredAt(at)) {
        continue;
      }
      final lotCanonical =
          registry?.canonicalIdFor(lot.canonicalIngredientId) ??
          registry?.resolve(lot.canonicalIngredientId).ingredient?.id ??
          registry?.resolve(lot.name).ingredient?.id ??
          lot.canonicalIngredientId;
      if (lotCanonical != canonicalId) {
        continue;
      }
      final converted = unitEngine.tryConvert(
        lot.quantity,
        fromUnit: lot.canonicalUnitId.isEmpty ? lot.unit : lot.canonicalUnitId,
        toUnit: item.unitId,
      );
      if (converted.isSuccess) {
        total += converted.value!;
      }
    }
    return unitEngine.precisionPolicy.apply(
      total,
      decimalPlaces: unitEngine.resolveUnit(item.unitId)?.decimalPlaces,
    );
  }

  bool _matches(ShoppingItem item, String query) {
    final ingredient =
        registry?.byId(item.canonicalIngredientId) ??
        registry?.resolve(item.canonicalIngredientId).ingredient ??
        registry?.resolve(item.displayName).ingredient;
    final values = <String>[
      item.displayName,
      item.canonicalIngredientId,
      if (ingredient != null) ...ingredient.searchableNames,
    ];
    return values.any((value) => normalizeIngredientKey(value).contains(query));
  }
}

String formatShoppingQuantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String shoppingUnitLabel(String unitId) {
  return UnitPresentation.label(unitId);
}

String shoppingCategoryLabel(ShoppingCategory category) {
  return switch (category) {
    ShoppingCategory.produce => 'ผักและผลไม้',
    ShoppingCategory.protein => 'โปรตีน',
    ShoppingCategory.seafood => 'อาหารทะเล',
    ShoppingCategory.dairyAndEggs => 'นมและไข่',
    ShoppingCategory.grains => 'ข้าวและธัญพืช',
    ShoppingCategory.seasonings => 'เครื่องปรุง',
    ShoppingCategory.beverages => 'เครื่องดื่ม',
    ShoppingCategory.frozen => 'อาหารแช่แข็ง',
    ShoppingCategory.household => 'ของใช้ในบ้าน',
    ShoppingCategory.other => 'อื่น ๆ',
  };
}

String _name(ShoppingItem item) => item.displayName.trim().toLowerCase();

String _recipeSortKey(ShoppingItem item, Map<String, String> recipeNames) {
  if (item.sourceReferenceIds.isEmpty) {
    return '~';
  }
  return item.sourceReferenceIds
      .map((id) => recipeNames[id] ?? id)
      .join('|')
      .toLowerCase();
}
