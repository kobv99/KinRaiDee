import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/substitution/data/knowledge_base_loader.dart';

void main() {
  test('loads immutable data and reuses one cached asset read', () async {
    final bundle = _Bundle(
      jsonEncode({
        'schemaVersion': 1,
        'records': [
          {
            'id': 'a-to-b',
            'originalIngredientId': 'a',
            'substituteIngredientId': 'b',
            'confidence': 0.9,
            'flavorSimilarity': 0.8,
            'textureSimilarity': 0.7,
            'cookingMethodCompatibility': 0.6,
            'suitableDishes': ['ทอด'],
            'unsuitableDishes': ['อบ'],
            'category': 'test',
            'notes': 'ใช้แทนได้',
            'flavorDifference': 'ต่างเล็กน้อย',
            'textureDifference': 'นุ่มกว่า',
            'limitations': 'ไม่เหมาะกับการอบ',
          },
        ],
      }),
    );
    final loader = KnowledgeBaseLoader(bundle: bundle);

    final first = await loader.load();
    final second = await loader.load();

    expect(identical(first, second), isTrue);
    expect(bundle.readCount, 1);
    expect(first.single.originalIngredientId, 'a');
    expect(() => first.add(first.single), throwsUnsupportedError);
  });
}

class _Bundle extends CachingAssetBundle {
  _Bundle(this.source);
  final String source;
  int readCount = 0;

  @override
  Future<ByteData> load(String key) async {
    readCount += 1;
    final bytes = Uint8List.fromList(utf8.encode(source));
    return ByteData.sublistView(bytes);
  }
}
