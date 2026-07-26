import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../../core/domain/units/unit_contract.dart';
import '../../features/pantry/application/canonical_ingredient_migration.dart';

final unitConversionEngineProvider = Provider<UnitConversionEngine>(
  (ref) => UnitConversionEngine.standard(),
);

/// Overridden during startup after the bundled registry has been validated.
final canonicalIngredientRegistryProvider =
    Provider<CanonicalIngredientRegistry?>((ref) => null);

/// Diagnostics are retained for support and future data-quality tooling.
final canonicalIngredientMigrationReportProvider =
    Provider<CanonicalIngredientMigrationResult?>((ref) => null);
