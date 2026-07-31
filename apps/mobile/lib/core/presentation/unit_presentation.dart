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
}
