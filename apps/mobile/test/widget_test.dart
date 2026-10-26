import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxbridge/main.dart';

void main() {
  testWidgets('dashboard navigates to patient, prescription and About', (tester) async {
    await tester.pumpWidget(const RxBridgeApp());
    expect(find.text('داشبورد RxBridge'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.person_outline).last);
    await tester.pumpAndSettle();
    expect(find.text('پرونده بیمار'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.medication_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('نسخه‌نویسی'), findsOneWidget);
    await tester.tap(find.byTooltip('معرفی نرم‌افزار'));
    await tester.pumpAndSettle();
    expect(find.text('درباره RxBridge'), findsOneWidget);
  });
}
