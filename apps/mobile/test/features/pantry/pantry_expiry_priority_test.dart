import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/features/pantry/domain/services/pantry_expiry_priority.dart';

void main() {
  group('PantryExpiryPriority', () {
    final now = DateTime(2026, 7, 24, 18, 30);

    test(
      'orders active use-soon items before later, undated and expired items',
      () {
        final items = <Ingredient>[
          _ingredient('undated', 'ไม่ระบุวัน', now: now),
          _ingredient(
            'later',
            'อีกสิบวัน',
            now: now,
            expiryDate: DateTime(2026, 8, 3),
          ),
          _ingredient(
            'tomorrow',
            'หมดอายุพรุ่งนี้',
            now: now,
            expiryDate: DateTime(2026, 7, 25),
          ),
          _ingredient(
            'today',
            'หมดอายุวันนี้',
            now: now,
            expiryDate: DateTime(2026, 7, 24),
          ),
          _ingredient(
            'expired',
            'หมดอายุแล้ว',
            now: now,
            expiryDate: DateTime(2026, 7, 23),
          ),
        ]..sort((a, b) => PantryExpiryPriority.compare(a, b, now: now));

        expect(items.map((item) => item.id), <String>[
          'today',
          'tomorrow',
          'later',
          'undated',
          'expired',
        ]);
      },
    );

    test('returns only non-expired items within seven days', () {
      final items = PantryExpiryPriority.useSoonItems(<Ingredient>[
        _ingredient(
          'today',
          'วันนี้',
          now: now,
          expiryDate: DateTime(2026, 7, 24),
        ),
        _ingredient(
          'seven',
          'เจ็ดวัน',
          now: now,
          expiryDate: DateTime(2026, 7, 31),
        ),
        _ingredient(
          'eight',
          'แปดวัน',
          now: now,
          expiryDate: DateTime(2026, 8, 1),
        ),
        _ingredient(
          'expired',
          'หมดอายุ',
          now: now,
          expiryDate: DateTime(2026, 7, 23),
        ),
      ], now: now);

      expect(items.map((item) => item.id), <String>['today', 'seven']);
    });

    test('uses calendar days instead of time-of-day differences', () {
      final today = _ingredient(
        'today',
        'วันนี้',
        now: now,
        expiryDate: DateTime(2026, 7, 24),
      );

      expect(PantryExpiryPriority.daysRemaining(today, now: now), 0);
      expect(PantryExpiryPriority.shouldUseSoon(today, now: now), isTrue);
      expect(
        PantryExpiryPriority.urgencyLabel(today, now: now),
        'ควรใช้วันนี้',
      );
    });
  });
}

Ingredient _ingredient(
  String id,
  String name, {
  required DateTime now,
  DateTime? expiryDate,
}) {
  return Ingredient(
    id: id,
    name: name,
    category: 'อาหาร',
    emoji: '🥬',
    quantity: 1,
    unit: 'ชิ้น',
    expiryDate: expiryDate,
    createdAt: now,
    updatedAt: now,
  );
}
