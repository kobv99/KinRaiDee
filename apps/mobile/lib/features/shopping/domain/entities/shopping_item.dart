import 'shopping_category.dart';
import 'shopping_item_status.dart';
import 'shopping_purchase.dart';
import 'shopping_source.dart';

const int currentShoppingItemVersion = 2;

class ShoppingItem {
  ShoppingItem({
    this.metadataVersion = currentShoppingItemVersion,
    required this.id,
    required this.canonicalIngredientId,
    required this.displayName,
    required this.quantity,
    required this.unitId,
    required this.category,
    required this.source,
    this.sourceReferenceId,
    List<String> sourceReferenceIds = const <String>[],
    this.status = ShoppingItemStatus.active,
    this.purchase,
    required this.createdAt,
    required this.updatedAt,
  }) : sourceReferenceIds = _normalizedReferences(
         sourceReferenceId,
         sourceReferenceIds,
       );

  final int metadataVersion;
  final String id;
  final String canonicalIngredientId;
  final String displayName;
  final double quantity;
  final String unitId;
  final ShoppingCategory category;
  final ShoppingSource source;
  final String? sourceReferenceId;
  final List<String> sourceReferenceIds;
  final ShoppingItemStatus status;
  final ShoppingPurchase? purchase;
  final DateTime createdAt;
  final DateTime updatedAt;

  ShoppingItem copyWith({
    int? metadataVersion,
    double? quantity,
    String? displayName,
    String? unitId,
    ShoppingCategory? category,
    ShoppingSource? source,
    String? sourceReferenceId,
    List<String>? sourceReferenceIds,
    ShoppingItemStatus? status,
    ShoppingPurchase? purchase,
    bool clearPurchase = false,
    DateTime? updatedAt,
  }) {
    return ShoppingItem(
      metadataVersion: metadataVersion ?? this.metadataVersion,
      id: id,
      canonicalIngredientId: canonicalIngredientId,
      displayName: displayName ?? this.displayName,
      quantity: quantity ?? this.quantity,
      unitId: unitId ?? this.unitId,
      category: category ?? this.category,
      source: source ?? this.source,
      sourceReferenceId: sourceReferenceId ?? this.sourceReferenceId,
      sourceReferenceIds: sourceReferenceIds ?? this.sourceReferenceIds,
      status: status ?? this.status,
      purchase: clearPurchase ? null : purchase ?? this.purchase,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'metadataVersion': metadataVersion,
      'id': id,
      'canonicalIngredientId': canonicalIngredientId,
      'displayName': displayName,
      'quantity': quantity,
      'unitId': unitId,
      'category': category.name,
      'source': source.name,
      'sourceReferenceId': sourceReferenceId,
      'sourceReferenceIds': sourceReferenceIds,
      'status': status.name,
      'purchase': purchase?.toJson(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    final createdAt = _date(json['createdAt']);
    final rawPurchase = json['purchase'];
    final rawSourceReferenceIds = json['sourceReferenceIds'];
    final legacySourceReference = _optionalString(json['sourceReferenceId']);
    final sourceReferences = rawSourceReferenceIds is List
        ? rawSourceReferenceIds
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
        : <String>[?legacySourceReference];
    sourceReferences.sort();
    return ShoppingItem(
      metadataVersion: _integer(json['metadataVersion'], fallback: -1),
      id: json['id']?.toString() ?? '',
      canonicalIngredientId: json['canonicalIngredientId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      quantity: _double(json['quantity']),
      unitId: json['unitId']?.toString() ?? '',
      category: ShoppingCategory.values.firstWhere(
        (category) => category.name == json['category']?.toString(),
        orElse: () => throw const FormatException('Unknown Shopping category.'),
      ),
      source: ShoppingSource.values.firstWhere(
        (source) => source.name == json['source']?.toString(),
        orElse: () => throw const FormatException('Unknown Shopping source.'),
      ),
      sourceReferenceId: legacySourceReference,
      sourceReferenceIds: List<String>.unmodifiable(sourceReferences),
      status: ShoppingItemStatus.values.firstWhere(
        (status) => status.name == json['status']?.toString(),
        orElse: () => ShoppingItemStatus.active,
      ),
      purchase: rawPurchase is Map
          ? ShoppingPurchase.fromJson(Map<String, dynamic>.from(rawPurchase))
          : null,
      createdAt: createdAt,
      updatedAt: _date(json['updatedAt'], fallback: createdAt),
    );
  }
}

double _double(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? double.nan;
}

int _integer(dynamic value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime _date(dynamic value, {DateTime? fallback}) {
  return DateTime.tryParse(value?.toString() ?? '')?.toUtc() ??
      fallback ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

String? _optionalString(dynamic value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}

List<String> _normalizedReferences(
  String? legacyReference,
  List<String> references,
) {
  final normalized = <String>{
    ...references.map((value) => value.trim()),
    if (legacyReference != null) legacyReference.trim(),
  }.where((value) => value.isNotEmpty).toList()..sort();
  return List<String>.unmodifiable(normalized);
}
