import 'shopping_item.dart';
import 'shopping_status.dart';

const int currentShoppingListVersion = 1;

class ShoppingList {
  ShoppingList({
    this.metadataVersion = currentShoppingListVersion,
    required this.id,
    required this.name,
    this.status = ShoppingStatus.active,
    this.revision = 0,
    required List<ShoppingItem> items,
    required this.createdAt,
    required this.updatedAt,
  }) : items = List<ShoppingItem>.unmodifiable(items);

  final int metadataVersion;
  final String id;
  final String name;
  final ShoppingStatus status;
  final int revision;
  final List<ShoppingItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  ShoppingList copyWith({
    String? name,
    ShoppingStatus? status,
    int? revision,
    List<ShoppingItem>? items,
    DateTime? updatedAt,
  }) {
    return ShoppingList(
      metadataVersion: metadataVersion,
      id: id,
      name: name ?? this.name,
      status: status ?? this.status,
      revision: revision ?? this.revision,
      items: items ?? this.items,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'metadataVersion': metadataVersion,
      'id': id,
      'name': name,
      'status': status.name,
      'revision': revision,
      'items': items.map((item) => item.toJson()).toList(growable: false),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final createdAt = _date(json['createdAt']);
    return ShoppingList(
      metadataVersion: _integer(json['metadataVersion'], fallback: -1),
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      status: ShoppingStatus.values.firstWhere(
        (status) => status.name == json['status']?.toString(),
        orElse: () => throw const FormatException('Unknown Shopping status.'),
      ),
      revision: _integer(json['revision'], fallback: -1),
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) =>
                      ShoppingItem.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const <ShoppingItem>[],
      createdAt: createdAt,
      updatedAt: _date(json['updatedAt'], fallback: createdAt),
    );
  }
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
