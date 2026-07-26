import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:mobile/app/app.dart';
import 'package:mobile/core/services/storage_service.dart';

void main() {
  late Directory tempDirectory;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'kinraidee_widget_test_',
    );
    Hive.init(tempDirectory.path);
    await Hive.openBox<dynamic>(StorageService.pantryBoxName);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  testWidgets('KinRaiDee app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KinRaiDeeApp()));
    await tester.pump();

    expect(find.byType(KinRaiDeeApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
