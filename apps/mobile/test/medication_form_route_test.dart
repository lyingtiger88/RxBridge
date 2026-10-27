import 'package:flutter_test/flutter_test.dart';
import 'package:rxbridge/medication_form_route.dart';

void main() {
  test('ordinary tablet defaults to oral route', () {
    expect(MedicationFormRoute.defaultRouteFor('قرص'), 'خوراکی');
    expect(MedicationFormRoute.isRouteAllowed('قرص', 'وریدی'), isFalse);
  });

  test('chewable and sublingual tablets use their specific route', () {
    expect(MedicationFormRoute.defaultRouteFor('قرص جویدنی'), 'خوراکی - جویدنی');
    expect(MedicationFormRoute.defaultRouteFor('قرص زیرزبانی'), 'زیرزبانی');
  });

  test('injection defaults to generic injection, not assumed intramuscular', () {
    expect(MedicationFormRoute.defaultRouteFor('آمپول / ویال'), 'تزریقی (نوع مشخص نشده)');
    expect(MedicationFormRoute.requiresSpecificRoute('آمپول / ویال', 'تزریقی (نوع مشخص نشده)'), isTrue);
    expect(MedicationFormRoute.isRouteAllowed('آمپول / ویال', 'وریدی'), isTrue);
  });

  test('rectal and vaginal products are distinct', () {
    expect(MedicationFormRoute.defaultRouteFor('شیاف مقعدی'), 'مقعدی');
    expect(MedicationFormRoute.defaultRouteFor('فرآورده واژینال'), 'واژینال');
    expect(MedicationFormRoute.isRouteAllowed('شیاف مقعدی', 'واژینال'), isFalse);
  });

  test('ambiguous drops cannot be saved until route is selected', () {
    expect(MedicationFormRoute.defaultRouteFor('قطره'), 'نیازمند تعیین مسیر');
    expect(MedicationFormRoute.requiresSpecificRoute('قطره', 'نیازمند تعیین مسیر'), isTrue);
    expect(MedicationFormRoute.isRouteAllowed('قطره', 'چشمی'), isTrue);
  });
}
