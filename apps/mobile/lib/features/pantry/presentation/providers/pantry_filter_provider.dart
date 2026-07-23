import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/ingredient.dart';
import '../../../../core/providers/pantry_provider.dart';

enum PantrySortOption { newest, oldest, nameAscending, expirySoonest }

extension PantrySortOptionLabel on PantrySortOption {
  String get label {
    switch (this) {
      case PantrySortOption.newest:
        return 'เพิ่มล่าสุด';
      case PantrySortOption.oldest:
        return 'เพิ่มเก่าสุด';
      case PantrySortOption.nameAscending:
        return 'ชื่อ ก–ฮ';
      case PantrySortOption.expirySoonest:
        return 'ใกล้หมดอายุก่อน';
    }
  }
}

class PantryFilterState {
  const PantryFilterState({
    this.searchQuery = '',
    this.selectedCategory,
    this.onlyExpiringSoon = false,
    this.sortOption = PantrySortOption.newest,
  });

  final String searchQuery;
  final String? selectedCategory;
  final bool onlyExpiringSoon;
  final PantrySortOption sortOption;

  bool get hasActiveFilters {
    return searchQuery.trim().isNotEmpty ||
        selectedCategory != null ||
        onlyExpiringSoon;
  }

  PantryFilterState copyWith({
    String? searchQuery,
    String? selectedCategory,
    bool clearSelectedCategory = false,
    bool? onlyExpiringSoon,
    PantrySortOption? sortOption,
  }) {
    return PantryFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: clearSelectedCategory
          ? null
          : selectedCategory ?? this.selectedCategory,
      onlyExpiringSoon: onlyExpiringSoon ?? this.onlyExpiringSoon,
      sortOption: sortOption ?? this.sortOption,
    );
  }
}

class PantryFilterNotifier extends Notifier<PantryFilterState> {
  @override
  PantryFilterState build() {
    return const PantryFilterState();
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void setCategory(String? category) {
    if (category == null) {
      state = state.copyWith(clearSelectedCategory: true);
      return;
    }

    state = state.copyWith(selectedCategory: category);
  }

  void toggleExpiringSoon() {
    state = state.copyWith(onlyExpiringSoon: !state.onlyExpiringSoon);
  }

  void setSortOption(PantrySortOption option) {
    state = state.copyWith(sortOption: option);
  }

  void clearFilters() {
    state = PantryFilterState(sortOption: state.sortOption);
  }
}

final pantryFilterProvider =
    NotifierProvider<PantryFilterNotifier, PantryFilterState>(
      PantryFilterNotifier.new,
    );

final pantryCategoriesProvider = Provider<List<String>>((ref) {
  final ingredients = ref.watch(pantryProvider);

  final categories =
      ingredients
          .map((ingredient) => ingredient.category.trim())
          .where((category) => category.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  return List<String>.unmodifiable(categories);
});

final filteredPantryProvider = Provider<List<Ingredient>>((ref) {
  final ingredients = ref.watch(pantryProvider);
  final filter = ref.watch(pantryFilterProvider);

  final normalizedQuery = filter.searchQuery.trim().toLowerCase();

  final filteredIngredients = ingredients
      .where((ingredient) {
        final matchesSearch =
            normalizedQuery.isEmpty ||
            ingredient.name.toLowerCase().contains(normalizedQuery) ||
            ingredient.category.toLowerCase().contains(normalizedQuery);

        final matchesCategory =
            filter.selectedCategory == null ||
            ingredient.category == filter.selectedCategory;

        final matchesExpiry =
            !filter.onlyExpiringSoon || _isExpiringSoon(ingredient);

        return matchesSearch && matchesCategory && matchesExpiry;
      })
      .toList(growable: false);

  final sortedIngredients = List<Ingredient>.of(filteredIngredients);

  switch (filter.sortOption) {
    case PantrySortOption.newest:
      sortedIngredients.sort(
        (first, second) => second.createdAt.compareTo(first.createdAt),
      );

    case PantrySortOption.oldest:
      sortedIngredients.sort(
        (first, second) => first.createdAt.compareTo(second.createdAt),
      );

    case PantrySortOption.nameAscending:
      sortedIngredients.sort(
        (first, second) => first.name.compareTo(second.name),
      );

    case PantrySortOption.expirySoonest:
      sortedIngredients.sort(_compareExpiryDate);
  }

  return List<Ingredient>.unmodifiable(sortedIngredients);
});

bool _isExpiringSoon(Ingredient ingredient) {
  final days = ingredient.daysUntilExpiry;

  if (days == null) {
    return false;
  }

  return days <= 7;
}

int _compareExpiryDate(Ingredient first, Ingredient second) {
  final firstExpiry = first.expiryDate;
  final secondExpiry = second.expiryDate;

  if (firstExpiry == null && secondExpiry == null) {
    return first.name.compareTo(second.name);
  }

  if (firstExpiry == null) {
    return 1;
  }

  if (secondExpiry == null) {
    return -1;
  }

  return firstExpiry.compareTo(secondExpiry);
}
