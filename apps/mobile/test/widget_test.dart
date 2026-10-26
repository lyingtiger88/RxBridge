import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxbridge/main.dart';

void main() {
  testWidgets('RxBridge demo opens editor and About', (tester) async {
    await tester.pumpWidget(const RxBridgeApp());
    expect(find.text('ثبت نسخه آزمایشی'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    expect(find.text('درباره RxBridge'), findsOneWidget);
  });
}
