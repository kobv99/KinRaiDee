import '../../../../core/models/ingredient.dart';

class PantryExpiryPriority {
  const PantryExpiryPriority._();

  static const int useSoonWindowDays = 7;

  static int? daysRemaining(Ingredient ingredient, {DateTime? now}) {
    final expiryDate = ingredient.expiryDate;
    if (expiryDate == null) {
      return null;
    }

    final today = _dateOnly(now ?? DateTime.now());
    final expiry = _dateOnly(expiryDate);
    return expiry.difference(today).inDays;
  }

  static bool isExpired(Ingredient ingredient, {DateTime? now}) {
    final days = daysRemaining(ingredient, now: now);
    return days != null && days < 0;
  }

  static bool shouldUseSoon(Ingredient ingredient, {DateTime? now}) {
    final days = daysRemaining(ingredient, now: now);
    return days != null && days >= 0 && days <= useSoonWindowDays;
  }

  static List<Ingredient> useSoonItems(
    Iterable<Ingredient> ingredients, {
    DateTime? now,
    int? limit,
  }) {
    final sorted = ingredients
        .where((ingredient) => shouldUseSoon(ingredient, now: now))
        .toList(growable: false)
      ..sort((first, second) => compare(first, second, now: now));

    if (limit == null || limit >= sorted.length) {
      return List<Ingredient>.unmodifiable(sorted);
    }

    return List<Ingredient>.unmodifiable(sorted.take(limit));
  }

  static int compare(
    Ingredient first,
    Ingredient second, {
    DateTime? now,
  }) {
    final firstGroup = _priorityGroup(first, now: now);
    final secondGroup = _priorityGroup(second, now: now);
    final groupComparison = firstGroup.compareTo(secondGroup);
    if (groupComparison != 0) {
      return groupComparison;
    }

    final firstDays = daysRemaining(first, now: now);
    final secondDays = daysRemaining(second, now: now);
    if (firstDays != null && secondDays != null) {
      final expiryComparison = firstDays.compareTo(secondDays);
      if (expiryComparison != 0) {
        return expiryComparison;
      }
    }

    final updatedComparison = second.updatedAt.compareTo(first.updatedAt);
    if (updatedComparison != 0) {
      return updatedComparison;
    }

    if (first.isFavorite != second.isFavorite) {
      return first.isFavorite ? -1 : 1;
    }

    return first.name.compareTo(second.name);
  }

  static String urgencyLabel(Ingredient ingredient, {DateTime? now}) {
    final days = daysRemaining(ingredient, now: now);
    if (days == null) {
      return 'ไม่ระบุวันหมดอายุ';
    }
    if (days < 0) {
      return 'หมดอายุแล้ว';
    }
    if (days == 0) {
      return 'ควรใช้วันนี้';
    }
    if (days == 1) {
      return 'หมดอายุพรุ่งนี้';
    }
    return 'เหลืออีก $days วัน';
  }

  static int _priorityGroup(Ingredient ingredient, {DateTime? now}) {
    final days = daysRemaining(ingredient, now: now);
    if (days == null) {
      return 3;
    }
    if (days < 0) {
      return 4;
    }
    if (days <= useSoonWindowDays) {
      return 0;
    }
    return 1;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}