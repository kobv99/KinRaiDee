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

    stdout.writeln('[widget_test] before setup runAsync');
    await tester.runAsync(() async {
      stdout.writeln('[widget_test] setup runAsync entered');
      tempDirectory = await Directory.systemTemp.createTemp(
        'kinraidee_widget_test_',
      );
      stdout.writeln('[widget_test] temp directory created');
      Hive.init(tempDirectory.path);
      stdout.writeln('[widget_test] before Hive.openBox');
      await Hive.openBox<dynamic>(StorageService.pantryBoxName);
      stdout.writeln('[widget_test] after Hive.openBox');
    });
    stdout.writeln('[widget_test] after setup runAsync');

    stdout.writeln('[widget_test] before pumpWidget app');
    await tester.pumpWidget(const ProviderScope(child: KinRaiDeeApp()));
    stdout.writeln('[widget_test] after pumpWidget app');

    stdout.writeln('[widget_test] before pump app');
    await tester.pump();
    stdout.writeln('[widget_test] after pump app');

    expect(find.byType(KinRaiDeeApp), findsOneWidget);
    expect(tester.takeException(), isNull);

    stdout.writeln('[widget_test] before pumpWidget unmount');
    await tester.pumpWidget(const SizedBox.shrink());
    stdout.writeln('[widget_test] after pumpWidget unmount');

    stdout.writeln('[widget_test] before pump unmount');
    await tester.pump();
    stdout.writeln('[widget_test] after pump unmount');

    expect(find.byType(KinRaiDeeApp), findsNothing);
    expect(tester.takeException(), isNull);

    stdout.writeln('[widget_test] before cleanup runAsync');
    await tester.runAsync(() async {
      stdout.writeln('[widget_test] cleanup runAsync entered');
      stdout.writeln('[widget_test] before Hive.close');
      await Hive.close();
      stdout.writeln('[widget_test] after Hive.close');
      if (await tempDirectory.exists()) {
        stdout.writeln('[widget_test] before temp directory delete');
        await tempDirectory.delete(recursive: true);
        stdout.writeln('[widget_test] after temp directory delete');
      }
    });
    stdout.writeln('[widget_test] after cleanup runAsync');
  });
}
