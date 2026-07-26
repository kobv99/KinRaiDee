import '../time/app_clock.dart';

const int currentPantryIngredientSchemaVersion = 2;

enum CanonicalMappingStatus { mapped, unmapped, legacy }

class Ingredient {
  final String id;

  /// ชื่อวัตถุดิบ เช่น หมูสามชั้น, ไข่ไก่
  final String name;

  /// ประเภทหลัก เช่น เนื้อสัตว์, ไข่, ผัก
  final String category;

  /// Emoji ของชนิดอาหาร เช่น 🐷 🥚 🥬
  final String emoji;

  /// จำนวนคงเหลือ
  final double quantity;

  /// หน่วย เช่น kg, g, ฟอง, ขวด
  final String unit;

  /// วันหมดอายุ
  final DateTime? expiryDate;

  /// วันที่เพิ่มเข้าระบบ
  final DateTime createdAt;

  /// วันที่แก้ไขล่าสุด
  final DateTime updatedAt;

  /// รายการโปรดสำหรับเข้าถึงวัตถุดิบที่ใช้บ่อยได้เร็วขึ้น
  final bool isFavorite;

  /// Version of the persisted pantry-lot model.
  final int schemaVersion;

  /// Stable identity shared by Pantry, Recipe, Recommendation, and Shopping.
  ///
  /// Legacy records may be empty until startup migration completes.
  final String canonicalIngredientId;

  /// Stable unit identity. [unit] remains the user-facing display value.
  final String canonicalUnitId;

  final CanonicalMappingStatus canonicalMappingStatus;

  const Ingredient({
    required this.id,
    required this.name,
    required this.category,
    required this.emoji,
    required this.quantity,
    required this.unit,
    this.expiryDate,
    required this.createdAt,
    required this.updatedAt,
    this.isFavorite = false,
    this.schemaVersion = currentPantryIngredientSchemaVersion,
    this.canonicalIngredientId = '',
    this.canonicalUnitId = '',
    this.canonicalMappingStatus = CanonicalMappingStatus.legacy,
  });

  Ingredient copyWith({
    String? id,
    String? name,
    String? category,
    String? emoji,
    double? quantity,
    String? unit,
    DateTime? expiryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
    int? schemaVersion,
    String? canonicalIngredientId,
    String? canonicalUnitId,
    CanonicalMappingStatus? canonicalMappingStatus,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      emoji: emoji ?? this.emoji,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      canonicalIngredientId:
          canonicalIngredientId ?? this.canonicalIngredientId,
      canonicalUnitId: canonicalUnitId ?? this.canonicalUnitId,
      canonicalMappingStatus:
          canonicalMappingStatus ?? this.canonicalMappingStatus,
    );
  }

  bool get isExpired => isExpiredAt(systemAppClock.now());

  bool isExpiredAt(DateTime now) {
    final expiry = expiryDate;
    if (expiry == null) {
      return false;
    }

    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
    return expiryDay.isBefore(today);
  }

  int? get daysUntilExpiry => daysUntilExpiryAt(systemAppClock.now());

  int? daysUntilExpiryAt(DateTime now) {
    final expiry = expiryDate;
    if (expiry == null) {
      return null;
    }

    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
    return expiryDay.difference(today).inDays;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'category': category,
      'emoji': emoji,
      'quantity': quantity,
      'unit': unit,
      'expiryDate': expiryDate?.toUtc().toIso8601String(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'isFavorite': isFavorite,
      'schemaVersion': schemaVersion,
      'canonicalIngredientId': canonicalIngredientId,
      'canonicalUnitId': canonicalUnitId,
      'canonicalMappingStatus': canonicalMappingStatus.name,
    };
  }

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return Ingredient(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '',
      quantity: _parseDouble(json['quantity']),
      unit: json['unit']?.toString() ?? '',
      expiryDate: DateTime.tryParse(
        json['expiryDate']?.toString() ?? '',
      )?.toUtc(),
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toUtc() ??
          createdAt,
      isFavorite: _parseBool(json['isFavorite']),
      schemaVersion: _parseInt(
        json['schemaVersion'],
        fallback: json.containsKey('canonicalIngredientId')
            ? currentPantryIngredientSchemaVersion
            : 1,
      ),
      canonicalIngredientId: json['canonicalIngredientId']?.toString() ?? '',
      canonicalUnitId: json['canonicalUnitId']?.toString() ?? '',
      canonicalMappingStatus: CanonicalMappingStatus.values.firstWhere(
        (status) => status.name == json['canonicalMappingStatus']?.toString(),
        orElse: () => json.containsKey('canonicalIngredientId')
            ? CanonicalMappingStatus.unmapped
            : CanonicalMappingStatus.legacy,
      ),
    );
  }

  @override
  String toString() {
    return '''
Ingredient(
  id: $id,
  name: $name,
  category: $category,
  emoji: $emoji,
  quantity: $quantity $unit,
  expiryDate: $expiryDate,
  isFavorite: $isFavorite
)
''';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Ingredient && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

double _parseDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? double.nan;
}

bool _parseBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  return value?.toString().toLowerCase() == 'true';
}

int _parseInt(dynamic value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
