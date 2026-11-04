import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// Replace this interface with a server-backed implementation at release time.
/// Contains TEST fixtures only, never real patient data.
abstract class CareSnapshotStorage {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> snapshot);
  Future<void> close();
}

/// Isolated SQLite adapter for the disposable mobile prototype.
/// No UI code or domain model imports sqflite.
class SqliteCareSnapshotStorage implements CareSnapshotStorage {
  SqliteCareSnapshotStorage._(this._db);

  final Database _db;
  static const String filename = 'rxbridge_demo_only.db';
  static const String snapshotId = 'care_demo_v1';

  static Future<SqliteCareSnapshotStorage> open() async {
    final directory = await getDatabasesPath();
    final db = await openDatabase(
      path.join(directory, filename),
      version: 1,
      onCreate: (database, version) async {
        await database.execute(
          'CREATE TABLE demo_state (state_key TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL)',
        );
      },
    );
    return SqliteCareSnapshotStorage._(db);
  }

  @override
  Future<Map<String, dynamic>?> read() async {
    final rows = await _db.query('demo_state',
        columns: ['payload'], where: 'state_key = ?', whereArgs: [snapshotId], limit: 1);
    if (rows.isEmpty) return null;
    final decoded = jsonDecode(rows.single['payload']! as String);
    if (decoded is! Map<String, dynamic>) throw const FormatException('Invalid demo snapshot');
    return decoded;
  }

  @override
  Future<void> write(Map<String, dynamic> snapshot) async {
    await _db.insert(
      'demo_state',
      {'state_key': snapshotId, 'payload': jsonEncode(snapshot)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> close() => _db.close();
}

/// In-memory implementation for deterministic tests and future API migration.
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
