import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dose_schedule.dart';
import 'custom_entry_snapshot.dart';
import 'medication_form_route.dart';

void main() => runApp(const RxBridgeApp());

class RxBridgeApp extends StatelessWidget {
  const RxBridgeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'RxBridge',
    debugShowCheckedModeBanner: false,
    locale: const Locale('fa'),
    supportedLocales: const [Locale('fa'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF116589)),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
    home: const RxBridgeHome(),
  );
}

class RxBridgeHome extends StatefulWidget {
  const RxBridgeHome({super.key});
  @override
  State<RxBridgeHome> createState() => _RxBridgeHomeState();
}

class _RxBridgeHomeState extends State<RxBridgeHome> {
  int selected = 0;
  String activeRole = 'انتخاب نقش';

  void selectRole(String role) {
    setState(() {
      activeRole = role;
      selected = switch (role) {
        'پزشک' => 2,
        'داروخانه' => 3,
        'بیمه' => 5,
        _ => 0,
      };
    });
  }

  Widget roleSwitcher() => Card(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final role in ['پزشک', 'داروخانه', 'بیمه'])
            ChoiceChip(
              avatar: Icon(switch (role) {
                'پزشک' => Icons.medical_services_outlined,
                'داروخانه' => Icons.local_pharmacy_outlined,
                _ => Icons.health_and_safety_outlined,
              }, size: 18),
              label: Text(role),
              selected: activeRole == role,
              onSelected: (_) => selectRole(role),
            ),
        ],
      ),
    ),
  );
  final patient = TextEditingController(text: 'TEST-001');
  final age = TextEditingController();
  final weight = TextEditingController();
  final allergies = TextEditingController();
  final drug = TextEditingController();
  final amount = TextEditingController();
  final days = TextEditingController();
  final instructions = TextEditingController();
  final custom = TextEditingController();
  final reason = TextEditingController();
  final unitPrice = TextEditingController();
  final quantity = TextEditingController();
  final insurance = TextEditingController(text: '0');
  String form = 'قرص', route = 'خوراکی', frequency = 'روزی یک نوبت';
  String product = 'انتخاب نشده';
  String interval = 'دستور زمان‌بندی مستقل';
  final startTime = TextEditingController(text: '08:00');
  static const demoProducts = <String, (String, String)>{
    'انتخاب نشده': ('قرص', 'خوراکی'),
    'TEST-TABLET-A (ساختگی)': ('قرص', 'خوراکی'),
    'TEST-CHEWABLE-TABLET (ساختگی)': ('قرص جویدنی', 'خوراکی - جویدنی'),
    'TEST-SUBLINGUAL-TABLET (ساختگی)': ('قرص زیرزبانی', 'زیرزبانی'),
    'TEST-SYRUP-B (ساختگی)': ('شربت', 'خوراکی'),
    'TEST-SUPPOSITORY-C (ساختگی)': ('شیاف مقعدی', 'مقعدی'),
    'TEST-VAGINAL-PESSARY (ساختگی)': ('فرآورده واژینال', 'واژینال'),
    'TEST-INJECTION-D (ساختگی)': ('آمپول / ویال', 'تزریقی (نوع مشخص نشده)'),
  };
  static const intervals = <String, int>{'دستور زمان‌بندی مستقل': 0, 'هر ۲۴ ساعت': 24, 'هر ۱۲ ساعت': 12, 'هر ۸ ساعت': 8, 'هر ۶ ساعت': 6, 'هر ۴ ساعت': 4};
  void selectProduct(String p) {
    product = p;
    form = demoProducts[p]!.$1;
    route = demoProducts[p]!.$2;
    drug.text = p == 'انتخاب نشده' ? '' : p;
  }
  void selectForm(String value) {
    form = value;
    route = MedicationFormRoute.defaultRouteFor(value);
  }
  List<String> get availableRoutes => MedicationFormRoute.routesFor(form);
  void selectInterval(String value) {
    interval=value;
    final hours=intervals[value]??0;
    if(hours>0){final count=24~/hours; if(count<=4)frequency=['','روزی یک نوبت','روزی دو نوبت','روزی سه نوبت','روزی چهار نوبت'][count]; else frequency='سایر';}
  }
  void selectFrequency(String value){frequency=value; interval='دستور زمان‌بندی مستقل';}
  String get calculatedSchedule {
    final hours=intervals[interval]??0;
    if(hours==0)return 'نوبت روزانه با فاصله دقیق یکی نیست؛ ساعت‌ها را پزشک باید مشخص کند.';
    try{return exampleTimes(intervalHours:hours,start:startTime.text).join(' ، ');}catch(_){return 'زمان شروع نامعتبر است؛ قالب HH:mm لازم است.';}
  }

  String stage = 'پیش‌نویس';
  final entries = <String>[];
  final timeline = <String>[];

  static const names = ['داشبورد','بیمار','نسخه','داروساز','تحویل','قیمت','درباره'];
  static const icons = [Icons.dashboard_outlined,Icons.person_outline,Icons.medication_outlined,Icons.fact_check_outlined,Icons.inventory_2_outlined,Icons.payments_outlined,Icons.info_outline];
  static const forms = MedicationFormRoute.forms;
  static const routes = MedicationFormRoute.allRoutes;
  static const frequencies = ['روزی یک نوبت','روزی دو نوبت','روزی سه نوبت','روزی چهار نوبت','در صورت نیاز','سایر'];

  @override
  void dispose() {
    for (final c in [patient,age,weight,allergies,drug,amount,days,instructions,custom,reason,unitPrice,quantity,insurance,startTime]) { c.dispose(); }
    super.dispose();
  }

  void message(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  Widget title(String text, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start,children:[
    Text(text,style: const TextStyle(fontWeight: FontWeight.bold,fontSize: 24)),
    const SizedBox(height: 6),Text(subtitle,style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    const SizedBox(height: 20),
  ]);
  Widget field(TextEditingController controller,String label,{TextInputType? keyboard}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: controller,keyboardType: keyboard,decoration: InputDecoration(labelText: label)),
  );
  Widget choice(String label,String value,List<String> options,ValueChanged<String> change) =>
    Padding(padding: const EdgeInsets.only(bottom: 12),child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,decoration: InputDecoration(labelText: label),
      items: options.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
      onChanged: (v){if(v!=null)setState(()=>change(v));},
    ));
  Widget panel(String heading,Widget child) => Card(child: Padding(padding: const EdgeInsets.all(16),child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,children:[Text(heading,style: const TextStyle(fontWeight: FontWeight.bold,fontSize: 17)),const SizedBox(height: 12),child])));

  Widget dashboard() => ListView(padding: const EdgeInsets.all(16),children:[
    title('داشبورد RxBridge','مرکز مدیریت نسخه‌های آزمایشی، پزشک و داروساز'),
    panel('انتخاب نقش برای تست',Column(crossAxisAlignment: CrossAxisAlignment.stretch,children:[
      const Text('برای آزمایش گردش‌کار، یکی از سه محیط را انتخاب کنید. این انتخاب فقط در نسخه تستی است.'),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed:()=>selectRole('پزشک'),icon:const Icon(Icons.medical_services_outlined),label:const Text('ورود به محیط پزشک')),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed:()=>selectRole('داروخانه'),icon:const Icon(Icons.local_pharmacy_outlined),label:const Text('ورود به محیط داروخانه')),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed:()=>selectRole('بیمه'),icon:const Icon(Icons.health_and_safety_outlined),label:const Text('ورود به محیط بیمه')),
    ])),
    const SizedBox(height: 8),
    panel('وضعیت نمونه آزمایشی',Column(crossAxisAlignment: CrossAxisAlignment.start,children:[
      Text('نسخه: $stage'),Text('تعداد اقلام: ${entries.length}'),const SizedBox(height: 8),
      const Text('تمام داده‌ها فقط در حافظه این اجرا هستند؛ سیستم بالینی واقعی نیست.'),
    ])),
    const SizedBox(height: 8),
    Wrap(spacing: 8,runSpacing: 8,children:[
      for(final pair in [(1,'ثبت بیمار'),(2,'نسخه جدید'),(3,'بررسی داروساز'),(4,'تحویل'),(5,'محاسبه قیمت')])
        ActionChip(label: Text(pair.$2 as String),onPressed: ()=>setState(()=>selected=pair.$1 as int)),
    ]),
    const SizedBox(height: 16),
    panel('گردش کار',const Text('۱. پرونده بیمار → ۲. پیش‌نویس نسخه → ۳. بررسی داروساز → ۴. تحویل آزمایشی → ۵. قیمت‌گذاری نمایشی')),
  ]);

  Widget patientPage() => ListView(padding: const EdgeInsets.all(16),children:[
    title('پرونده بیمار','اطلاعات ساختگی برای آزمایش فرم‌ها'),
    field(patient,'شناسه تست (باید با TEST- شروع شود)'),
    field(age,'سن (سال)',keyboard: TextInputType.number),
    field(weight,'وزن (کیلوگرم)',keyboard: TextInputType.number),
    field(allergies,'حساسیت دارویی اعلام‌شده (متن نمایشی)'),
    FilledButton(onPressed: (){
      if(!patient.text.trim().startsWith('TEST-')){message('فقط شناسه آزمایشی TEST- مجاز است.');return;}
      message('مشخصات آزمایشی در حافظه همین اجرا نگهداری می‌شود.');
    },child: const Text('ثبت اطلاعات آزمایشی')),
  ]);

  Future<void> addDraft() async {
    if(stage!='پیش‌نویس'){message('برای افزودن دارو ابتدا نسخه آزمایشی جدید ایجاد کنید.');return;}
    final a=double.tryParse(amount.text.trim()),d=int.tryParse(days.text.trim());
    if (product != 'انتخاب نشده' && form != demoProducts[product]!.$1) {
      message('شکل دارویی این فرآورده آزمایشی قابل تغییر نیست؛ فرآورده سازگار دیگری انتخاب کنید.');
      return;
    }
    if (!MedicationFormRoute.isRouteAllowed(form, route)) {
      message('مسیر مصرف با شکل دارویی سازگار نیست؛ مسیر مناسب را انتخاب کنید.');
      return;
    }
    if (MedicationFormRoute.requiresSpecificRoute(form, route)) {
      message('مسیر دقیق این شکل دارویی مشخص نیست؛ پیش از ثبت باید مسیر مصرف تأیید شود.');
      return;
    }
    if(intervals[interval]!=0 && calculatedSchedule.startsWith('زمان شروع نامعتبر')){message('ساعت شروع نامعتبر است.');return;}
    if(!patient.text.trim().startsWith('TEST-')||drug.text.trim().isEmpty||a==null||!a.isFinite||a<=0||d==null||d<=0){
      message('اطلاعات آزمایشی بیمار، دارو، مقدار و مدت را بررسی کنید.');return;
    }
    if((frequency=='در صورت نیاز'||form=='آمپول / ویال')&&instructions.text.trim().isEmpty){
      message('برای این مورد دستور تکمیلی الزامی است.');return;
    }
    final customNeeded=form=='سایر'||route=='سایر'||frequency=='سایر';
    if(customNeeded){
      if(custom.text.trim().isEmpty||reason.text.trim().isEmpty){message('مقدار و علت سفارشی ضروری است.');return;}
      final snapshot = buildCustomEntrySnapshot(patient: patient.text, drug: drug.text, amount: amount.text, days: days.text, instructions: instructions.text, form: form, route: route, frequency: frequency, interval: interval, startTime: startTime.text, custom: custom.text, reason: reason.text);
      var confirmed=false;
      final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
        title: const Text('تأیید داده غیراستاندارد'),
        content: SingleChildScrollView(child: Column(mainAxisSize:MainAxisSize.min,children:[
          Text('مقدار: ${custom.text}\nدلیل: ${reason.text}\nاین تأیید جایگزین بررسی ایمنی دارویی نیست.'),
          CheckboxListTile(value:confirmed,onChanged:(v)=>update(()=>confirmed=v??false),title:const Text('داده را بررسی کردم و عمداً وارد کرده‌ام.')),
        ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('اصلاح')),
          FilledButton(onPressed:confirmed?()=>Navigator.pop(ctx,true):null,child:const Text('افزودن به پیش‌نویس'))],
      )));
      if(!mounted||ok!=true)return;
      final currentSnapshot = buildCustomEntrySnapshot(patient: patient.text, drug: drug.text, amount: amount.text, days: days.text, instructions: instructions.text, form: form, route: route, frequency: frequency, interval: interval, startTime: startTime.text, custom: custom.text, reason: reason.text);
      if (snapshot != currentSnapshot) {
        message('داده تغییر کرده است؛ تأیید دوباره الزامی است.');return;
      }
    }
    setState((){
      entries.add('${drug.text.trim()} | $form | $route | ${amount.text} | $frequency | $interval | ${calculatedSchedule} | ${days.text} روز');
      timeline.add('قلم آزمایشی جدید ثبت شد');
      drug.clear();amount.clear();days.clear();instructions.clear();custom.clear();reason.clear();
    });
    message('قلم در پیش‌نویس ذخیره شد.');
  }

  Widget prescription() => ListView(padding: const EdgeInsets.all(16),children:[
    title('نسخه‌نویسی','نوع دارو، مسیر تجویز، نوبت و توضیحات'),
    choice('داروی کاتالوگ آزمایشی',product,demoProducts.keys.toList(),selectProduct),
    const Text('فهرست فعلاً ساختگی است؛ شکل و مسیر واقعی فقط پس از اتصال بانک دارویی دارای منبع باید خودکار شوند.'),
    const SizedBox(height: 12),
    field(drug,'نام داروی آزمایشی'),
    choice('شکل دارویی', form, forms, selectForm),
    choice('مسیر مصرف', route, availableRoutes, (v) => route = v),
    Text(MedicationFormRoute.helpTextFor(form), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    const SizedBox(height: 12),
    field(amount,'مقدار هر نوبت (عدد نمایشی)',keyboard: TextInputType.number),
    choice('نوبت مصرف',frequency,frequencies,selectFrequency),
    choice('فاصله زمانی دقیق (فقط در صورت تجویز)',interval,intervals.keys.toList(),selectInterval),
    field(startTime,'ساعت شروع HH:mm'),
    panel('پیش‌نمایش نوبت‌ها',Text(calculatedSchedule)),
    field(days,'مدت مصرف (روز)',keyboard:TextInputType.number),
    field(instructions,'دستور مصرف تکمیلی'),
    if(form=='سایر'||route=='سایر'||frequency=='سایر')...[
      field(custom,'مقدار سفارشی'),field(reason,'علت ورود مقدار سفارشی'),
    ],
    FilledButton(onPressed:addDraft,child: const Text('افزودن دارو به پیش‌نویس')),
    const SizedBox(height: 14),
    panel('اقلام نسخه',Column(children:[
      if(entries.isEmpty)const Text('هنوز قلمی ثبت نشده است.'),
      for(final e in entries)ListTile(leading:const Icon(Icons.medication_outlined),title:Text(e)),
    ])),
  ]);

  Widget pharmacy() => ListView(padding: const EdgeInsets.all(16),children:[
    title('بررسی داروساز','شبیه‌سازی کنترل و ارجاع نسخه'),
    panel('وضعیت نسخه',Text('وضعیت فعلی: $stage\nتعداد اقلام: ${entries.length}\nهشدار: هیچ کنترل تداخل یا اعتبارسنجی بالینی انجام نشده است.')),
    FilledButton(onPressed:entries.isNotEmpty&&stage=='پیش‌نویس'?(){
      setState((){stage='بررسی‌شده (نمایشی)';timeline.add('بررسی داروساز شبیه‌سازی شد');});
    }:null,child:const Text('ثبت بررسی نمایشی')),
    const SizedBox(height: 12),
    OutlinedButton(onPressed:(){
      setState((){stage='پیش‌نویس';timeline.add('برای اصلاح به پیش‌نویس برگشت');});
    },child:const Text('ارجاع برای اصلاح')),
  ]);

  Widget dispensing() => ListView(padding: const EdgeInsets.all(16),children:[
    title('تحویل دارو','ثبت مرحله تحویل؛ صرفاً شبیه‌سازی'),
    panel('اطلاعات تحویل',Text('شناسه نمونه: ${patient.text}\nاقلام: ${entries.length}\nوضعیت: $stage')),
    FilledButton(onPressed:stage=='بررسی‌شده (نمایشی)'?(){
      setState((){stage='تحویل‌شده (نمایشی)';timeline.add('تحویل آزمایشی ثبت شد');});
    }:null,child: const Text('ثبت تحویل آزمایشی')),
    const SizedBox(height: 12),
    OutlinedButton(onPressed:(){
      setState((){stage='پیش‌نویس';entries.clear();timeline.clear();});
    },child:const Text('نسخه آزمایشی جدید')),
    panel('سوابق',Column(children:[for(final e in timeline)ListTile(title:Text(e),dense:true)])),
  ]);

  Widget pricing() => ListView(padding:const EdgeInsets.all(16),children:[
    title('قیمت‌گذاری نمایشی','ریال؛ بدون ارتباط با قیمت رسمی یا بیمه واقعی'),
    field(quantity,'تعداد واحد (عدد صحیح)',keyboard:TextInputType.number),
    field(unitPrice,'قیمت هر واحد فرضی (ریال)',keyboard:TextInputType.number),
    field(insurance,'سهم بیمه فرضی (ریال)',keyboard:TextInputType.number),
    FilledButton(onPressed:(){
      final q=int.tryParse(quantity.text),p=int.tryParse(unitPrice.text),i=int.tryParse(insurance.text);
      if(q==null||q<=0||p==null||p<0||i==null||i<0||q>9000000||p>9000000000){
        message('مبالغ ورودی نامعتبر هستند.');return;
      }
      final total=q*p;
      if(i>total){message('سهم فرضی بیمه از مبلغ کل بیشتر است.');return;}
      showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('برآورد فرضی'),
        content:Text('کل: $total ریال\nسهم بیمه ورودی: $i ریال\nمانده فرضی: ${total-i} ریال\nفاقد اعتبار برای فروش واقعی'),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('بستن'))]));
    },child:const Text('محاسبه آزمایشی')),
  ]);

  Widget about() => ListView(padding:const EdgeInsets.all(16),children:[
    title('درباره RxBridge','پل نسخه‌نویسی پزشک و داروساز | برنامه چندسکویی'),
    panel('نسخه نمایشی',const Text('صفحات بیمار، نسخه، بررسی داروساز، تحویل و محاسبات مالی آزمایشی برای Android و iOS.')),
    panel('نقشه راه',const Text('v0.2 رابط و فرم‌های اولیه\nv0.3 اعتبارسنجی و داده ساختاریافته\nv0.4 API و ورود امن\nv0.5 بانک دارویی معتبر\nv0.6 قیمت رسمی و قواعد مالی پس از دریافت دسترسی\nv0.9 امنیت و بررسی بالینی\nv1.0 انتشار پس از الزامات قانونی')),
    panel('توجه ایمنی',const Text('این اپ فعلاً نمایشی است؛ احراز هویت واقعی، کنترل بالینی، تأیید بیمه و صدور نسخه قانونی ندارد. هیچ اطلاعات واقعی بیمار وارد نکنید.')),
  ]);

  Widget page() => switch(selected){0=>dashboard(),1=>patientPage(),2=>prescription(),3=>pharmacy(),4=>dispensing(),5=>pricing(),_=>about()};
  @override
  Widget build(BuildContext context) => Directionality(textDirection:TextDirection.rtl,child:Scaffold(
    appBar:AppBar(title:const Text('RxBridge'),actions:[
      IconButton(tooltip:'معرفی نرم‌افزار',onPressed:()=>setState(()=>selected=6),icon:const Icon(Icons.info_outline)),
    ]),
    drawer:Drawer(child:SafeArea(child:ListView(children:[
      const ListTile(title:Text('RxBridge',style:TextStyle(fontWeight:FontWeight.bold,fontSize:22)),subtitle:Text('محیط آزمایشی — اطلاعات ساختگی')),
      for(var i=0;i<names.length;i++)ListTile(leading:Icon(icons[i]),title:Text(names[i]),selected:selected==i,onTap:(){
        Navigator.pop(context);setState(()=>selected=i);
      }),
    ]))),
    body:Column(children:[roleSwitcher(),Expanded(child:page())]),
    bottomNavigationBar:NavigationBar(selectedIndex:selected<=2?selected:0,onDestinationSelected:(i)=>setState(()=>selected=i),
      destinations:const [
        NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'داشبورد'),
        NavigationDestination(icon:Icon(Icons.person_outline),label:'بیمار'),
        NavigationDestination(icon:Icon(Icons.medication_outlined),label:'نسخه'),
      ]),
  ));
}
