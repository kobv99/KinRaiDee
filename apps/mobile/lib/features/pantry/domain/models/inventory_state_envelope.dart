import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../../core/models/ingredient.dart';
import 'cooking_history_entry.dart';

const int currentInventoryEnvelopeVersion = 1;
const int currentInventoryReaderVersion = 1;

class InventoryStateEnvelope {
  InventoryStateEnvelope({
    this.envelopeVersion = currentInventoryEnvelopeVersion,
    this.minimumReaderVersion = currentInventoryReaderVersion,
    this.capabilities = const <String>[],
    required this.revision,
    required this.lastAppliedTransactionId,
    required this.updatedAt,
    required List<Ingredient> pantry,
    required List<CookingHistoryEntry> history,
    String? checksum,
  }) : pantry = List<Ingredient>.unmodifiable(pantry),
       history = List<CookingHistoryEntry>.unmodifiable(history),
       checksum = checksum ?? '';

  final int envelopeVersion;
  final int minimumReaderVersion;
  final List<String> capabilities;
  final int revision;
  final String lastAppliedTransactionId;
  final DateTime updatedAt;
  final List<Ingredient> pantry;
  final List<CookingHistoryEntry> history;
  final String checksum;

  factory InventoryStateEnvelope.initial({
    required DateTime createdAt,
    List<Ingredient> pantry = const <Ingredient>[],
    List<CookingHistoryEntry> history = const <CookingHistoryEntry>[],
  }) {
    return InventoryStateEnvelope(
      revision: 0,
      lastAppliedTransactionId: '',
      updatedAt: createdAt,
      pantry: pantry,
      history: history,
    ).withComputedChecksum();
  }

  InventoryStateEnvelope copyWith({
    int? revision,
    String? lastAppliedTransactionId,
    DateTime? updatedAt,
    List<Ingredient>? pantry,
    List<CookingHistoryEntry>? history,
    List<String>? capabilities,
    String? checksum,
  }) {
    return InventoryStateEnvelope(
      envelopeVersion: envelopeVersion,
      minimumReaderVersion: minimumReaderVersion,
      capabilities: capabilities ?? this.capabilities,
      revision: revision ?? this.revision,
      lastAppliedTransactionId:
          lastAppliedTransactionId ?? this.lastAppliedTransactionId,
      updatedAt: updatedAt ?? this.updatedAt,
      pantry: pantry ?? this.pantry,
      history: history ?? this.history,
      checksum: checksum ?? this.checksum,
    );
  }

  InventoryStateEnvelope withComputedChecksum() {
    return InventoryStateEnvelope(
      envelopeVersion: envelopeVersion,
      minimumReaderVersion: minimumReaderVersion,
      capabilities: capabilities,
      revision: revision,
      lastAppliedTransactionId: lastAppliedTransactionId,
      updatedAt: updatedAt,
      pantry: pantry,
      history: history,
      checksum: calculateChecksum(unsignedJson),
    );
  }

  bool get hasValidChecksum =>
      checksum.isNotEmpty && checksum == calculateChecksum(unsignedJson);

  Map<String, dynamic> get unsignedJson {
    return <String, dynamic>{
      'envelopeVersion': envelopeVersion,
      'minimumReaderVersion': minimumReaderVersion,
      'capabilities': capabilities,
      'revision': revision,
      'lastAppliedTransactionId': lastAppliedTransactionId,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'pantry': pantry.map((item) => item.toJson()).toList(growable: false),
      'history': history.map((item) => item.toJson()).toList(growable: false),
    };
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{...unsignedJson, 'checksum': checksum};
  }

  factory InventoryStateEnvelope.fromJson(Map<String, dynamic> json) {
    final rawPantry = json['pantry'];
    final rawHistory = json['history'];
    final rawCapabilities = json['capabilities'];
    return InventoryStateEnvelope(
      envelopeVersion: _parseInt(json['envelopeVersion'], fallback: -1),
      minimumReaderVersion: _parseInt(
        json['minimumReaderVersion'],
        fallback: -1,
      ),
      capabilities: rawCapabilities is List
          ? rawCapabilities
                .map((item) => item.toString())
                .toList(growable: false)
          : const <String>[],
      revision: _parseInt(json['revision'], fallback: -1),
      lastAppliedTransactionId:
          json['lastAppliedTransactionId']?.toString() ?? '',
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      pantry: rawPantry is List
          ? rawPantry
                .whereType<Map>()
                .map(
                  (item) =>
                      Ingredient.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const <Ingredient>[],
      history: rawHistory is List
          ? rawHistory
                .whereType<Map>()
                .map(
                  (item) => CookingHistoryEntry.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const <CookingHistoryEntry>[],
      checksum: json['checksum']?.toString() ?? '',
    );
  }
}

String calculateChecksum(Object? value) {
  return sha256.convert(utf8.encode(canonicalJsonEncode(value))).toString();
}

String canonicalJsonEncode(Object? value) {
  return jsonEncode(_canonicalize(value));
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) {
    return value.map(_canonicalize).toList(growable: false);
  }
  if (value is num && !value.isFinite) {
    throw const FormatException('Non-finite numbers cannot be checksummed.');
  }
  return value;
}

int _parseInt(dynamic value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
