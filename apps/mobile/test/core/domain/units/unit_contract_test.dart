import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';

void main() {
  group('UnitConversionEngine', () {
    test('converts mass and volume through canonical base units', () {
      final engine = UnitConversionEngine.standard();

      expect(engine.convertOrNull(1.25, fromUnit: 'kg', toUnit: 'gram'), 1250);
      expect(engine.convertOrNull(2, fromUnit: 'tbsp', toUnit: 'tsp'), 6);
      expect(engine.resolveUnitId('ช้อนโต๊ะ'), 'tablespoon');
    });

    test('applies deterministic target precision and half-up rounding', () {
      final engine = UnitConversionEngine(
        definitions: const <UnitDefinition>[
          UnitDefinition(
            id: 'base',
            dimension: 'test',
            displayName: 'base',
            factorToParent: 1,
            decimalPlaces: 2,
          ),
          UnitDefinition(
            id: 'third',
            dimension: 'test',
            displayName: 'third',
            parentUnitId: 'base',
            factorToParent: 1 / 3,
            decimalPlaces: 2,
          ),
        ],
      );

      expect(engine.convertOrNull(1, fromUnit: 'base', toUnit: 'third'), 3);
      expect(engine.convertOrNull(1, fromUnit: 'third', toUnit: 'base'), 0.33);
    });

    test('fails safely for invalid, unknown, and incompatible conversions', () {
      final engine = UnitConversionEngine.standard();

      expect(
        engine.tryConvert(-1, fromUnit: 'gram', toUnit: 'kilogram').failure,
        UnitConversionFailure.invalidQuantity,
      );
      expect(
        engine.tryConvert(1, fromUnit: 'mystery', toUnit: 'gram').failure,
        UnitConversionFailure.unknownSourceUnit,
      );
      expect(
        engine.tryConvert(1, fromUnit: 'gram', toUnit: 'piece').failure,
        UnitConversionFailure.incompatibleDimensions,
      );
    });

    test('forbids duplicate IDs, duplicate aliases, and circular graphs', () {
      expect(
        () => UnitConversionEngine(
          definitions: const <UnitDefinition>[
            UnitDefinition(
              id: 'same',
              dimension: 'x',
              displayName: 'one',
              factorToParent: 1,
            ),
            UnitDefinition(
              id: 'same',
              dimension: 'x',
              displayName: 'two',
              factorToParent: 1,
            ),
          ],
        ),
        throwsA(
          isA<UnitContractException>().having(
            (error) => error.code,
            'code',
            'duplicate_unit_id',
          ),
        ),
      );
      expect(
        () => UnitConversionEngine(
          definitions: const <UnitDefinition>[
            UnitDefinition(
              id: 'one',
              dimension: 'x',
              displayName: 'one',
              factorToParent: 1,
              aliases: <String>['shared'],
            ),
            UnitDefinition(
              id: 'two',
              dimension: 'x',
              displayName: 'two',
              factorToParent: 1,
              aliases: <String>['shared'],
            ),
          ],
        ),
        throwsA(
          isA<UnitContractException>().having(
            (error) => error.code,
            'code',
            'duplicate_unit_alias',
          ),
        ),
      );
      expect(
        () => UnitConversionEngine(
          definitions: const <UnitDefinition>[
            UnitDefinition(
              id: 'one',
              dimension: 'x',
              displayName: 'one',
              parentUnitId: 'two',
              factorToParent: 1,
            ),
            UnitDefinition(
              id: 'two',
              dimension: 'x',
              displayName: 'two',
              parentUnitId: 'one',
              factorToParent: 1,
            ),
          ],
        ),
        throwsA(
          isA<UnitContractException>().having(
            (error) => error.code,
            'code',
            'circular_unit_conversion',
          ),
        ),
      );
    });
  });
}
