import '../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../../core/domain/units/unit_contract.dart';
import '../../features/recipe/data/ingredient_catalog.dart';

/// The single production code path that builds the app's merged canonical
/// ingredient registry — loads `assets/ingredients/thai_ingredients.json`
/// and layers `applyPantryCatalogCanonicalCoverage` on top (see
/// [IngredientCatalog.loadRegistry]).
///
/// `main.dart` calls this during startup, before `runApp`, and overrides
/// [canonicalIngredientRegistryProvider] with the result. Extracted here so
/// tests can prove they exercise the *exact* production bootstrap — not a
/// hand-rolled or partial registry that happens to look similar — by
/// calling this same function instead of re-deriving the loading steps.
Future<CanonicalIngredientRegistry> bootstrapCanonicalIngredientRegistry({
  required UnitConversionEngine unitConversionEngine,
}) {
  return IngredientCatalog(
    unitConversionEngine: unitConversionEngine,
  ).loadRegistry();
}
