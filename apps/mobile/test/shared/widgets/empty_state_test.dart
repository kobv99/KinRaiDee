import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/widgets/empty_state.dart';

void main() {
  testWidgets('pantry empty state does not overflow on a short screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 300);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: const [
              SliverToBoxAdapter(child: SizedBox(height: 170)),
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.kitchen_outlined,
                  title: 'ยังไม่มีวัตถุดิบ',
                  description:
                      'พิมพ์ชื่อวัตถุดิบด้านบน หรือกดปุ่มเพิ่มวัตถุดิบเพื่อเริ่มใช้งาน',
                  actionLabel: 'เพิ่มวัตถุดิบ',
                ),
              ),
            ],
          ),
          bottomNavigationBar: const SizedBox(height: 88),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ยังไม่มีวัตถุดิบ'), findsOneWidget);
  });
}
