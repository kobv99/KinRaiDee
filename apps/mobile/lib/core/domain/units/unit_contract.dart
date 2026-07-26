import 'dart:math' as math;

enum QuantityRoundingMode { halfUp, down, up }

class QuantityPrecisionPolicy {
  const QuantityPrecisionPolicy({
    this.decimalPlaces = 3,
    this.roundingMode = QuantityRoundingMode.halfUp,
    this.zeroTolerance = 0.000001,
  });

  final int decimalPlaces;
  final QuantityRoundingMode roundingMode;
  final double zeroTolerance;

  double apply(double value, {int? decimalPlaces}) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'must be finite');
    }
    final places = decimalPlaces ?? this.decimalPlaces;
    if (places < 0 || places > 9) {
      throw ArgumentError.value(
        places,
        'decimalPlaces',
        'must be between 0 and 9',
      );
    }
    if (value.abs() <= zeroTolerance) {
      return 0;
    }

    final scale = math.pow(10, places).toDouble();
    final scaled = value * scale;
    final rounded = switch (roundingMode) {
      QuantityRoundingMode.halfUp => scaled.roundToDouble(),
      QuantityRoundingMode.down => scaled.floorToDouble(),
      QuantityRoundingMode.up => scaled.ceilToDouble(),
    };
    return rounded / scale;
  }
}

class UnitDefinition {
  const UnitDefinition({
    required this.id,
    required this.dimension,
    required this.displayName,
    required this.factorToParent,
    this.parentUnitId,
    this.aliases = const <String>[],
    this.decimalPlaces = 3,
    this.version = 1,
  });

  final String id;
  final String dimension;
  final String displayName;
  final String? parentUnitId;
  final double factorToParent;
  final List<String> aliases;
  final int decimalPlaces;
  final int version;
}

enum UnitConversionFailure {
  invalidQuantity,
  unknownSourceUnit,
  unknownTargetUnit,
  incompatibleDimensions,
}

class UnitConversionResult {
  const UnitConversionResult.success({
    required this.value,
    required this.sourceUnitId,
    required this.targetUnitId,
  }) : failure = null;

  const UnitConversionResult.failure(this.failure)
    : value = null,
      sourceUnitId = null,
      targetUnitId = null;

  final double? value;
  final String? sourceUnitId;
  final String? targetUnitId;
  final UnitConversionFailure? failure;

  bool get isSuccess => failure == null;
}

class UnitContractException implements Exception {
  const UnitContractException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'UnitContractException($code): $message';
}

class UnitConversionEngine {
  UnitConversionEngine({
    required Iterable<UnitDefinition> definitions,
    this.precisionPolicy = const QuantityPrecisionPolicy(),
  }) {
    for (final definition in definitions) {
      _register(definition);
    }
    if (_definitions.isEmpty) {
      throw const UnitContractException(
        'empty_unit_contract',
        'At least one unit is required.',
      );
    }
    _validateGraph();
  }

  factory UnitConversionEngine.standard() {
    return UnitConversionEngine(definitions: standardUnitDefinitions);
  }

  final QuantityPrecisionPolicy precisionPolicy;
  final Map<String, UnitDefinition> _definitions = <String, UnitDefinition>{};
  final Map<String, String> _aliases = <String, String>{};
  final Map<String, double> _factorCache = <String, double>{};
  final Map<String, String> _rootCache = <String, String>{};

  List<UnitDefinition> get definitions =>
      List<UnitDefinition>.unmodifiable(_definitions.values);

  UnitDefinition? resolveUnit(String value) {
    final key = normalizeUnitKey(value);
    final id = _aliases[key];
    return id == null ? null : _definitions[id];
  }

  String? resolveUnitId(String value) => resolveUnit(value)?.id;

  UnitConversionResult tryConvert(
    double quantity, {
    required String fromUnit,
    required String toUnit,
  }) {
    if (!quantity.isFinite || quantity < 0) {
      return const UnitConversionResult.failure(
        UnitConversionFailure.invalidQuantity,
      );
    }
    final from = resolveUnit(fromUnit);
    if (from == null) {
      return const UnitConversionResult.failure(
        UnitConversionFailure.unknownSourceUnit,
      );
    }
    final to = resolveUnit(toUnit);
    if (to == null) {
      return const UnitConversionResult.failure(
        UnitConversionFailure.unknownTargetUnit,
      );
    }
    if (_rootFor(from.id) != _rootFor(to.id) ||
        from.dimension != to.dimension) {
      return const UnitConversionResult.failure(
        UnitConversionFailure.incompatibleDimensions,
      );
    }

    final raw = quantity * _factorToRoot(from.id) / _factorToRoot(to.id);
    return UnitConversionResult.success(
      value: precisionPolicy.apply(raw, decimalPlaces: to.decimalPlaces),
      sourceUnitId: from.id,
      targetUnitId: to.id,
    );
  }

  double? convertOrNull(
    double quantity, {
    required String fromUnit,
    required String toUnit,
  }) {
    return tryConvert(quantity, fromUnit: fromUnit, toUnit: toUnit).value;
  }

  void _register(UnitDefinition definition) {
    final id = normalizeUnitKey(definition.id);
    if (id.isEmpty || id != definition.id) {
      throw UnitContractException(
        'invalid_unit_id',
        'Unit ID "${definition.id}" must already be normalized.',
      );
    }
    if (_definitions.containsKey(id)) {
      throw UnitContractException(
        'duplicate_unit_id',
        'Duplicate unit ID: $id',
      );
    }
    if (definition.dimension.trim().isEmpty ||
        !definition.factorToParent.isFinite ||
        definition.factorToParent <= 0 ||
        definition.decimalPlaces < 0 ||
        definition.decimalPlaces > 9 ||
        definition.version < 1) {
      throw UnitContractException(
        'invalid_unit_definition',
        'Invalid unit definition: $id',
      );
    }
    _definitions[id] = definition;

    for (final alias in <String>[
      definition.id,
      definition.displayName,
      ...definition.aliases,
    ]) {
      final normalized = normalizeUnitKey(alias);
      if (normalized.isEmpty) {
        continue;
      }
      final existing = _aliases[normalized];
      if (existing != null && existing != id) {
        throw UnitContractException(
          'duplicate_unit_alias',
          'Unit alias "$alias" maps to both $existing and $id.',
        );
      }
      _aliases[normalized] = id;
    }
  }

  void _validateGraph() {
    final visiting = <String>{};
    final visited = <String>{};

    void visit(String id) {
      if (visited.contains(id)) {
        return;
      }
      if (!visiting.add(id)) {
        throw UnitContractException(
          'circular_unit_conversion',
          'Circular conversion detected at $id.',
        );
      }
      final definition = _definitions[id]!;
      final parentId = definition.parentUnitId;
      if (parentId != null) {
        final parent = _definitions[parentId];
        if (parent == null) {
          throw UnitContractException(
            'missing_parent_unit',
            'Unit $id references missing parent $parentId.',
          );
        }
        if (parent.dimension != definition.dimension) {
          throw UnitContractException(
            'unit_dimension_mismatch',
            'Unit $id and parent $parentId use different dimensions.',
          );
        }
        visit(parentId);
      }
      visiting.remove(id);
      visited.add(id);
      _rootFor(id);
      _factorToRoot(id);
    }

    for (final id in _definitions.keys) {
      visit(id);
    }
  }

  String _rootFor(String id) {
    return _rootCache.putIfAbsent(id, () {
      final parent = _definitions[id]!.parentUnitId;
      return parent == null ? id : _rootFor(parent);
    });
  }

  double _factorToRoot(String id) {
    return _factorCache.putIfAbsent(id, () {
      final definition = _definitions[id]!;
      final parent = definition.parentUnitId;
      return definition.factorToParent *
          (parent == null ? 1 : _factorToRoot(parent));
    });
  }
}

String normalizeUnitKey(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('.', '')
      .replaceAll(RegExp(r'[\s_-]+'), '');
}

const List<UnitDefinition> standardUnitDefinitions = <UnitDefinition>[
  UnitDefinition(
    id: 'gram',
    dimension: 'mass',
    displayName: 'กรัม',
    factorToParent: 1,
    aliases: <String>['g', 'gram', 'grams'],
    decimalPlaces: 3,
  ),
  UnitDefinition(
    id: 'kilogram',
    dimension: 'mass',
    displayName: 'กิโลกรัม',
    parentUnitId: 'gram',
    factorToParent: 1000,
    aliases: <String>['kg', 'kilogram', 'kilograms'],
    decimalPlaces: 3,
  ),
  UnitDefinition(
    id: 'milliliter',
    dimension: 'volume',
    displayName: 'มิลลิลิตร',
    factorToParent: 1,
    aliases: <String>['ml', 'millilitre', 'milliliters', 'millilitres'],
    decimalPlaces: 2,
  ),
  UnitDefinition(
    id: 'liter',
    dimension: 'volume',
    displayName: 'ลิตร',
    parentUnitId: 'milliliter',
    factorToParent: 1000,
    aliases: <String>['l', 'litre', 'liters', 'litres'],
    decimalPlaces: 3,
  ),
  UnitDefinition(
    id: 'teaspoon',
    dimension: 'volume',
    displayName: 'ช้อนชา',
    parentUnitId: 'milliliter',
    factorToParent: 5,
    aliases: <String>['tsp', 'teaspoons'],
    decimalPlaces: 2,
  ),
  UnitDefinition(
    id: 'tablespoon',
    dimension: 'volume',
    displayName: 'ช้อนโต๊ะ',
    parentUnitId: 'milliliter',
    factorToParent: 15,
    aliases: <String>['tbsp', 'tablespoons'],
    decimalPlaces: 2,
  ),
  UnitDefinition(
    id: 'cup',
    dimension: 'volume',
    displayName: 'ถ้วย',
    parentUnitId: 'milliliter',
    factorToParent: 240,
    aliases: <String>['cups'],
    decimalPlaces: 2,
  ),
  UnitDefinition(
    id: 'piece',
    dimension: 'count',
    displayName: 'ชิ้น',
    factorToParent: 1,
    aliases: <String>['pieces'],
    decimalPlaces: 2,
  ),
  UnitDefinition(
    id: 'egg',
    dimension: 'count',
    displayName: 'ฟอง',
    parentUnitId: 'piece',
    factorToParent: 1,
    aliases: <String>['eggs'],
    decimalPlaces: 0,
  ),
  UnitDefinition(
    id: 'whole',
    dimension: 'count',
    displayName: 'ตัว',
    parentUnitId: 'piece',
    factorToParent: 1,
    aliases: <String>['whole'],
    decimalPlaces: 0,
  ),
  UnitDefinition(
    id: 'stalk',
    dimension: 'count',
    displayName: 'ต้น',
    parentUnitId: 'piece',
    factorToParent: 1,
    aliases: <String>['stalks'],
    decimalPlaces: 0,
  ),
  UnitDefinition(
    id: 'clove',
    dimension: 'count',
    displayName: 'กลีบ',
    parentUnitId: 'piece',
    factorToParent: 1,
    aliases: <String>['cloves'],
    decimalPlaces: 0,
  ),
  UnitDefinition(
    id: 'pod',
    dimension: 'count',
    displayName: 'ฝัก',
    parentUnitId: 'piece',
    factorToParent: 1,
    aliases: <String>['pods'],
    decimalPlaces: 0,
  ),
  UnitDefinition(
    id: 'bunch',
    dimension: 'count',
    displayName: 'กำ',
    parentUnitId: 'piece',
    factorToParent: 1,
    aliases: <String>['bunches', 'กำมือ', 'handful'],
    decimalPlaces: 1,
  ),
  UnitDefinition(
    id: 'block',
    dimension: 'count',
    displayName: 'ก้อน',
    parentUnitId: 'piece',
    factorToParent: 1,
    aliases: <String>['blocks'],
    decimalPlaces: 1,
  ),
  UnitDefinition(
    id: 'head',
    dimension: 'count',
    displayName: 'หัว',
    parentUnitId: 'piece',
    factorToParent: 1,
    aliases: <String>['heads'],
    decimalPlaces: 1,
  ),
  UnitDefinition(
    id: 'seed',
    dimension: 'count',
    displayName: 'เม็ด',
    parentUnitId: 'piece',
    factorToParent: 1,
    aliases: <String>['seeds'],
    decimalPlaces: 0,
  ),
  UnitDefinition(
    id: 'leaf',
    dimension: 'count',
    displayName: 'ใบ',
    parentUnitId: 'piece',
    factorToParent: 1,
    aliases: <String>['leaves'],
    decimalPlaces: 0,
  ),
  UnitDefinition(
    id: 'slice',
    dimension: 'count',
    displayName: 'แว่น',
    parentUnitId: 'piece',
    factorToParent: 1,
    aliases: <String>['slices'],
    decimalPlaces: 1,
  ),
  UnitDefinition(
    id: 'fruit',
    dimension: 'count',
    displayName: 'ลูก',
    parentUnitId: 'piece',
    factorToParent: 1,
    aliases: <String>['fruits'],
    decimalPlaces: 0,
  ),
  UnitDefinition(
    id: 'bottle',
    dimension: 'package',
    displayName: 'ขวด',
    factorToParent: 1,
    aliases: <String>['bottles'],
    decimalPlaces: 1,
  ),
  UnitDefinition(
    id: 'bag',
    dimension: 'package',
    displayName: 'ถุง',
    factorToParent: 1,
    aliases: <String>['bags'],
    decimalPlaces: 1,
  ),
  UnitDefinition(
    id: 'pack',
    dimension: 'package',
    displayName: 'แพ็ก',
    factorToParent: 1,
    aliases: <String>['packs', 'แพ็ค'],
    decimalPlaces: 1,
  ),
];
