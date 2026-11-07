import 'package:flutter/material.dart';
import 'backend_contracts.dart';
import 'backend_factory.dart';

/// Authenticated staging entry point. Never exposes the local demo workspaces.
class StagingPortal extends StatefulWidget {
  const StagingPortal({super.key});
  @override
  State<StagingPortal> createState() => _StagingPortalState();
}

class _StagingPortalState extends State<StagingPortal> {
  final backend = RxBridgeBackendFactory.instance!;
  final email = TextEditingController();
  final password = TextEditingController();
  SessionUser? user;
  bool busy = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final current = await backend.auth.currentUser();
      if (mounted) setState(() => user = current);
    } catch (e) {
      if (mounted) setState(() => error = 'خطا در بررسی حساب: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _signIn() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      final current = await backend.auth.signIn(email: email.text, password: password.text);
      if (mounted) setState(() => user = current);
    } catch (e) {
      if (mounted) setState(() => error = 'ورود ناموفق: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => busy = true);
    try {
      await backend.auth.signOut();
      if (mounted) setState(() => user = null);
    } catch (e) {
      if (mounted) setState(() => error = 'خروج ناموفق: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('پل سلامت • محیط آزمایشی متصل'),
      actions: [if (user != null) IconButton(
        tooltip: 'خروج از حساب',
        onPressed: busy ? null : _signOut,
        icon: const Icon(Icons.logout_rounded),
      )],
    ),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: busy && user == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(18), children: [
          const Card(child: Padding(
            padding: EdgeInsets.all(14),
            child: Text('حالت Staging • صرفاً داده‌های ساختگی. مجوزها بر اساس حساب تأییدشده و سیاست‌های سرور اعمال می‌شوند.'),
          )),
          if (error != null) Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
          if (user == null) ...[
            const SizedBox(height: 24),
            const Text('ورود به حساب آزمایشی', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(controller: email, keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'ایمیل')),
            const SizedBox(height: 12),
            TextField(controller: password, obscureText: true,
              decoration: const InputDecoration(labelText: 'رمز عبور')),
            const SizedBox(height: 12),
            FilledButton(onPressed: busy ? null : _signIn, child: const Text('ورود امن')),
          ] else ...[
            Text('خوش آمدید، ${user!.displayName}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
            Text('نقش ثبت‌شده در سرور: ${user!.role}'),
            const SizedBox(height: 10),
            if (['doctor','patient','pharmacist'].contains(user!.role))
              _PrescriptionPanel(key: ValueKey(user!.id), backend: backend, role: user!.role)
            else
              const Card(child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('این نقش وارد سامانه شده است. گردش نسخه در Staging فعلاً برای پزشک، بیمار و داروساز فعال است.'),
              )),
          ],
        ]),
    ))),
  );
}

class _PrescriptionPanel extends StatefulWidget {
  const _PrescriptionPanel({super.key, required this.backend, required this.role});
  final RxBridgeBackend backend;
  final String role;
  @override
  State<_PrescriptionPanel> createState() => _PrescriptionPanelState();
}

class _PrescriptionPanelState extends State<_PrescriptionPanel> {
  List<PrescriptionDto> prescriptions = const [];
  List<PatientSummary> patients = const [];
  String? selectedPatient;
  final pharmacyId = TextEditingController();
  final medicine = TextEditingController();
  final dose = TextEditingController();
  final duration = TextEditingController(text: '۳ روز');
  final quantity = TextEditingController(text: '۶');
  bool busy = true;
  String? error;
  String form = 'قرص';
  String frequency = 'هر ۱۲ ساعت';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {busy = true; error = null;});
    try {
      final entries = await widget.backend.prescriptions.listAuthorizedPrescriptions();
      final people = widget.role == 'doctor'
        ? await widget.backend.patients.listAuthorizedPatients() : <PatientSummary>[];
      if (mounted) setState(() {
        prescriptions = entries;
        patients = people;
        if (people.isEmpty) selectedPatient = null;
        else if (!people.any((p) => p.id == selectedPatient)) selectedPatient = people.first.id;
      });
    } catch (e) {
      if (mounted) setState(() => error = 'دریافت اطلاعات ناموفق: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _submit() async {
    final patientId = selectedPatient;
    final count = int.tryParse(quantity.text.trim());
    if (patientId == null || pharmacyId.text.trim().isEmpty || count == null) {
      setState(() => error = 'بیمار، شناسه داروخانه و تعداد معتبر لازم است.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      await widget.backend.prescriptions.createPrescription(
        patientId: patientId, pharmacyId: pharmacyId.text.trim(),
        medicine: medicine.text, form: form, dose: dose.text,
        frequency: frequency, duration: duration.text,
        instructions: 'سناریوی آزمایشی', quantity: count,
      );
      medicine.clear();
      await _refresh();
    } catch (e) {
      if (mounted) setState(() {error = 'ثبت نسخه ناموفق: $e'; busy = false;});
    }
  }

  Future<void> _setStatus(PrescriptionDto prescription, String status) async {
    setState(() {busy = true; error = null;});
    try {
      await widget.backend.prescriptions.updateStatus(
        prescriptionId: prescription.id, status: status,
      );
      await _refresh();
    } catch (e) {
      if (mounted) setState(() {error = 'ثبت وضعیت ناموفق: $e'; busy = false;});
    }
  }

  @override
  void dispose() {
    pharmacyId.dispose(); medicine.dispose(); dose.dispose();
    duration.dispose(); quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 12),
      Row(children: [
        const Expanded(child: Text('نسخه‌های مجاز', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
        IconButton(onPressed: busy ? null : _refresh,
          tooltip: 'بروزرسانی از سرور', icon: const Icon(Icons.refresh)),
      ]),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
      if (busy) const LinearProgressIndicator(),
      if (widget.role == 'doctor') ...[
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('ارسال نسخه آزمایشی', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (patients.isEmpty)
              const Text('بیمار مجاز یافت نشد. ابتدا داده‌های ساختگی و ارتباط درمانی را در Supabase ثبت کنید.'),
            if (patients.isNotEmpty) DropdownButtonFormField<String>(
              initialValue: selectedPatient,
              decoration: const InputDecoration(labelText: 'بیمار مجاز'),
              items: patients.map((p) => DropdownMenuItem(
                value: p.id, child: Text(p.displayName),
              )).toList(),
              onChanged: (v) => setState(() => selectedPatient = v),
            ),
            const SizedBox(height: 10),
            TextField(controller: pharmacyId,
              decoration: const InputDecoration(labelText: 'UUID داروساز آزمایشی')),
            const SizedBox(height: 10),
            TextField(controller: medicine,
              decoration: const InputDecoration(labelText: 'نام داروی ساختگی')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: form,
              decoration: const InputDecoration(labelText: 'شکل دارویی'),
              items: ['قرص','کپسول','شربت','قطره','سایر'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
              onChanged: (x) {if(x!=null)setState(()=>form=x);},
            ),
            const SizedBox(height: 10),
            TextField(controller: dose,
              decoration: const InputDecoration(labelText: 'مقدار نمایشی')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: frequency,
              decoration: const InputDecoration(labelText: 'فاصله نمایشی'),
              items: ['هر ۸ ساعت','هر ۱۲ ساعت','روزانه'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
              onChanged: (x) {if(x!=null)setState(()=>frequency=x);},
            ),
            const SizedBox(height: 10),
            TextField(controller: duration,
              decoration: const InputDecoration(labelText: 'مدت نمونه')),
            const SizedBox(height: 10),
            TextField(controller: quantity, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'تعداد')),
            const SizedBox(height: 10),
            FilledButton(onPressed: busy ? null : _submit,
              child: const Text('ثبت در Supabase')),
          ],
        ))),
      ],
      const SizedBox(height: 10),
      if (!busy && prescriptions.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(16),
          child: Text('نسخه‌ای با دسترسی مجاز برای این حساب وجود ندارد.'))),
      for (final p in prescriptions)
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(p.medicine, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('${p.form} • ${p.dose} • ${p.frequency} • ${p.duration}'),
            Text('تعداد: ${p.quantity} • وضعیت: ${p.status}'),
            if (widget.role == 'pharmacist' && p.status == 'sent')
              Wrap(spacing: 8, children: [
                OutlinedButton(onPressed: busy ? null : () => _setStatus(p,'dispensed'),
                  child: const Text('تحویل شد')),
                OutlinedButton(onPressed: busy ? null : () => _setStatus(p,'unavailable'),
                  child: const Text('ناموجود')),
              ]),
          ],
        ))),
    ],
  );
}
