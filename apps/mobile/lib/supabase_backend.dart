import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_contracts.dart';

/// Supabase-specific implementation. UI/domain code must only see repositories.
class SupabaseRxBridgeBackend implements RxBridgeBackend {
  SupabaseRxBridgeBackend(this.client)
      : auth = _SupabaseAuthRepository(client),
        patients = _SupabasePatientRepository(client),
        care = _SupabaseCareRepository(client);

  final SupabaseClient client;
  @override
  final AuthRepository auth;
  @override
  final PatientRepository patients;
  @override
  final CareRepository care;

  @override
  Future<void> close() async {
    // Supabase client lifecycle is owned by Supabase.initialize().
  }
}

class _SupabaseAuthRepository implements AuthRepository {
  _SupabaseAuthRepository(this.client);
  final SupabaseClient client;

  SessionUser _mapUser(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    return SessionUser(
      id: user.id,
      role: metadata['role'] as String? ?? 'unassigned',
      displayName: metadata['display_name'] as String? ?? user.email ?? 'کاربر',
    );
  }

  @override
  Future<SessionUser> signIn({required String email, required String password}) async {
    final response = await client.auth.signInWithPassword(email: email.trim(), password: password);
    final user = response.user;
    if (user == null) throw StateError('Authentication returned no user');
    return _mapUser(user);
  }

  @override
  Future<void> signOut() => client.auth.signOut();

  @override
  Future<SessionUser?> currentUser() async {
    final user = client.auth.currentUser;
    return user == null ? null : _mapUser(user);
  }
}

class _SupabasePatientRepository implements PatientRepository {
  _SupabasePatientRepository(this.client);
  final SupabaseClient client;

  @override
  Future<List<PatientSummary>> listAuthorizedPatients() async {
    final rows = await client.from('patients').select('id, display_code, display_name').order('display_name');
    return rows.map((row) => PatientSummary(
      id: row['id'] as String,
      displayCode: row['display_code'] as String,
      displayName: row['display_name'] as String,
    )).toList(growable: false);
  }

  @override
  Future<PatientRecord> getPatientRecord(String patientId) async {
    final row = await client.from('patients').select().eq('id', patientId).single();
    return PatientRecord(id: row['id'] as String, fields: Map<String, Object?>.from(row));
  }
}

class _SupabaseCareRepository implements CareRepository {
  _SupabaseCareRepository(this.client);
  final SupabaseClient client;

  @override
  Future<List<LabOrderDto>> listLabOrders({required String patientId}) async {
    final rows = await client.from('lab_orders').select('id, patient_id, test_code, scheduled_at, status')
        .eq('patient_id', patientId).order('scheduled_at');
    return rows.map((row) => LabOrderDto(
      id: row['id'] as String,
      patientId: row['patient_id'] as String,
      testCode: row['test_code'] as String,
      scheduledAt: DateTime.parse(row['scheduled_at'] as String).toUtc(),
      status: row['status'] as String,
    )).toList(growable: false);
  }

  @override
  Future<LabOrderDto> createLabOrder(LabOrderDto order) async {
    final row = await client.from('lab_orders').insert({
      'patient_id': order.patientId,
      'test_code': order.testCode,
      'scheduled_at': order.scheduledAt.toUtc().toIso8601String(),
      'status': order.status,
    }).select('id, patient_id, test_code, scheduled_at, status').single();
    return LabOrderDto(
      id: row['id'] as String, patientId: row['patient_id'] as String,
      testCode: row['test_code'] as String,
      scheduledAt: DateTime.parse(row['scheduled_at'] as String).toUtc(),
      status: row['status'] as String,
    );
  }

  @override
  Future<List<GlucoseReadingDto>> listGlucoseReadings({required String patientId}) async {
    final rows = await client.from('glucose_readings').select('id, patient_id, value_mg_dl, measured_at, context')
        .eq('patient_id', patientId).order('measured_at', ascending: false);
    return rows.map((row) => GlucoseReadingDto(
      id: row['id'] as String, patientId: row['patient_id'] as String,
      valueMgDl: row['value_mg_dl'] as int,
      measuredAt: DateTime.parse(row['measured_at'] as String).toUtc(),
      context: row['context'] as String,
    )).toList(growable: false);
  }

  @override
  Future<GlucoseReadingDto> addGlucoseReading(GlucoseReadingDto reading) async {
    if (reading.valueMgDl < 1 || reading.valueMgDl > 1000) {
      throw ArgumentError.value(reading.valueMgDl, 'valueMgDl', 'Outside accepted entry range');
    }
    final row = await client.from('glucose_readings').insert({
      'patient_id': reading.patientId,
      'value_mg_dl': reading.valueMgDl,
      'measured_at': reading.measuredAt.toUtc().toIso8601String(),
      'context': reading.context,
    }).select('id, patient_id, value_mg_dl, measured_at, context').single();
    return GlucoseReadingDto(
      id: row['id'] as String, patientId: row['patient_id'] as String,
      valueMgDl: row['value_mg_dl'] as int,
      measuredAt: DateTime.parse(row['measured_at'] as String).toUtc(),
      context: row['context'] as String,
    );
  }
}
