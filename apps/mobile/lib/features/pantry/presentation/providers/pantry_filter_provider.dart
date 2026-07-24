import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/ingredient.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../domain/services/pantry_expiry_priority.dart';
import '../../domain/services/pantry_search_engine.dart';

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
        return 'ควรใช้ก่อน';
    }
  }
}

class PantryFilterState {
  const PantryFilterState({
    this.searchQuery = '',
    this.selectedCategory,
    this.onlyExpiringSoon = false,
    this.sortOption = PantrySortOption.expirySoonest,
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
  final searchQuery = filter.searchQuery.trim();
  final searchScores = <String, int>{};

  final filteredIngredients = ingredients
      .where((ingredient) {
        final searchMatch = PantrySearchEngine.matchIngredient(
          ingredient,
          searchQuery,
        );
        final matchesSearch = searchQuery.isEmpty || searchMatch.isMatch;

        if (matchesSearch && searchQuery.isNotEmpty) {
          searchScores[ingredient.id] = searchMatch.score;
        }

        final matchesCategory =
            filter.selectedCategory == null ||
            ingredient.category == filter.selectedCategory;

        final matchesExpiry =
            !filter.onlyExpiringSoon ||
            PantryExpiryPriority.shouldUseSoon(ingredient);

        return matchesSearch && matchesCategory && matchesExpiry;
      })
      .toList(growable: false);

  final sortedIngredients = List<Ingredient>.of(filteredIngredients);

  sortedIngredients.sort((first, second) {
    if (searchQuery.isNotEmpty) {
      final searchComparison = (searchScores[second.id] ?? 0).compareTo(
        searchScores[first.id] ?? 0,
      );
      if (searchComparison != 0) {
        return searchComparison;
      }
    }

    if (filter.sortOption == PantrySortOption.expirySoonest) {
      return PantryExpiryPriority.compare(first, second);
    }

    final favoriteComparison = _compareFavorite(first, second);
    if (favoriteComparison != 0) {
      return favoriteComparison;
    }

    switch (filter.sortOption) {
      case PantrySortOption.newest:
        return second.createdAt.compareTo(first.createdAt);
      case PantrySortOption.oldest:
        return first.createdAt.compareTo(second.createdAt);
      case PantrySortOption.nameAscending:
        return first.name.compareTo(second.name);
      case PantrySortOption.expirySoonest:
        return PantryExpiryPriority.compare(first, second);
    }
  });

  return List<Ingredient>.unmodifiable(sortedIngredients);
});

int _compareFavorite(Ingredient first, Ingredient second) {
  if (first.isFavorite == second.isFavorite) {
    return 0;
  }

  return first.isFavorite ? -1 : 1;
}