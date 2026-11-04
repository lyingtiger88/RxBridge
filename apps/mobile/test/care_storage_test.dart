import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxbridge/care_demo_store.dart';
import 'package:rxbridge/care_storage.dart';

void main() {
  test('demo snapshot survives a simulated app restart', () async {
    final disk = MemoryCareSnapshotStorage();
    final first = CareDemoStore.forTesting();
    await first.attachStorage(disk);
    first.setGlucosePlan(const [
      TimeOfDay(hour: 7, minute: 15), TimeOfDay(hour: 19, minute: 15),
    ]);
    first.addGlucoseReading(123, DateTime.now().subtract(const Duration(minutes: 3)), 'ناشتا');
    first.addOrder('TEST-CBC', DateTime.now().add(const Duration(days: 2)), 'synthetic');
    final id = first.orders.last.id;
    expect(first.saveLabResult(id, 'TEST RESULT', 'sample', 'dummy'), isTrue);
    await first.flushPendingWrites();

    final second = CareDemoStore.forTesting();
    await second.attachStorage(disk);
    expect(second.glucoseTimes.map(clockLabel), ['07:15', '19:15']);
    expect(second.readings.single.value, 123);
    expect(second.orders.last.completed, isTrue);
    expect(second.orders.last.result, 'TEST RESULT');
  });

  test('invalid snapshot is rejected, no partial application', () async {
    final disk = MemoryCareSnapshotStorage();
    disk.snapshot = {'schema': 99, 'patientId': 'TEST-PATIENT-001'};
    final store = CareDemoStore.forTesting();
    await expectLater(store.attachStorage(disk), throwsFormatException);
    expect(store.readings, isEmpty);
    expect(store.orders.length, 2);
  });
}
