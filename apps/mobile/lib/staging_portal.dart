import 'package:flutter/material.dart';
import 'backend_contracts.dart';
import 'backend_factory.dart';
import 'care_reminders.dart';

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
            if (['doctor','patient','pharmacist'].contains(user!.role)) ...[
              _PrescriptionPanel(key: ValueKey(user!.id), backend: backend, role: user!.role),
              if (['doctor','patient'].contains(user!.role))
                _HealthyHabitsPanel(backend: backend, role: user!.role),
            ]
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

class _HealthyHabitsPanel extends StatefulWidget {
  const _HealthyHabitsPanel({required this.backend, required this.role});
  final RxBridgeBackend backend;
  final String role;
  @override
  State<_HealthyHabitsPanel> createState() => _HealthyHabitsPanelState();
}

class _HealthyHabitsPanelState extends State<_HealthyHabitsPanel> {
  List<PatientSummary> patients = [];
  List<HabitPlanDto> plans = [];
  List<HabitLogDto> logs = [];
  String? patientId;
  bool busy = true;
  String? error;
  final title = TextEditingController();
  final instruction = TextEditingController();
  final unit = TextEditingController(text: 'دقیقه');
  final min = TextEditingController(text: '20');
  final max = TextEditingController(text: '40');
  final value = TextEditingController();
  final feedback = TextEditingController();
  String habitType = 'activity';
  int frequency = 1;
  List<TimeOfDay> reminderTimes = [const TimeOfDay(hour: 9, minute: 0)];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() {busy=true; error=null;});
    try {
      final p = await widget.backend.patients.listAuthorizedPatients();
      final selected = patientId != null && p.any((x)=>x.id==patientId) ? patientId : (p.isEmpty?null:p.first.id);
      final hp = selected == null ? <HabitPlanDto>[] : await widget.backend.habits.listPlans(patientId:selected);
      final lg = selected == null ? <HabitLogDto>[] : await widget.backend.habits.listLogs(patientId:selected);
      if(mounted) setState(() {patients=p;patientId=selected;plans=hp;logs=lg;});
    } catch(e) { if(mounted) setState(()=>error='دریافت برنامه عادات ناموفق بود: $e'); }
    finally { if(mounted) setState(()=>busy=false); }
  }

  Future<void> _createPlan() async {
    final id=patientId;
    if(id==null || title.text.trim().isEmpty || instruction.text.trim().isEmpty) return;
    final lo=double.tryParse(min.text.trim());
    final hi=double.tryParse(max.text.trim());
    if(lo!=null && hi!=null && lo>hi) {setState(()=>error='حداقل نباید از حداکثر بیشتر باشد.');return;}
    setState(()=>busy=true);
    try {
      await widget.backend.habits.createPlan(
        patientId:id,title:title.text,habitType:habitType,
        instruction:instruction.text,unitLabel:unit.text,
        targetMin:lo,targetMax:hi,targetDescription:'',
        frequencyPerDay:frequency,
        reminderTimes:reminderTimes.map((t)=>'${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}').toList(),
      );
      title.clear();instruction.clear();await _load();
    } catch(e) {if(mounted)setState(()=>error='ثبت دستور پزشک انجام نشد: $e');}
  }

  Future<void> _submit(HabitPlanDto plan) async {
    final v=double.tryParse(value.text.trim());
    if(v==null || !v.isFinite) {setState(()=>error='مقدار ثبت‌شده باید عدد معتبر باشد.');return;}
    setState(()=>busy=true);
    try {
      await widget.backend.habits.submitLog(
        planId:plan.id,patientId:plan.patientId,measuredValue:v,
        completed:true,note:'ثبت خوداظهاری بیمار',occurredAt:DateTime.now(),
      );
      value.clear();await _load();
    } catch(e) {if(mounted)setState(()=>error='ثبت عملکرد انجام نشد: $e');}
  }


  Future<void> _addReminderTime() async {
    if (reminderTimes.length >= 8) return;
    final picked = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (picked == null || !mounted) return;
    if (reminderTimes.any((t)=>t.hour==picked.hour && t.minute==picked.minute)) return;
    setState(() { reminderTimes = [...reminderTimes, picked]..sort((a,b)=>(a.hour*60+a.minute).compareTo(b.hour*60+b.minute)); });
  }
  Future<void> _enableReminders(HabitPlanDto plan) async {
    if (plan.reminderTimes.isEmpty) { setState(()=>error='برای این برنامه هنوز ساعتی توسط پزشک تعیین نشده است.'); return; }
    try {
      final enabled = await CareReminders.instance.activateHabitReminders(planId:plan.id,times:plan.reminderTimes);
      if (!mounted) return;
      setState(()=>error=enabled?'یادآورها روی همین دستگاه فعال شدند.':'مجوز اعلان داده نشد یا دستگاه پشتیبانی نمی‌کند.');
    } catch(e) { if(mounted)setState(()=>error='فعال‌سازی یادآور ناموفق بود: $e'); }
  }
  Widget _metric(String label,String value) => Column(children:[
    Text(value,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800,color:Color(0xFF126D68))),
    Text(label,style:const TextStyle(fontSize:10,color:Colors.blueGrey)),
  ]);

  Widget _achievementCard() {
    final points=logs.fold<int>(0,(sum,log)=>sum+log.pointsAwarded);
    final String level;
    final String nextLabel;
    final int lower;
    final int upper;
    final IconData symbol;
    final Color tint;
    if(points>=50) {
      level='طلایی'; nextLabel='بالاترین سطح'; lower=50; upper=50;
      symbol=Icons.workspace_premium_rounded; tint=const Color(0xFFFFE8A3);
    } else if(points>=20) {
      level='نقره‌ای'; nextLabel='تا نشان طلایی'; lower=20; upper=50;
      symbol=Icons.military_tech_rounded; tint=const Color(0xFFE5E9EF);
    } else if(points>=5) {
      level='برنزی'; nextLabel='تا نشان نقره‌ای'; lower=5; upper=20;
      symbol=Icons.emoji_events_rounded; tint=const Color(0xFFF3D5BD);
    } else {
      level='در آغاز مسیر'; nextLabel='تا نشان برنزی'; lower=0; upper=5;
      symbol=Icons.flag_rounded; tint=const Color(0xFFE8F1F4);
    }
    final progress=upper==lower?1.0:((points-lower)/(upper-lower)).clamp(0.0,1.0);
    final remaining=(upper-points).clamp(0,upper);
    return Card(child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[
      Container(width:54,height:54,decoration:BoxDecoration(color:tint,shape:BoxShape.circle),
        child:Icon(symbol,size:30,color:const Color(0xFF805B24))),
      const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('نشان پایبندی به برنامه درمان',style:TextStyle(fontSize:12,color:Colors.blueGrey)),
        Text('سطح $level',style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
        Text('$points امتیاز تأییدشده • $nextLabel',style:const TextStyle(fontSize:11,color:Colors.blueGrey)),
        const SizedBox(height:7),
        ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(
          value:progress,minHeight:7,backgroundColor:const Color(0xFFF0F2F4),color:const Color(0xFF16A6A1))),
        if(remaining>0) Text('$remaining امتیاز تا سطح بعدی',style:const TextStyle(fontSize:10,color:Colors.blueGrey)),
      ])),
    ])));
  }

  Widget _progressSummary() {
    final reviewed=logs.where((x)=>x.reviewed).length;
    final earned=logs.fold<int>(0,(sum,x)=>sum+x.pointsAwarded);
    final rate=reviewed==0?0:(earned/reviewed*100).round();
    return Card(color:const Color(0xFFEAF7F5),child:Padding(padding:const EdgeInsets.all(14),child:Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Text('گزارش پیشرفت',style:TextStyle(fontWeight:FontWeight.w800,fontSize:16)),
        const SizedBox(height:10),
        Row(children:[
          Expanded(child:_metric('ثبت‌ها',logs.length.toString())),
          Expanded(child:_metric('بازبینی‌شده',reviewed.toString())),
          Expanded(child:_metric('امتیاز',earned.toString())),
          Expanded(child:_metric('پایبندی','\${rate}%')),
        ]),
        const SizedBox(height:8),
        ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(
          minHeight:9,value:reviewed==0?0:earned/reviewed,backgroundColor:Colors.white,color:Colors.teal)),
        const Text('درصد فقط از گزارش‌های بازبینی‌شده محاسبه می‌شود.',style:TextStyle(fontSize:10,color:Colors.blueGrey)),
      ],
    )));
  }
  Widget _weeklyCalendar() {
    final today=DateUtils.dateOnly(DateTime.now());
    final days=List.generate(7,(i)=>today.subtract(Duration(days:6-i)));
    final labels=['دوشنبه','سه‌شنبه','چهارشنبه','پنجشنبه','جمعه','شنبه','یکشنبه'];
    return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Text('تقویم هفتگی عادات',style:TextStyle(fontWeight:FontWeight.w800,fontSize:16)),
        const SizedBox(height:10),
        Row(children:days.map((day){
          final count=logs.where((l)=>DateUtils.isSameDay(l.occurredAt.toLocal(),day)).length;
          final index=(day.weekday+6)%7;
          return Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:2),child:Column(children:[
            Text(labels[index].substring(0,2),style:const TextStyle(fontSize:9,color:Colors.blueGrey)),
            const SizedBox(height:5),
            Container(width:31,height:34,alignment:Alignment.center,
              decoration:BoxDecoration(color:count>0?const Color(0xFFBDEAE2):const Color(0xFFF0F3F5),borderRadius:BorderRadius.circular(9)),
              child:Text('\${day.day}',style:const TextStyle(fontWeight:FontWeight.w700,fontSize:11))),
            const SizedBox(height:4),
            Icon(count>0?Icons.check_circle_rounded:Icons.circle_outlined,size:13,color:count>0?Colors.teal:Colors.black26),
          ])));
        }).toList()),
        const SizedBox(height:6),
        const Text('نشانگر سبز یعنی حداقل یک گزارش در آن روز ثبت شده است؛ تأیید پزشک جداگانه محاسبه می‌شود.',
          style:TextStyle(fontSize:10,color:Colors.blueGrey)),
      ],
    )));
  }

  Future<void> _review(HabitLogDto log) async {
    setState(()=>busy=true);
    try { await widget.backend.habits.reviewLog(logId:log.id,feedback:feedback.text);feedback.clear();await _load(); }
    catch(e) {if(mounted)setState(()=>error='ثبت بازخورد پزشک انجام نشد: $e');}
  }

  @override
  void dispose() {title.dispose();instruction.dispose();unit.dispose();min.dispose();max.dispose();value.dispose();feedback.dispose();super.dispose();}

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top:16,bottom:24),
    child: Padding(padding: const EdgeInsets.all(16),child:Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,children:[
        const Row(children:[
          Icon(Icons.eco_rounded,color:Colors.teal),
          SizedBox(width:8),
          Expanded(child:Text('عادات سالم و پیگیری درمان',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800))),
        ]),
        const Text('دستور پزشک، ثبت عملکرد بیمار و امتیازدهی پس از بازبینی پزشک'),
        if(error!=null) Padding(padding:const EdgeInsets.only(top:8),child:Text(error!,style:const TextStyle(color:Colors.red))),
        if(busy) const LinearProgressIndicator(),
        if(patients.length>1) DropdownButtonFormField<String>(
          initialValue:patientId,decoration:const InputDecoration(labelText:'پرونده بیمار'),
          items:patients.map((p)=>DropdownMenuItem(value:p.id,child:Text(p.displayName))).toList(),
          onChanged:(v){patientId=v;_load();},
        ),
        if(widget.role=='doctor') ...[
          const SizedBox(height:12),
          const Text('تعریف دستور عادت سالم',style:TextStyle(fontWeight:FontWeight.bold)),
          TextField(controller:title,decoration:const InputDecoration(labelText:'عنوان عادت؛ مثال پیاده‌روی')),
          const SizedBox(height:8),
          TextField(controller:instruction,maxLines:2,decoration:const InputDecoration(labelText:'دستور دقیق پزشک و شرایط اجرا')),
          const SizedBox(height:8),
          DropdownButtonFormField<String>(initialValue:habitType,decoration:const InputDecoration(labelText:'دسته'),
            items:const [
              DropdownMenuItem(value:'activity',child:Text('فعالیت بدنی')),
              DropdownMenuItem(value:'hydration',child:Text('آب و مایعات')),
              DropdownMenuItem(value:'nutrition',child:Text('تغذیه')),
              DropdownMenuItem(value:'sleep',child:Text('خواب')),
              DropdownMenuItem(value:'measurement',child:Text('اندازه‌گیری و پایش')),
              DropdownMenuItem(value:'other',child:Text('سایر')),
            ],onChanged:(v){if(v!=null)setState(()=>habitType=v);}),
          Row(children:[
            Expanded(child:TextField(controller:min,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'حداقل مقدار'))),
            const SizedBox(width:8),
            Expanded(child:TextField(controller:max,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'حداکثر مقدار'))),
            const SizedBox(width:8),
            Expanded(child:TextField(controller:unit,decoration:const InputDecoration(labelText:'واحد'))),
          ]),
          DropdownButtonFormField<int>(initialValue:frequency,decoration:const InputDecoration(labelText:'دفعات در روز'),
            items:List.generate(24,(i)=>DropdownMenuItem(value:i+1,child:Text('${i+1} بار'))),
            onChanged:(v){if(v!=null)setState(()=>frequency=v);}),
          const SizedBox(height:8),
          const Text('ساعت‌های یادآوری روزانه',style:TextStyle(fontWeight:FontWeight.w600)),
          Wrap(spacing:6,runSpacing:4,children:[
            for(final time in reminderTimes) InputChip(label:Text(time.format(context)),onDeleted:()=>setState(()=>reminderTimes.remove(time))),
            ActionChip(avatar:const Icon(Icons.add_alarm_rounded,size:18),label:const Text('افزودن ساعت'),onPressed:_addReminderTime),
          ]),
          const SizedBox(height:8),
          FilledButton(onPressed:busy?null:_createPlan,child:const Text('ثبت دستور برای بیمار')),
        ],
        const Divider(height:28),
        if(plans.isNotEmpty) _achievementCard(),
        if(plans.isNotEmpty) _progressSummary(),
        if(plans.isNotEmpty) _weeklyCalendar(),
        for(final plan in plans) ...[
          ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.track_changes_rounded,color:Colors.teal),
            title:Text(plan.title,style:const TextStyle(fontWeight:FontWeight.bold)),
            subtitle:Text('${plan.instruction}\nمحدوده مورد تأیید: ${plan.targetMin??'—'} تا ${plan.targetMax??'—'} ${plan.unitLabel} • ${plan.frequencyPerDay} نوبت در روز')),
          if(widget.role=='patient' && plan.reminderTimes.isNotEmpty) Align(
            alignment:Alignment.centerRight,
            child:TextButton.icon(onPressed:()=>_enableReminders(plan),icon:const Icon(Icons.notifications_active_outlined),label:Text('فعال‌سازی یادآورها: ${plan.reminderTimes.join('، ')}')),
          ),
          if(widget.role=='patient') Row(children:[
            Expanded(child:TextField(controller:value,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'مقدار انجام‌شده (${plan.unitLabel})'))),
            const SizedBox(width:8),
            FilledButton(onPressed:busy?null:()=>_submit(plan),child:const Text('ثبت عملکرد')),
          ]),
          for(final log in logs.where((x)=>x.planId==plan.id))
            Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(10),
              decoration:BoxDecoration(color:const Color(0xFFF3F7FA),borderRadius:BorderRadius.circular(12)),
              child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                Text('مقدار: ${log.measuredValue??'—'} • وضعیت: ${log.reviewed?(log.pointsAwarded>0?'تأیید شد؛ +۱ امتیاز': 'نیازمند اصلاح'):'در انتظار بازبینی پزشک'}'),
                if(log.doctorFeedback.isNotEmpty) Text('راهنمایی پزشک: ${log.doctorFeedback}'),
                if(widget.role=='doctor' && !log.reviewed) ...[
                  TextField(controller:feedback,decoration:const InputDecoration(labelText:'بازخورد یا راهنمایی پزشک')),
                  Align(alignment:Alignment.centerLeft,child:FilledButton.tonal(onPressed:busy?null:()=>_review(log),child:const Text('بازبینی و ثبت نتیجه'))),
                ],
              ]),
            ),
        ],
        if(plans.isEmpty && !busy) const Text('هنوز دستور عادت سالمی برای این پرونده ثبت نشده است.'),
        OutlinedButton.icon(onPressed:busy?null:_load,icon:const Icon(Icons.refresh),label:const Text('بروزرسانی')),
        const Text('امتیاز فقط پس از بازبینی پزشک ثبت می‌شود. ثبت بیمار خوداظهاری است و به‌تنهایی اثبات انجام فعالیت نیست. این سیستم جایگزین توصیه یا ارزیابی بالینی نیست.',
          style:TextStyle(fontSize:11,color:Colors.blueGrey)),
      ],
    )),
  );
}
