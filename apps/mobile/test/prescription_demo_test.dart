import 'package:flutter_test/flutter_test.dart';
import 'package:rxbridge/prescription_demo_store.dart';

void main() {
  test('doctor creates a demo prescription and pharmacy updates its status', () {
    final store = DemoPrescriptionStore.instance;
    final before = store.prescriptions.length;
    store.add(
      medicine: 'TEST-DRUG-ALPHA',
      form: 'قرص',
      dose: 'مقدار ساختگی',
      frequency: 'هر ۱۲ ساعت',
      duration: '۲ روز',
      quantity: 4,
      instructions: 'اطلاعات صرفاً نمایشی',
    );
    expect(store.prescriptions.length, before + 1);
    final rx = store.prescriptions.first;
    expect(rx.medicine, 'TEST-DRUG-ALPHA');
    expect(rx.available, isTrue);
    store.setAvailability(rx.id, false);
    expect(store.prescriptions.first.available, isFalse);
    expect(store.prescriptions.first.status, DemoPrescriptionStatus.partiallyDispensed);
    store.setAvailability(rx.id, true);
    expect(store.prescriptions.first.status, DemoPrescriptionStatus.dispensed);
    store.reset();
    expect(store.prescriptions.length, 2);
  });

  test('invalid demo prescription is not stored', () {
    final store = DemoPrescriptionStore.instance;
    final count = store.prescriptions.length;
    expect(() => store.add(
      medicine: '', form: 'قرص', dose: '۱', frequency: 'روزانه',
      duration: '۱ روز', quantity: 1, instructions: '',
    ), throwsArgumentError);
    expect(store.prescriptions.length, count);
  });
}
