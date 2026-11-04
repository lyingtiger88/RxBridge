import 'package:flutter/material.dart';

/// An isolated, in-memory synthetic demo. Never accepts real patient records.
class LabOrder {
  final String id;
  final String testName;
  final DateTime dueAt;
  final String patientId;
  final String clinicianNote;
  final String? result;
  final String? units;
  final String? laboratoryNote;
  final DateTime? reportedAt;

  const LabOrder({
    required this.id, required this.testName, required this.dueAt,
    required this.patientId, this.clinicianNote = '', this.result, this.units,
    this.laboratoryNote, this.reportedAt,
  });

  bool get completed => result != null;

  LabOrder withResult(String value, String resultUnits, String note) => LabOrder(
    id: id, testName: testName, dueAt: dueAt, patientId: patientId,
    clinicianNote: clinicianNote, result: value, units: resultUnits,
    laboratoryNote: note, reportedAt: DateTime.now(),
  );
}

class GlucoseReading {
  final int value;
  final DateTime measuredAt;
  final String context;
  final String unit;
  const GlucoseReading(this.value, this.measuredAt, this.context, {this.unit = 'mg/dL'});
}

/// Shared only while the app process stays alive. No API or durable persistence.
class CareDemoStore extends ChangeNotifier {
  CareDemoStore._();
  static final CareDemoStore instance = CareDemoStore._();

  final String patientId = 'TEST-PATIENT-001';
  List<TimeOfDay> _glucoseTimes = const [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 20, minute: 0)];
  List<TimeOfDay> get glucoseTimes => List.unmodifiable(_glucoseTimes);

  final List<GlucoseReading> readings = [];
  final List<LabOrder> orders = [
    LabOrder(id: 'LAB-TEST-001', testName: 'HbA1c (نمونه)', dueAt: DateTime(2026, 12, 15), patientId: 'TEST-PATIENT-001', clinicianNote: 'ارجاع آزمایشی؛ فاقد ارزش درمانی'),
    LabOrder(id: 'LAB-TEST-002', testName: 'CBC (نمونه)', dueAt: DateTime(2026, 12, 20), patientId: 'TEST-PATIENT-001'),
  ];

  void setGlucosePlan(List<TimeOfDay> times) {
    if (times.isEmpty || times.length > 8) throw ArgumentError('1 to 8 times per day required');
    final minutes = times.map((t) => t.hour * 60 + t.minute).toSet();
    if (minutes.length != times.length) throw ArgumentError('Duplicate times');
    _glucoseTimes = [...times]..sort((a,b) => (a.hour*60+a.minute).compareTo(b.hour*60+b.minute));
    notifyListeners();
  }

  void addOrder(String testName, DateTime dueAt, String note) {
    if (testName.trim().isEmpty || testName.length > 100) throw ArgumentError('Invalid test');
    if (dueAt.isBefore(DateTime.now().subtract(const Duration(days: 1)))) throw ArgumentError('Invalid due date');
    orders.add(LabOrder(
      id: 'LAB-TEST-${DateTime.now().microsecondsSinceEpoch}',
      testName: testName.trim(), dueAt: dueAt,
      patientId: patientId, clinicianNote: note.trim(),
    ));
    notifyListeners();
  }

  bool saveLabResult(String id, String result, String unit, String note) {
    final idx = orders.indexWhere((o) => o.id == id && !o.completed);
    if (idx < 0 || result.trim().isEmpty || result.length > 150 || note.length > 500) return false;
    orders[idx] = orders[idx].withResult(result.trim(), unit.trim(), note.trim());
    notifyListeners();
    return true;
  }

  void addGlucoseReading(int value, DateTime measuredAt, String context) {
    // Broadly validate measurement entry only, never diagnose or recommend insulin.
    if (value < 1 || value > 1000 || measuredAt.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      throw ArgumentError('Invalid measurement');
    }
    readings.add(GlucoseReading(value, measuredAt, context));
    readings.sort((a,b) => b.measuredAt.compareTo(a.measuredAt));
    notifyListeners();
  }
}

String clockLabel(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

List<TimeOfDay> fixedIntervalTimes(int count, {int startHour = 8}) {
  if (count < 1 || count > 8 || 24 % count != 0 || startHour < 0 || startHour > 23) {
    throw ArgumentError('Count must divide 24: 1, 2, 3, 4, 6 or 8');
  }
  return List.generate(count, (i) => TimeOfDay(hour: (startHour + i * (24 ~/ count)) % 24, minute: 0));
}
