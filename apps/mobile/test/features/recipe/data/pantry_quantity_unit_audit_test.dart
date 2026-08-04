import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';

/// Proves the pantry quantity/unit contract is coherent for every selectable
/// Animal & Seafood MVP node: a quantity alone or a unit alone can each look
/// fine in isolation, but the *pair* is what actually gets shown on the
/// future batch-review screen — "300 kilogram" is the failure mode this
/// guards against.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final unitEngine = UnitConversionEngine.standard();

  test('every selectable Animal & Seafood MVP node has a valid, plausible '
      'pantry quantity/unit pair', () async {
    final registry = await IngredientCatalog().loadRegistry();
    final failures = <String>[];

    for (final id in _mvpSelectableIds) {
      final ingredient = registry.byId(id);
      if (ingredient == null) {
        failures.add('$id: missing from registry');
        continue;
      }
      final quantity = ingredient.defaultPantryQuantity;
      if (quantity == null || !quantity.isFinite || quantity <= 0) {
        failures.add('$id: defaultPantryQuantity is $quantity');
        continue;
      }
      final unit = unitEngine.resolveUnit(ingredient.defaultPantryUnitId);
      if (unit == null) {
        failures.add(
          '$id: defaultPantryUnitId "${ingredient.defaultPantryUnitId}" '
          'does not resolve in the unit engine',
        );
        continue;
      }
      if (!_isPlausiblePantryQuantity(quantity, unit, unitEngine)) {
        failures.add(
          '$id: implausible pair — quantity=$quantity, '
          'unit=${unit.id} (${unit.dimension})',
        );
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  group('_isPlausiblePantryQuantity (audit logic itself)', () {
    test('rejects 300 kilogram — a mass-scale unit at an absurd magnitude', () {
      final kilogram = unitEngine.resolveUnit('kilogram')!;
      expect(_isPlausiblePantryQuantity(300, kilogram, unitEngine), isFalse);
    });

    test('accepts 300 gram', () {
      final gram = unitEngine.resolveUnit('gram')!;
      expect(_isPlausiblePantryQuantity(300, gram, unitEngine), isTrue);
    });

    test('rejects a count-style unit (whole) accidentally receiving a '
        'mass-style quantity such as 300', () {
      final whole = unitEngine.resolveUnit('whole')!;
      expect(_isPlausiblePantryQuantity(300, whole, unitEngine), isFalse);
    });

    test('accepts a small count-style quantity such as 1 can', () {
      final can = unitEngine.resolveUnit('can')!;
      expect(_isPlausiblePantryQuantity(1, can, unitEngine), isTrue);
    });
  });
}

/// Mass/volume are checked by converting to a common reference unit
/// (gram/milliliter) so unit choice (gram vs kilogram) can't hide an
/// absurd magnitude; count/package dimensions are checked directly since
/// there's no finer subdivision to convert through.
bool _isPlausiblePantryQuantity(
  double quantity,
  UnitDefinition unit,
  UnitConversionEngine engine,
) {
  switch (unit.dimension) {
    case 'mass':
      final grams = engine.convertOrNull(
        quantity,
        fromUnit: unit.id,
        toUnit: 'gram',
      );
      return grams != null && grams > 0 && grams <= 5000;
    case 'volume':
      final milliliters = engine.convertOrNull(
        quantity,
        fromUnit: unit.id,
        toUnit: 'milliliter',
      );
      return milliliters != null && milliliters > 0 && milliliters <= 5000;
    default: // count, package
      return quantity > 0 && quantity <= 20;
  }
}

const _mvpSelectableIds = <String>{
  'pork', 'minced_pork', 'pork_belly', 'pork_neck', 'pork_tenderloin',
  'pork_ribs', 'moo_yor', 'pork_liver', //
  'chicken', 'chicken_breast', 'chicken_thigh', 'chicken_drumstick',
  'chicken_wing', 'minced_chicken', 'chicken_liver', 'chicken_gizzard', //
  'beef', 'minced_beef', 'beef_shank', //
  'fish', 'fish_fillet', 'tilapia', 'catfish', 'snakehead', 'sea_bass',
  'mackerel', 'salmon', //
  'shrimp', //
  'crab', 'imitation_crab', //
  'squid', //
  'shellfish',
};
