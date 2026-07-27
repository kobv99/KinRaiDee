import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:mobile/app/app.dart';
import 'package:mobile/core/services/storage_service.dart';

void main() {
  testWidgets('KinRaiDee app loads and releases owned resources', (
    WidgetTester tester,
  ) async {
    late Directory tempDirectory;

    await tester.runAsync(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'kinraidee_widget_test_',
      );
      Hive.init(tempDirectory.path);
      await Hive.openBox<dynamic>(StorageService.pantryBoxName);
    });

    await tester.pumpWidget(const ProviderScope(child: KinRaiDeeApp()));
    await tester.pump();

    expect(find.byType(KinRaiDeeApp), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(find.byType(KinRaiDeeApp), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      await Hive.close();
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
  });
}
