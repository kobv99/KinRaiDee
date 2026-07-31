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
}
