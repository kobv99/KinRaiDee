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

  Future<void> flushCheckpoint(String label) async {
    stdout.writeln(
      '[widget_test] $label: before pantryBox.flush '
      '(open=${pantryBox.isOpen}, length=${pantryBox.length}, '
      'keys=${pantryBox.keys.toList()})',
    );
    await pantryBox.flush();
    stdout.writeln('[widget_test] $label: after pantryBox.flush');
  }

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'kinraidee_widget_test_',
    );
    Hive.init(tempDirectory.path);
    pantryBox = await Hive.openBox<dynamic>(StorageService.pantryBoxName);
    await flushCheckpoint('setUpAll-after-open');
  });

  tearDownAll(() async {
    await flushCheckpoint('tearDownAll');

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
    await flushCheckpoint('test-before-mount');

    await tester.pumpWidget(const ProviderScope(child: KinRaiDeeApp()));
    await tester.pump();

    expect(find.byType(KinRaiDeeApp), findsOneWidget);
    expect(tester.takeException(), isNull);
    await flushCheckpoint('test-after-mount');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(find.byType(KinRaiDeeApp), findsNothing);
    expect(tester.takeException(), isNull);
    await flushCheckpoint('test-after-unmount');
  });
}
