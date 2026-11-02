import 'package:flutter/material.dart' show Scrollable;
import 'package:flutter_test/flutter_test.dart';
import 'package:rxbridge/main.dart';

void main() {
  testWidgets('role landing opens patient workspace and private record', (tester) async {
    await tester.pumpWidget(const RxBridgeApp());
    expect(find.text('به RxBridge خوش آمدید'), findsOneWidget);
    await tester.tap(find.text('ورود به پنل بیمار'));
    await tester.pumpAndSettle();
    expect(find.text('سلام، خوش آمدید'), findsOneWidget);
    await tester.tap(find.text('پرونده من').last);
    await tester.pumpAndSettle();
    expect(find.text('پرونده سلامت من'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('بخش محرمانه'), 250, scrollable: find.byType(Scrollable).last);
    expect(find.text('بخش محرمانه'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('مجوزهای دسترسی'), 250, scrollable: find.byType(Scrollable).last);
    expect(find.text('مجوزهای دسترسی'), findsOneWidget);
  });

  testWidgets('doctor has separate patient and prescription workspaces', (tester) async {
    await tester.pumpWidget(const RxBridgeApp());
    await tester.tap(find.text('ورود به پنل پزشک'));
    await tester.pumpAndSettle();
    expect(find.text('صبح بخیر، پزشک'), findsOneWidget);
    await tester.tap(find.text('بیماران'));
    await tester.pumpAndSettle();
    expect(find.text('بیماران من'), findsOneWidget);
    await tester.tap(find.text('نسخه‌ها').last);
    await tester.pumpAndSettle();
    expect(find.text('نسخه‌ها'), findsWidgets);
  });

  testWidgets('pharmacy and insurer roles open their own dashboards', (tester) async {
    await tester.pumpWidget(const RxBridgeApp());
    await tester.tap(find.text('ورود به پنل داروساز'));
    await tester.pumpAndSettle();
    expect(find.text('داشبورد داروخانه'), findsOneWidget);
    await tester.tap(find.byTooltip('تغییر نقش'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ورود به پنل مسئول بیمه'), 250, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('ورود به پنل مسئول بیمه'));
    await tester.pumpAndSettle();
    expect(find.text('داشبورد بیمه'), findsOneWidget);
  });
}
