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
    );
  }

  bool get isExpired {
    if (expiryDate == null) {
      return false;
    }

    return expiryDate!.isBefore(DateTime.now());
  }

  int? get daysUntilExpiry {
    if (expiryDate == null) {
      return null;
    }

    return expiryDate!.difference(DateTime.now()).inDays;
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
