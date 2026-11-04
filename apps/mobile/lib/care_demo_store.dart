import 'package:flutter/material.dart';
import 'care_storage.dart';

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
  @visibleForTesting
  CareDemoStore.forTesting();
  static final CareDemoStore instance = CareDemoStore._();

  CareSnapshotStorage? _storage;
  Future<void> _pendingWrite = Future<void>.value();

  /// Hydrate before the app starts. The demo keeps synchronous screen actions
  /// while writes are serialized asynchronously through this adapter.
  Future<void> attachStorage(CareSnapshotStorage storage) async {
    if (_storage != null) throw StateError('Storage already attached');
    final snapshot = await storage.read();
    if (snapshot != null) {
      _restoreSnapshot(snapshot);
    }
    _storage = storage;
    notifyListeners();
  }

  Future<void> flushPendingWrites() => _pendingWrite;

  Map<String, dynamic> toSnapshot() => {
    'schema': 1,
    'patientId': patientId,
    'glucoseMinutes': _glucoseTimes.map((t) => t.hour * 60 + t.minute).toList(),
    'glucoseReadings': readings.map((r) => {
      'value': r.value,
      'measuredAt': r.measuredAt.toIso8601String(),
      'context': r.context,
      'unit': r.unit,
    }).toList(),
    'labOrders': orders.map((o) => {
      'id': o.id, 'testName': o.testName,
      'dueAt': o.dueAt.toIso8601String(),
      'patientId': o.patientId, 'clinicianNote': o.clinicianNote,
      'result': o.result, 'units': o.units, 'laboratoryNote': o.laboratoryNote,
      'reportedAt': o.reportedAt?.toIso8601String(),
    }).toList(),
  };

  void _restoreSnapshot(Map<String, dynamic> snapshot) {
    if (snapshot['schema'] != 1 || snapshot['patientId'] != patientId) {
      throw const FormatException('Unsupported synthetic demo data');
    }
    final minutes = (snapshot['glucoseMinutes'] as List<dynamic>).cast<int>();
    if(minutes.isEmpty || minutes.length > 8 || minutes.any((m) => m < 0 || m > 1439) || minutes.toSet().length != minutes.length) {
      throw const FormatException('Invalid synthetic schedule');
    }
    final restoredTimes = minutes.map((m) => TimeOfDay(hour: m ~/ 60, minute: m % 60)).toList();
    final restoredReadings = (snapshot['glucoseReadings'] as List<dynamic>).map((value) {
      final m = Map<String, dynamic>.from(value as Map);
      return GlucoseReading(m['value'] as int, DateTime.parse(m['measuredAt'] as String),
          m['context'] as String, unit: m['unit'] as String);
    }).toList();
    final restoredOrders = (snapshot['labOrders'] as List<dynamic>).map((value) {
      final m = Map<String, dynamic>.from(value as Map);
      return LabOrder(
        id: m['id'] as String, testName: m['testName'] as String,
        dueAt: DateTime.parse(m['dueAt'] as String),
        patientId: m['patientId'] as String,
        clinicianNote: m['clinicianNote'] as String,
        result: m['result'] as String?, units: m['units'] as String?,
        laboratoryNote: m['laboratoryNote'] as String?,
        reportedAt: m['reportedAt'] == null ? null : DateTime.parse(m['reportedAt'] as String),
      );
    }).toList();
    // Apply only after the entire snapshot has been parsed successfully.
    _glucoseTimes = restoredTimes;
    readings..clear()..addAll(restoredReadings);
    orders..clear()..addAll(restoredOrders);
  }

  void _changed() {
    notifyListeners();
    final storage = _storage;
    if (storage == null) return;
    final snapshot = toSnapshot();
    // The recovery path is explicit and testable; no write reordering.
    _pendingWrite = _pendingWrite.then((_) => storage.write(snapshot));
  }

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
    _changed();
  }

  void addOrder(String testName, DateTime dueAt, String note) {
    if (testName.trim().isEmpty || testName.length > 100) throw ArgumentError('Invalid test');
    if (dueAt.isBefore(DateTime.now().subtract(const Duration(days: 1)))) throw ArgumentError('Invalid due date');
    orders.add(LabOrder(
      id: 'LAB-TEST-${DateTime.now().microsecondsSinceEpoch}',
      testName: testName.trim(), dueAt: dueAt,
      patientId: patientId, clinicianNote: note.trim(),
    ));
    _changed();
  }

  bool saveLabResult(String id, String result, String unit, String note) {
    final idx = orders.indexWhere((o) => o.id == id && !o.completed);
    if (idx < 0 || result.trim().isEmpty || result.length > 150 || note.length > 500) return false;
    orders[idx] = orders[idx].withResult(result.trim(), unit.trim(), note.trim());
    _changed();
    return true;
  }

  void addGlucoseReading(int value, DateTime measuredAt, String context) {
    // Broadly validate measurement entry only, never diagnose or recommend insulin.
    if (value < 1 || value > 1000 || measuredAt.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      throw ArgumentError('Invalid measurement');
    }
    readings.add(GlucoseReading(value, measuredAt, context));
    readings.sort((a,b) => b.measuredAt.compareTo(a.measuredAt));
    _changed();
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
