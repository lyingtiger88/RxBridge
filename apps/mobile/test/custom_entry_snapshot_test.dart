import 'package:flutter_test/flutter_test.dart';
import 'package:rxbridge/custom_entry_snapshot.dart';

void main() {
  String snapshot({String interval = 'هر ۱۲ ساعت', String startTime = '08:00'}) =>
      buildCustomEntrySnapshot(
        patient: 'TEST-001',
        drug: 'TEST-TABLET-A',
        amount: '1',
        days: '5',
        instructions: '',
        form: 'سایر',
        route: 'خوراکی',
        frequency: 'سایر',
        interval: interval,
        startTime: startTime,
        custom: 'یک واحد',
        reason: 'آزمایش',
      );

  test('changing interval invalidates custom-entry confirmation', () {
    expect(snapshot(interval: 'هر ۱۲ ساعت'), isNot(snapshot(interval: 'هر ۸ ساعت')));
  });

  test('changing start time invalidates custom-entry confirmation', () {
    expect(snapshot(startTime: '08:00'), isNot(snapshot(startTime: '09:00')));
  });

  test('unchanged fields preserve the confirmation snapshot', () {
    expect(snapshot(), snapshot());
  });
}
