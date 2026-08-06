import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../core/domain/ingredients/canonical_ingredient.dart';
import '../../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../../../../core/domain/ingredients/canonical_ingredient_search_service.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../domain/models/ingredient_browse_facet.dart';

/// Temporary, session-scoped selection for the multi-select ingredient
/// picker. `autoDispose` ties its lifetime to whether any picker screen is
/// currently watching it — once the whole picker flow is popped, Riverpod
/// disposes this instance, so no selection can leak into the next session
/// structurally. The picker's entry point additionally calls
/// `ref.invalidate` when the flow is left (see `pantry_page.dart`), which
/// gives an immediate, deterministic reset rather than relying solely on
/// autoDispose's GC-like timing.
class IngredientPickerSelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  /// Toggles [canonicalId]: adds it if absent, removes it if present.
  /// Selecting the same id twice never produces a duplicate, since the
  /// underlying state is a [Set].
  void toggle(String canonicalId) {
    final next = <String>{...state};
    if (!next.remove(canonicalId)) {
      next.add(canonicalId);
    }
    state = Set<String>.unmodifiable(next);
  }

  void clear() {
    state = const <String>{};
  }
}

final ingredientPickerSelectionProvider =
    NotifierProvider.autoDispose<
      IngredientPickerSelectionNotifier,
      Set<String>
    >(IngredientPickerSelectionNotifier.new);

/// The picker's root navigation cards: every family node with no parent.
/// Sorted by display name (registry-derived data, not a hardcoded id
/// order) for a stable, presentable order.
final rootIngredientFamiliesProvider = Provider<List<CanonicalIngredient>>((
  ref,
) {
  final registry = ref.watch(canonicalIngredientRegistryProvider);
  if (registry == null) {
    return const <CanonicalIngredient>[];
  }
  final roots =
      registry.ingredients
          .where(
            (ingredient) =>
                ingredient.nodeType == CanonicalIngredientNodeType.family &&
                ingredient.parentId == null,
          )
          .toList()
        ..sort((a, b) => a.displayName().compareTo(b.displayName()));
  return List<CanonicalIngredient>.unmodifiable(roots);
});

/// Direct children of [familyId] — both selectable ingredients and nested
/// families — sorted by display name. The picker UI never hardcodes which
/// children belong to a family; this is the only source of that list.
final ingredientFamilyChildrenProvider =
    Provider.family<List<CanonicalIngredient>, String>((ref, familyId) {
      final registry = ref.watch(canonicalIngredientRegistryProvider);
      if (registry == null) {
        return const <CanonicalIngredient>[];
      }
      final children =
          registry.ingredients
              .where((ingredient) => ingredient.parentId == familyId)
              .toList()
            ..sort((a, b) => a.displayName().compareTo(b.displayName()));
      return List<CanonicalIngredient>.unmodifiable(children);
    });

const CanonicalIngredientSearchService _searchService =
    CanonicalIngredientSearchService();

/// Search results for [query], `autoDispose`d per distinct query string so
/// keystroke-level queries don't accumulate cached providers forever.
final ingredientSearchResultsProvider = Provider.autoDispose
    .family<List<CanonicalIngredientSearchResult>, String>((ref, query) {
      final registry = ref.watch(canonicalIngredientRegistryProvider);
      if (registry == null) {
        _logSearchDiagnostics(registry: null, query: query, results: null);
        return const <CanonicalIngredientSearchResult>[];
      }
      final results = _searchService.search(registry, query);
      _logSearchDiagnostics(registry: registry, query: query, results: results);
      return results;
    });

/// Temporary, debug-build-only diagnostics for tracing the exact runtime
/// registry instance the picker's search actually reads from — compiled out
/// entirely in profile/release builds since [kDebugMode] is a compile-time
/// constant, so this can never leak into release UI or logs.
void _logSearchDiagnostics({
  required CanonicalIngredientRegistry? registry,
  required String query,
  required List<CanonicalIngredientSearchResult>? results,
}) {
  if (!kDebugMode) {
    return;
  }
  if (registry == null) {
    debugPrint(
      'ingredientSearchResultsProvider: registry=null (not yet bootstrapped) '
      'query=$query',
    );
    return;
  }
  final beefShank = registry.byId('beef_shank');
  debugPrint(
    'registryCount=${registry.ingredients.length} '
    'beef_shank.exists=${beefShank != null} '
    'beef_shank.searchableNames=${beefShank?.searchableNames.toList() ?? const <String>[]} '
    'query=$query '
    'results=${results?.map((r) => r.ingredient.id).toList() ?? const <String>[]}',
  );
}

/// Members of a browse facet (e.g. "อาหารแปรรูป") — a UI classification
/// over existing canonical ids, never a new identity. See
/// `ingredient_browse_facet.dart` for how membership is derived.
final ingredientBrowseFacetMembersProvider =
    Provider.family<List<CanonicalIngredient>, String>((ref, facetId) {
      final registry = ref.watch(canonicalIngredientRegistryProvider);
      if (registry == null) {
        return const <CanonicalIngredient>[];
      }
      return ingredientBrowseFacetMembers(registry, facetId);
    });

/// Canonical ids already present in the pantry, for the "มีแล้ว" check.
/// Keyed by canonical id, never by display name.
final pantryCanonicalIngredientIdsProvider = Provider<Set<String>>((ref) {
  final pantry = ref.watch(pantryProvider);
  return pantry
      .where((ingredient) => ingredient.canonicalIngredientId.isNotEmpty)
      .map((ingredient) => ingredient.canonicalIngredientId)
      .toSet();
});
