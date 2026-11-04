import 'dart:convert';

/// Only synthetic test records are allowed.
/// A future server adapter will implement this interface without any SQLite dependency.
abstract class CareSnapshotStorage {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> snapshot);
  Future<void> close();
}

/// Pure Dart test storage with no disk or network dependency.
class MemoryCareSnapshotStorage implements CareSnapshotStorage {
  Map<String, dynamic>? snapshot;

  @override
  Future<Map<String, dynamic>?> read() async =>
      snapshot == null ? null : jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;

  @override
  Future<void> write(Map<String, dynamic> data) async {
    snapshot = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  }

  @override
  Future<void> close() async {}
}
