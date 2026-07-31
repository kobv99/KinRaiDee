import '../domain/units/unit_contract.dart';

/// Centralizes user-facing unit localization without changing persisted unit
/// identities. Known canonical IDs, aliases, and localized names all resolve
/// through the shared Unit Contract. Unknown legacy values remain readable.
class UnitPresentation {
  UnitPresentation._();

  static final UnitConversionEngine _standardEngine =
      UnitConversionEngine.standard();

  static String label(String value, {UnitConversionEngine? unitEngine}) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return '';
    }
    return (unitEngine ?? _standardEngine)
            .resolveUnit(normalized)
            ?.displayName ??
        normalized;
  }

  static String quantity(
    double value,
    String unit, {
    int maximumFractionDigits = 3,
    UnitConversionEngine? unitEngine,
  }) {
    return '${number(value, maximumFractionDigits: maximumFractionDigits)} '
            '${label(unit, unitEngine: unitEngine)}'
        .trim();
  }

  static String number(double value, {int maximumFractionDigits = 3}) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value
        .toStringAsFixed(maximumFractionDigits)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  /// Same as [quantity], but re-expresses volume and mass amounts in
  /// whichever unit reads naturally for cooking instead of the raw
  /// canonical storage unit — "0.015 ลิตร" becomes "1 ช้อนโต๊ะ". Count and
  /// package units (piece, clove, stalk, bottle, ...) already read
  /// naturally and are left untouched. Persisted/canonical storage is
  /// unaffected — this only changes what is displayed.
  static String cookingQuantity(
    double value,
    String unit, {
    UnitConversionEngine? unitEngine,
  }) {
    final engine = unitEngine ?? _standardEngine;
    final resolved = engine.resolveUnit(unit);
    if (resolved == null || value <= 0) {
      return quantity(value, unit, unitEngine: unitEngine);
    }

    final friendlyUnitId = _cookingFriendlyUnitId(engine, resolved, value);
    final converted = friendlyUnitId == null
        ? null
        : engine.convertOrNull(
            value,
            fromUnit: resolved.id,
            toUnit: friendlyUnitId,
          );

    return converted == null
        ? quantity(value, unit, unitEngine: unitEngine)
        : quantity(converted, friendlyUnitId!, unitEngine: unitEngine);
  }

  /// Deterministic: driven only by the ingredient's own dimension (volume
  /// vs mass vs count/package) and the converted magnitude, never by
  /// per-ingredient special-casing.
  static String? _cookingFriendlyUnitId(
    UnitConversionEngine engine,
    UnitDefinition unit,
    double value,
  ) {
    switch (unit.dimension) {
      case 'volume':
        final milliliters = engine.convertOrNull(
          value,
          fromUnit: unit.id,
          toUnit: 'milliliter',
        );
        if (milliliters == null) return null;
        if (milliliters < 15) return 'teaspoon';
        if (milliliters < 240) return 'tablespoon';
        if (milliliters < 1000) return 'cup';
        return 'liter';
      case 'mass':
        final grams = engine.convertOrNull(
          value,
          fromUnit: unit.id,
          toUnit: 'gram',
        );
        if (grams == null) return null;
        return grams >= 1000 ? 'kilogram' : 'gram';
      default:
        // count / package units (piece, clove, stalk, bottle, ...) are
        // already the natural cooking unit — leave them as-is.
        return null;
    }
  }
}
