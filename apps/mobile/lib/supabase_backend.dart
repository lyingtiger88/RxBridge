import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_contracts.dart';

/// Supabase-specific implementation. UI/domain code must only see repositories.
class SupabaseRxBridgeBackend implements RxBridgeBackend {
  SupabaseRxBridgeBackend(this.client)
      : auth = _SupabaseAuthRepository(client),
        patients = _SupabasePatientRepository(client),
        care = _SupabaseCareRepository(client),
        prescriptions = _SupabasePrescriptionRepository(client);

  final SupabaseClient client;
  @override
  final AuthRepository auth;
  @override
  final PatientRepository patients;
  @override
  final CareRepository care;
  @override
  final PrescriptionRepository prescriptions;

  @override
  Future<void> close() async {
    // Supabase client lifecycle is owned by Supabase.initialize().
  }
}

class _SupabaseAuthRepository implements AuthRepository {
  _SupabaseAuthRepository(this.client);
  final SupabaseClient client;

  Future<SessionUser> _mapUser(User user) async {
    // Role is read from the protected profiles table, never trusted from
    // user-editable Auth metadata.
    final profile = await client.from('profiles').select('role, display_name')
        .eq('id', user.id).maybeSingle();
    if (profile == null) {
      await client.auth.signOut();
      throw StateError('Account profile is not provisioned. Contact the staging administrator.');
    }
    return SessionUser(
      id: user.id,
      role: profile['role'] as String,
      displayName: profile['display_name'] as String,
    );
  }

  @override
  Future<SessionUser> signIn({required String email, required String password}) async {
    final response = await client.auth.signInWithPassword(email: email.trim(), password: password);
    final user = response.user;
    if (user == null) throw StateError('Authentication returned no user');
    return await _mapUser(user);
  }

  @override
  Future<void> signOut() => client.auth.signOut();

  @override
  Future<SessionUser?> currentUser() async {
    final user = client.auth.currentUser;
    return user == null ? null : await _mapUser(user);
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

class _SupabasePrescriptionRepository implements PrescriptionRepository {
  const _SupabasePrescriptionRepository(this.client);
  final SupabaseClient client;

  PrescriptionDto _map(Map<String, dynamic> row) => PrescriptionDto(
    id: row['id'] as String,
    patientId: row['patient_id'] as String,
    medicine: row['medicine_name'] as String,
    form: row['pharmaceutical_form'] as String,
    dose: row['dose_label'] as String,
    frequency: row['frequency_label'] as String,
    duration: row['duration_label'] as String,
    instructions: row['instructions'] as String,
    quantity: row['quantity'] as int,
    status: row['status'] as String,
  );

  @override
  Future<List<PrescriptionDto>> listAuthorizedPrescriptions() async {
    final rows = await client.from('prescriptions').select(
      'id,patient_id,medicine_name,pharmaceutical_form,dose_label,frequency_label,duration_label,instructions,quantity,status'
    ).order('created_at', ascending: false);
    return rows.map((row) => _map(row)).toList(growable: false);
  }

  @override
  Future<PrescriptionDto> createPrescription({
    required String patientId, required String pharmacyId,
    required String medicine, required String form, required String dose,
    required String frequency, required String duration,
    required String instructions, required int quantity,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');
    if (medicine.trim().isEmpty || dose.trim().isEmpty || quantity < 1 || quantity > 1000) {
      throw ArgumentError('Invalid demonstration prescription');
    }
    final row = await client.from('prescriptions').insert({
      'patient_id': patientId,
      'doctor_id': userId,
      'pharmacy_id': pharmacyId,
      'medicine_name': medicine.trim(),
      'pharmaceutical_form': form.trim(),
      'dose_label': dose.trim(),
      'frequency_label': frequency.trim(),
      'duration_label': duration.trim(),
      'instructions': instructions.trim(),
      'quantity': quantity,
      'status': 'sent',
    }).select(
      'id,patient_id,medicine_name,pharmaceutical_form,dose_label,frequency_label,duration_label,instructions,quantity,status'
    ).single();
    return _map(row);
  }

  @override
  Future<void> updateStatus({required String prescriptionId, required String status}) async {
    if (!['dispensed','unavailable'].contains(status)) throw ArgumentError.value(status);
    final changed = await client.from('prescriptions')
      .update({'status': status})
      .eq('id', prescriptionId)
      .select('id');
    if (changed.isEmpty) throw StateError('Access denied or prescription not found');
  }
}
