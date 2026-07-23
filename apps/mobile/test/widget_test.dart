import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app/app.dart';

void main() {
  testWidgets('KinRaiDee app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const KinRaiDeeApp());

    expect(find.byType(KinRaiDeeApp), findsOneWidget);
  });
}
