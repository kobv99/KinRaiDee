import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:mobile/app/app.dart';
import 'package:mobile/core/services/storage_service.dart';

void main() {
  late Directory tempDirectory;
  late Box<dynamic> pantryBox;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'kinraidee_widget_test_',
    );
    Hive.init(tempDirectory.path);
    pantryBox = await Hive.openBox<dynamic>(StorageService.pantryBoxName);
  });

  tearDownAll(() async {
    stdout.writeln(
      '[widget_test] tearDownAll: before pantryBox.flush '
      '(name=${pantryBox.name}, open=${pantryBox.isOpen})',
    );
    await pantryBox.flush();
    stdout.writeln('[widget_test] tearDownAll: after pantryBox.flush');

    stdout.writeln('[widget_test] tearDownAll: before pantryBox.close');
    await pantryBox.close();
    stdout.writeln('[widget_test] tearDownAll: after pantryBox.close');

    final exists = await tempDirectory.exists();
    stdout.writeln(
      '[widget_test] tearDownAll: temp directory exists = $exists',
    );
    if (exists) {
      stdout.writeln('[widget_test] tearDownAll: before directory delete');
      await tempDirectory.delete(recursive: true);
      stdout.writeln('[widget_test] tearDownAll: after directory delete');
    }
    stdout.writeln('[widget_test] tearDownAll: complete');
  });

  testWidgets('KinRaiDee app loads and releases owned resources', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: KinRaiDeeApp()));
    await tester.pump();

    expect(find.byType(KinRaiDeeApp), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(find.byType(KinRaiDeeApp), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
