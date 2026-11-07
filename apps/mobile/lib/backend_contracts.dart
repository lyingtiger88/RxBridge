/// Stable application-facing contracts shared by every deployment.
/// Implementations may use Supabase now or an Iranian REST API later.
/// UI widgets must depend on these contracts, never on a vendor SDK.
abstract interface class AuthRepository {
  Future<SessionUser> signIn({required String email, required String password});
  Future<void> signOut();
  Future<SessionUser?> currentUser();
}

abstract interface class PatientRepository {
  Future<List<PatientSummary>> listAuthorizedPatients();
  Future<PatientRecord> getPatientRecord(String patientId);
}

abstract interface class CareRepository {
  Future<List<LabOrderDto>> listLabOrders({required String patientId});
  Future<LabOrderDto> createLabOrder(LabOrderDto order);
  Future<List<GlucoseReadingDto>> listGlucoseReadings({required String patientId});
  Future<GlucoseReadingDto> addGlucoseReading(GlucoseReadingDto reading);
}

abstract interface class PrescriptionRepository {
  Future<List<PrescriptionDto>> listAuthorizedPrescriptions();
  Future<PrescriptionDto> createPrescription({
    required String patientId, required String pharmacyId,
    required String medicine, required String form, required String dose,
    required String frequency, required String duration,
    required String instructions, required int quantity,
  });
  Future<void> updateStatus({required String prescriptionId, required String status});
}

class PrescriptionDto {
  final String id;
  final String patientId;
  final String medicine;
  final String form;
  final String dose;
  final String frequency;
  final String duration;
  final String instructions;
  final int quantity;
  final String status;
  const PrescriptionDto({
    required this.id, required this.patientId, required this.medicine,
    required this.form, required this.dose, required this.frequency,
    required this.duration, required this.instructions,
    required this.quantity, required this.status,
  });
}

abstract interface class RxBridgeBackend {
  AuthRepository get auth;
  PatientRepository get patients;
  CareRepository get care;
  PrescriptionRepository get prescriptions;
  Future<void> close();
}

class SessionUser {
  final String id;
  final String role;
  final String displayName;
  const SessionUser({required this.id, required this.role, required this.displayName});
}

class PatientSummary {
  final String id;
  final String displayCode;
  final String displayName;
  const PatientSummary({required this.id, required this.displayCode, required this.displayName});
}

class PatientRecord {
  final String id;
  final Map<String, Object?> fields;
  const PatientRecord({required this.id, required this.fields});
}

class LabOrderDto {
  final String? id;
  final String patientId;
  final String testCode;
  final DateTime scheduledAt;
  final String status;
  const LabOrderDto({this.id, required this.patientId, required this.testCode, required this.scheduledAt, required this.status});
}

class GlucoseReadingDto {
  final String? id;
  final String patientId;
  final int valueMgDl;
  final DateTime measuredAt;
  final String context;
  const GlucoseReadingDto({this.id, required this.patientId, required this.valueMgDl, required this.measuredAt, required this.context});
}
