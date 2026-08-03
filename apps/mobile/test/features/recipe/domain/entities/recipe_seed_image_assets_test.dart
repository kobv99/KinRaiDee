import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every structured image.assetPath declared in assets/recipes/*.json '
      'resolves to a file that actually exists on disk', () {
    final recipesDir = Directory('assets/recipes');
    expect(
      recipesDir.existsSync(),
      isTrue,
      reason: 'expected to run flutter test from apps/mobile',
    );

    final jsonFiles = recipesDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList();
    expect(jsonFiles, isNotEmpty);

    var checkedAtLeastOneAssetPath = false;

    for (final file in jsonFiles) {
      final decoded = jsonDecode(file.readAsStringSync());
      final recipes = decoded is List ? decoded : <dynamic>[decoded];

      for (final recipe in recipes) {
        if (recipe is! Map || recipe['image'] is! Map) {
          continue;
        }
        final image = recipe['image'] as Map;
        final assetPath = image['assetPath'];
        if (assetPath is! String) {
          continue;
        }

        checkedAtLeastOneAssetPath = true;
        final assetFile = File(assetPath);
        expect(
          assetFile.existsSync(),
          isTrue,
          reason:
              'Recipe "${recipe['id']}" in ${file.path} declares '
              'image.assetPath "$assetPath", which does not exist on disk.',
        );
      }
    }

    expect(
      checkedAtLeastOneAssetPath,
      isTrue,
      reason: 'expected at least one seed recipe to declare image.assetPath',
    );
  });
}
