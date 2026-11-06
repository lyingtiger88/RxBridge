import 'package:flutter/foundation.dart';

enum DemoPrescriptionStatus { sent, partiallyDispensed, dispensed }

class DemoPrescription {
  final String id;
  final String patientName;
  final String doctorName;
  final String medicine;
  final String form;
  final String dose;
  final String frequency;
  final String duration;
  final String instructions;
  final int quantity;
  final bool available;
  final DemoPrescriptionStatus status;
  final DateTime createdAt;

  const DemoPrescription({
    required this.id, required this.patientName, required this.doctorName,
    required this.medicine, required this.form, required this.dose,
    required this.frequency, required this.duration, required this.instructions,
    required this.quantity, required this.available, required this.status,
    required this.createdAt,
  });

  DemoPrescription copyWith({bool? available, DemoPrescriptionStatus? status}) => DemoPrescription(
    id:id, patientName:patientName, doctorName:doctorName, medicine:medicine,
    form:form,dose:dose,frequency:frequency,duration:duration,instructions:instructions,
    quantity:quantity,available:available??this.available,status:status??this.status,createdAt:createdAt,
  );
}

/// Shared, resettable, synthetic prescription workflow for presentation only.
class DemoPrescriptionStore extends ChangeNotifier {
  DemoPrescriptionStore._();
  static final instance=DemoPrescriptionStore._();

  final List<DemoPrescription> prescriptions=[
    DemoPrescription(id:'RX-DEMO-024',patientName:'بیمار نمونه ۰۰۱',doctorName:'پزشک نمونه',
      medicine:'استامینوفن (نمونه)',form:'قرص',dose:'۵۰۰ میلی‌گرم',frequency:'هر ۸ ساعت',
      duration:'۳ روز',instructions:'پس از غذا • فقط سناریوی نمایشی',quantity:9,available:true,
      status:DemoPrescriptionStatus.sent,createdAt:DateTime.now()),
    DemoPrescription(id:'RX-DEMO-023',patientName:'بیمار نمونه ۰۰۲',doctorName:'پزشک نمونه',
      medicine:'فرآورده نمونه B',form:'شربت',dose:'۵ میلی‌لیتر',frequency:'هر ۱۲ ساعت',
      duration:'۵ روز',instructions:'اقلام و مقادیر ساختگی',quantity:1,available:false,
      status:DemoPrescriptionStatus.partiallyDispensed,createdAt:DateTime.now().subtract(const Duration(hours:3))),
  ];

  void add({required String medicine,required String form,required String dose,
    required String frequency,required String duration,required int quantity,required String instructions}) {
    if(medicine.trim().isEmpty||dose.trim().isEmpty||duration.trim().isEmpty||quantity<1||quantity>1000) {
      throw ArgumentError('اطلاعات نسخه کامل نیست.');
    }
    prescriptions.insert(0,DemoPrescription(
      id:'RX-DEMO-${DateTime.now().millisecondsSinceEpoch}',
      patientName:'بیمار نمونه ۰۰۱',doctorName:'پزشک نمونه',medicine:medicine.trim(),
      form:form,dose:dose.trim(),frequency:frequency,duration:duration.trim(),
      instructions:instructions.trim(),quantity:quantity,available:true,
      status:DemoPrescriptionStatus.sent,createdAt:DateTime.now()));
    notifyListeners();
  }

  void setAvailability(String id,bool available) {
    final i=prescriptions.indexWhere((p)=>p.id==id);
    if(i<0)return;
    prescriptions[i]=prescriptions[i].copyWith(available:available,
      status:available?DemoPrescriptionStatus.dispensed:DemoPrescriptionStatus.partiallyDispensed);
    notifyListeners();
  }

  void reset() {
    prescriptions.removeWhere((p)=>p.id.startsWith('RX-DEMO-') && p.id!='RX-DEMO-024' && p.id!='RX-DEMO-023');
    notifyListeners();
  }
}
