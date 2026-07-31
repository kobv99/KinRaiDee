import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/presentation/unit_presentation.dart';

void main() {
  group('UnitPresentation', () {
    test('localizes canonical Unit Contract values consistently', () {
      expect(UnitPresentation.label('egg'), 'ฟอง');
      expect(UnitPresentation.label('kilogram'), 'กิโลกรัม');
      expect(UnitPresentation.label('liter'), 'ลิตร');
    });

    test('formats quantities without exposing canonical IDs', () {
      expect(UnitPresentation.quantity(1, 'egg'), '1 ฟอง');
      expect(UnitPresentation.quantity(0.2, 'kilogram'), '0.2 กิโลกรัม');
    });

    test('keeps unknown legacy units readable', () {
      expect(UnitPresentation.label('legacy-scoop'), 'legacy-scoop');
    });
  });

  group('UnitPresentation.cookingQuantity', () {
    test('a tiny liter amount for seasoning becomes tablespoons', () {
      expect(UnitPresentation.cookingQuantity(0.015, 'liter'), '1 ช้อนโต๊ะ');
    });

    test('an even tinier liter amount becomes teaspoons', () {
      expect(UnitPresentation.cookingQuantity(0.005, 'liter'), '1 ช้อนชา');
    });

    test('never shows a fractional-liter decimal for a small volume', () {
      final formatted = UnitPresentation.cookingQuantity(0.015, 'liter');
      expect(formatted, isNot(contains('ลิตร')));
    });

    test('a mid-size volume becomes cups, not a huge tablespoon count', () {
      // 480ml = 2 cups = 32 tablespoons; cups reads more naturally.
      expect(UnitPresentation.cookingQuantity(0.48, 'liter'), '2 ถ้วย');
    });

    test('a genuinely large volume stays in liters', () {
      expect(UnitPresentation.cookingQuantity(2, 'liter'), '2 ลิตร');
    });

    test('milliliter input converts the same way as liter input', () {
      expect(UnitPresentation.cookingQuantity(15, 'milliliter'), '1 ช้อนโต๊ะ');
    });

    test('a small mass amount stays in grams', () {
      expect(UnitPresentation.cookingQuantity(300, 'gram'), '300 กรัม');
    });

    test('a mass amount at or above 1000g becomes kilograms', () {
      expect(UnitPresentation.cookingQuantity(1500, 'gram'), '1.5 กิโลกรัม');
    });

    test('count and package units are left exactly as-is', () {
      expect(UnitPresentation.cookingQuantity(3, 'clove'), '3 กลีบ');
      expect(UnitPresentation.cookingQuantity(1, 'bottle'), '1 ขวด');
      expect(UnitPresentation.cookingQuantity(2, 'stalk'), '2 ต้น');
    });

    test('is deterministic: same input always produces the same output', () {
      final first = UnitPresentation.cookingQuantity(0.015, 'liter');
      final second = UnitPresentation.cookingQuantity(0.015, 'liter');
      expect(first, second);
    });

    test('falls back to plain formatting for an unresolvable unit', () {
      expect(
        UnitPresentation.cookingQuantity(2, 'legacy-scoop'),
        '2 legacy-scoop',
      );
    });
  });
}
