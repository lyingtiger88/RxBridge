import 'package:flutter/material.dart';
import 'care_demo_store.dart';
import 'care_reminders.dart';

const _navy = Color(0xFF102A43);
const _teal = Color(0xFF16A6A1);
const _muted = Color(0xFF6C8293);
const _paper = Color(0xFFF3F7FA);

class CareTrackingPage extends StatefulWidget {
  final bool clinician;
  const CareTrackingPage({super.key, required this.clinician});
  @override
  State<CareTrackingPage> createState() => _CareTrackingPageState();
}

class _CareTrackingPageState extends State<CareTrackingPage> {
  final store = CareDemoStore.instance;
  final glucoseInput = TextEditingController();
  final testInput = TextEditingController();
  final noteInput = TextEditingController();
  DateTime dueAt = DateTime.now().add(const Duration(days: 7));
  String glucoseContext = 'پیش از غذا';
  int frequency = 2;
  int startHour = 8;
  bool scheduling = false;

  @override
  void initState() {
    super.initState();
    store.addListener(refresh);
  }

  void refresh() { if (mounted) setState(() {}); }
  void notice(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  @override
  void dispose() {
    store.removeListener(refresh);
    glucoseInput.dispose(); testInput.dispose(); noteInput.dispose();
    super.dispose();
  }

  Widget card(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 12), ...children,
      ],
    )),
  );

  Widget banner(String message) => Container(
    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0xFFFFF4E3)),
    child: Row(children: [const Icon(Icons.info_outline_rounded, color: Color(0xFF926516)), const SizedBox(width: 8),
      Expanded(child: Text(message, style: const TextStyle(fontSize: 11, color: Color(0xFF926516))))]),
  );

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: _paper, child: ListView(
      padding: const EdgeInsets.all(16), children: [
      Text(widget.clinician ? 'برنامه آزمایش و پایش' : 'آزمایش‌ها و قند خون من',
        style: const TextStyle(fontSize: 22, color: _navy, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      Text(widget.clinician ? 'پزشک • بیمار نمونه TEST-PATIENT-001' : 'بیمار نمونه • گزارش‌ها و ثبت شخصی',
        style: const TextStyle(fontSize: 11, color: _muted)),
      const SizedBox(height: 16),
      banner('این نسخه فقط شبیه‌سازی است؛ هیچ تشخیص، تنظیم دارو، تغییر دوز یا ارسال اطلاعات به پزشک واقعی انجام نمی‌شود.'),
      if(widget.clinician) ...[clinicianPlan(), orderForm()] else ...[glucoseEntry(), reminderCard()],
      resultsCard(),
      glucoseTimeline(),
    ]));
  }

  Widget clinicianPlan() => card('تعیین نوبت‌های قند خون خانگی', [
    const Text('تعداد و زمان اندازه‌گیری را پزشک تعیین می‌کند. پیش‌فرض‌ها فقط ساعت‌های نمونه‌اند و تجویز پزشکی محسوب نمی‌شوند.', style: TextStyle(fontSize: 12, color: _muted)),
    const SizedBox(height: 10),
    DropdownButtonFormField<int>(
      initialValue: frequency,
      decoration: const InputDecoration(labelText: 'تعداد نوبت در روز'),
      items: [1,2,3,4,6,8].map((n) => DropdownMenuItem(value:n, child:Text('$n نوبت'))).toList(),
      onChanged: (v) { if(v != null) setState(() => frequency=v); },
    ),
    const SizedBox(height: 10),
    DropdownButtonFormField<int>(
      initialValue: startHour,
      decoration: const InputDecoration(labelText: 'ساعت شروع'),
      items: List.generate(24, (h) => DropdownMenuItem(value:h,child: Text('${h.toString().padLeft(2,'0')}:00'))),
      onChanged: (v) { if(v != null) setState(() => startHour=v); },
    ),
    const SizedBox(height: 8),
    Wrap(spacing: 6, children: [
      for(final time in fixedIntervalTimes(frequency,startHour:startHour))
        Chip(label: Text(clockLabel(time)), avatar: const Icon(Icons.schedule_rounded, size: 16)),
    ]),
    const SizedBox(height: 6),
    FilledButton.icon(onPressed: () {
      store.setGlucosePlan(fixedIntervalTimes(frequency,startHour:startHour));
      notice('برنامه نمونه ثبت شد؛ بیمار می‌تواند آن را ببیند و یادآورها را فعال کند.');
    }, icon: const Icon(Icons.event_available_rounded),label: const Text('ثبت برنامه پایش بیمار')),
  ]);

  Widget orderForm() => card('درخواست آزمایش جدید', [
    TextField(controller:testInput, decoration: const InputDecoration(labelText:'نام آزمایش (نمونه)',hintText:'مثلاً CBC یا HbA1c')),
    const SizedBox(height: 10),
    TextField(controller:noteInput, maxLines:2, decoration: const InputDecoration(labelText:'توضیح پزشک (اختیاری)')),
    const SizedBox(height: 8),
    OutlinedButton.icon(onPressed: () async {
      final selected = await showDatePicker(context:context, initialDate: dueAt, firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days: 365)));
      if(selected != null) setState(() => dueAt=selected);
    }, icon:const Icon(Icons.calendar_today_rounded),
      label:Text('موعد آزمایش: ${dueAt.year}/${dueAt.month}/${dueAt.day}')),
    const SizedBox(height: 8),
    FilledButton.icon(onPressed: () {
      try {
        store.addOrder(testInput.text,dueAt,noteInput.text);
        testInput.clear();noteInput.clear();
        notice('درخواست آزمایش برای بیمار نمونه ثبت شد.');
      } catch (_) {notice('نام یا تاریخ آزمایش معتبر نیست.');}
    },icon:const Icon(Icons.add_task_rounded),label:const Text('افزودن به برنامه آزمایش')),
  ]);

  Widget glucoseEntry() => card('ثبت قند خون خانگی', [
    const Text('عدد را عیناً مطابق نمایش دستگاه ثبت کنید؛ سامانه این مقدار را تفسیر پزشکی نمی‌کند.', style: TextStyle(color:_muted,fontSize:12)),
    const SizedBox(height:12),
    TextField(controller:glucoseInput, keyboardType:TextInputType.number, decoration:const InputDecoration(labelText:'میزان قند خون (mg/dL)')),
    const SizedBox(height:10),
    DropdownButtonFormField<String>(initialValue:glucoseContext,decoration:const InputDecoration(labelText:'زمان نسبت به وعده غذایی'),
      items: const ['پیش از غذا','پس از غذا','ناشتا','قبل از خواب','سایر'].map((v) => DropdownMenuItem(value:v,child:Text(v))).toList(),
      onChanged:(v) {if(v != null)setState(() => glucoseContext=v);}),
    const SizedBox(height:10),
    FilledButton.icon(onPressed: () {
      final value=int.tryParse(glucoseInput.text.trim());
      if(value==null){notice('مقدار عددی معتبر وارد کنید.');return;}
      try {
        store.addGlucoseReading(value,DateTime.now(),glucoseContext);
        glucoseInput.clear();
        notice('ثبت در پرونده نمونه انجام شد؛ در پنل پزشک نمونه نیز قابل مشاهده است.');
      } catch (_){notice('عدد یا زمان نامعتبر است؛ مطابق دستگاه مجدداً بررسی کنید.');}
    },icon:const Icon(Icons.save_outlined),label:const Text('ثبت اندازه‌گیری در پرونده')),
    const SizedBox(height:8),
    const Text('اگر علائم هشداردهنده یا عدد غیرعادی دارید، فقط به اپ متکی نباشید و از برنامه درمانی پزشکتان یا خدمات فوری استفاده کنید.',style:TextStyle(fontSize:11,color:_muted)),
  ]);

  Widget reminderCard() => card('زمان‌بندی و یادآوری آزمایش', [
    const Text('ساعت‌های تعیین‌شده توسط پزشک نمونه:',style:TextStyle(fontSize:12,color:_muted)),
    const SizedBox(height:8),
    Wrap(spacing:7,runSpacing:5,children: [
      for(final time in store.glucoseTimes) Chip(label:Text(clockLabel(time)),avatar:const Icon(Icons.alarm_rounded,size:16)),
    ]),
    const SizedBox(height:8),
    FilledButton.tonalIcon(onPressed:scheduling?null:() async {
      setState(() => scheduling=true);
      try {
        final success=await CareReminders.instance.activateDailyGlucoseReminders(store.glucoseTimes);
        if(!mounted)return;
        notice(success?'یادآورهای محلی درخواست و تنظیم شدند؛ تحویل آن‌ها به مجوز و تنظیمات گوشی بستگی دارد.':'مجوز اعلان یا امکان زمان‌بندی در این دستگاه فعال نیست.');
      } catch (_) {
        if(mounted)notice('تنظیم یادآورها ناموفق بود؛ مجوز اعلان و تنظیمات گوشی را بررسی کنید.');
      } finally {if(mounted)setState(() => scheduling=false);}
    },icon:const Icon(Icons.notifications_active_outlined),label:const Text('فعال‌سازی اعلان‌های روزانه')),
    const SizedBox(height:8),
    OutlinedButton.icon(onPressed:() async {
      await CareReminders.instance.cancelGlucoseReminders();
      if(mounted)notice('یادآورهای محلی حذف شدند.');
    },icon:const Icon(Icons.notifications_off_outlined),label:const Text('لغو یادآورها')),
    const SizedBox(height:6),
    const Text('یادآورها محلی و وابسته به مجوز اعلان و محدودیت باتری سیستم‌عامل‌اند؛ تضمین تحویل دقیق یا جایگزین برنامه درمانی نیستند.',style:TextStyle(fontSize:11,color:_muted)),
  ]);

  Widget resultsCard() => card('آزمایش‌های برنامه‌ریزی‌شده و گزارش‌ها', [
    for(final order in store.orders) ...[
      ListTile(contentPadding:EdgeInsets.zero,
        leading:Icon(order.completed?Icons.fact_check_outlined:Icons.pending_actions_rounded,color:order.completed?_teal:_navy),
        title:Text(order.testName,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
        subtitle:Text(order.completed?'گزارش: ${order.result} ${order.units??''}\nیادداشت آزمایشگاه: ${order.laboratoryNote??'—'}':'موعد: ${order.dueAt.year}/${order.dueAt.month}/${order.dueAt.day}\n${order.clinicianNote}',style:const TextStyle(fontSize:11)),
        isThreeLine: true,
      ),
      const Divider(height:5),
    ],
    const Text('گزارش آزمایشگاه تا زمان انتشار فقط وضعیت «در انتظار» دارد و از داده واقعی استفاده نمی‌شود.',style:TextStyle(fontSize:11,color:_muted)),
  ]);

  Widget glucoseTimeline() => card('سوابق ثبت‌شده قند خون', [
    if(store.readings.isEmpty)const Text('هنوز اندازه‌گیری ثبت نشده است.',style:TextStyle(color:_muted,fontSize:12)),
    for(final reading in store.readings) ListTile(
      contentPadding:EdgeInsets.zero,leading:const Icon(Icons.bloodtype_outlined,color:_teal),
      title:Text('${reading.value} ${reading.unit}',style:const TextStyle(fontWeight:FontWeight.bold)),
      subtitle:Text('${reading.context} • ${reading.measuredAt.year}/${reading.measuredAt.month}/${reading.measuredAt.day} ${reading.measuredAt.hour.toString().padLeft(2,'0')}:${reading.measuredAt.minute.toString().padLeft(2,'0')}',
        style:const TextStyle(fontSize:11,color:_muted)),
    ),
    if(widget.clinician)const Text('این داده‌ها در برنامه نمایشی مشترک‌اند. در محصول واقعی، نمایش پزشک به احراز هویت، رابطه درمانی و مجوز سروری نیاز دارد.',style:TextStyle(fontSize:11,color:_muted)),
  ]);
}

class LaboratoryPage extends StatefulWidget {
  const LaboratoryPage({super.key});
  @override
  State<LaboratoryPage> createState() => _LaboratoryPageState();
}

class _LaboratoryPageState extends State<LaboratoryPage> {
  final store=CareDemoStore.instance;
  @override
  void initState(){super.initState();store.addListener(refresh);}
  void refresh(){if(mounted)setState((){});}
  @override
  void dispose(){store.removeListener(refresh);super.dispose();}

  Future<void> publish(LabOrder order) async {
    final result=TextEditingController();
    final unit=TextEditingController();
    final note=TextEditingController();
    try {
      final accepted=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
        title:Text('گزارش آزمایش: ${order.testName}'),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          const Text('گزارش فقط برای شناسه ساختگی TEST-PATIENT-001 ثبت می‌شود.',style:TextStyle(fontSize:12)),
          const SizedBox(height:10),
          TextField(controller:result,decoration:const InputDecoration(labelText:'نتیجه نمایشی')),
          const SizedBox(height:10),
          TextField(controller:unit,decoration:const InputDecoration(labelText:'واحد (در صورت نیاز)')),
          const SizedBox(height:10),
          TextField(controller:note,maxLines:3,decoration:const InputDecoration(labelText:'توضیحات تفصیلی آزمایشگاه')),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('انصراف')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('انتشار گزارش')),
        ],
      ));
      if(accepted!=true||!mounted)return;
      final ok=store.saveLabResult(order.id,result.text,unit.text,note.text);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(ok?'گزارش نمایشی برای پزشک و بیمار قابل مشاهده شد.':'نتیجه معتبر نیست یا قبلاً منتشر شده است.')));
    } finally {result.dispose();unit.dispose();note.dispose();}
  }

  @override
  Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
    const Text('پنل آزمایشگاه',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:_navy)),
    const SizedBox(height:7),
    const Text('درخواست‌ها و گزارش‌های نمونه • دسترسی واقعی هنوز پیاده‌سازی نشده است',style:TextStyle(color:_muted,fontSize:12)),
    const SizedBox(height:15),
    Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text('${store.orders.where((x)=>!x.completed).length} آزمایش در انتظار گزارش',style:const TextStyle(fontWeight:FontWeight.w800)),
      const SizedBox(height:12),
      for(final order in store.orders) ...[
        ListTile(
          leading:Icon(order.completed?Icons.check_circle_outline:Icons.biotech_outlined,color:_teal),
          title:Text(order.testName),
          subtitle:Text('بیمار: ${order.patientId}\n${order.completed?'منتشرشده: ${order.result} ${order.units??''}':'موعد: ${order.dueAt.year}/${order.dueAt.month}/${order.dueAt.day}'}'),
          isThreeLine:true,
        ),
        if(!order.completed) Align(alignment:Alignment.centerLeft,child:OutlinedButton.icon(
          onPressed:()=>publish(order),icon:const Icon(Icons.upload_file_outlined),label:const Text('ورود گزارش تفصیلی'))),
        const Divider(),
      ],
    ]))),
    const SizedBox(height:10),
    const Text('توجه: در نسخه عملیاتی، آزمایشگاه باید احراز هویت شود، نتیجه به‌صورت امضاشده و قابل ممیزی ثبت گردد و فقط با مجوز به پرونده بیمار منتقل شود.',style:TextStyle(fontSize:11,color:_muted)),
  ]);
}
