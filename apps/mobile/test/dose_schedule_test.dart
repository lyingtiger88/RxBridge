import 'package:flutter_test/flutter_test.dart';
import 'package:rxbridge/dose_schedule.dart';

void main() {
  test('every 12 hours with 08:00 start', () {
    expect(exampleTimes(intervalHours: 12, start: '08:00'), ['08:00', '20:00']);
  });
  test('every 8 hours with 07:00 start', () {
    expect(exampleTimes(intervalHours: 8, start: '07:00'), ['07:00', '15:00', '23:00']);
  });
  test('every 6 hours crossing midnight', () {
    expect(exampleTimes(intervalHours: 6, start: '22:30'), ['22:30', '04:30', '10:30', '16:30']);
  });
  test('invalid clock rejected', () {
    expect(() => exampleTimes(intervalHours: 8, start: '25:00'), throwsArgumentError);
  });
}
