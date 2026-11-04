import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxbridge/care_demo_store.dart';

void main() {
  test('two and three daily intervals are calculated without clinical advice', () {
    expect(fixedIntervalTimes(2).map(clockLabel).toList(), ['08:00', '20:00']);
    expect(fixedIntervalTimes(3).map(clockLabel).toList(), ['08:00', '16:00', '00:00']);
    expect(() => fixedIntervalTimes(5), throwsArgumentError);
  });

  test('doctor schedule and patient glucose entry share synthetic in-memory state', () {
    final store = CareDemoStore.instance;
    store.setGlucosePlan(const [TimeOfDay(hour: 7,minute: 30), TimeOfDay(hour: 19, minute: 30)]);
    expect(store.glucoseTimes.map(clockLabel), ['07:30', '19:30']);
    store.addGlucoseReading(110, DateTime.now().subtract(const Duration(minutes: 5)), 'ناشتا');
    expect(store.readings.first.value, 110);
    expect(store.readings.first.unit, 'mg/dL');
  });

  test('lab can publish report against an order, which becomes visible to patient and doctor', () {
    final store=CareDemoStore.instance;
    final count=store.orders.length;
    store.addOrder('TEST-FERRITIN',DateTime.now().add(const Duration(days: 2)),'نمونه');
    expect(store.orders.length,count+1);
    final order=store.orders.last;
    expect(order.completed,isFalse);
    expect(store.saveLabResult(order.id,'TEST RESULT','unit','توضیح آزمایشی'),isTrue);
    expect(store.orders.last.completed,isTrue);
    expect(store.orders.last.laboratoryNote,'توضیح آزمایشی');
    expect(store.saveLabResult(order.id,'duplicate','',''),isFalse);
  });

  test('invalid blood glucose entries are rejected', () {
    final store=CareDemoStore.instance;
    expect(() => store.addGlucoseReading(-5,DateTime.now(),'ناشتا'),throwsArgumentError);
    expect(() => store.addGlucoseReading(200,DateTime.now().add(const Duration(days:1)),'ناشتا'),throwsArgumentError);
  });
}
