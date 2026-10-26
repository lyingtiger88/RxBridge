import 'package:flutter/material.dart';

void main() => runApp(const RxBridgeApp());

class RxBridgeApp extends StatelessWidget {
  const RxBridgeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'RxBridge',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF15678C)), useMaterial3: true),
    locale: const Locale('fa'),
    supportedLocales: const [Locale('fa'), Locale('en')],
    home: const Directionality(textDirection: TextDirection.rtl, child: RxBridgeHome()),
  );
}

class RxBridgeHome extends StatefulWidget {
  const RxBridgeHome({super.key});
  @override
  State<RxBridgeHome> createState() => _RxBridgeHomeState();
}

class _RxBridgeHomeState extends State<RxBridgeHome> {
  int selected = 0;
  String dosageForm = 'قرص';
  String route = 'خوراکی';
  String frequency = 'روزی یک نوبت';
  final drug = TextEditingController();
  final amount = TextEditingController();
  final days = TextEditingController();
  final custom = TextEditingController();
  final reason = TextEditingController();
  final List<String> entries = [];

  final forms = const ['قرص','کپسول','شربت','آمپول / ویال','شیاف','قطره','سایر'];
  final routes = const ['خوراکی','عضلانی','وریدی','زیرجلدی','مقعدی','موضعی','سایر'];
  final frequencies = const ['روزی یک نوبت','روزی دو نوبت','روزی سه نوبت','در صورت نیاز','سایر'];

  @override
  void dispose() {
    drug.dispose(); amount.dispose(); days.dispose(); custom.dispose(); reason.dispose();
    super.dispose();
  }

  Future<void> addDraft() async {
    final a = double.tryParse(amount.text.trim());
    final d = int.tryParse(days.text.trim());
    if (drug.text.trim().isEmpty || a == null || !a.isFinite || a <= 0 || d == null || d <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نام دارو، مقدار مثبت و مدت معتبر را وارد کنید.')));
      return;
    }
    final needsConfirmation = dosageForm == 'سایر' || route == 'سایر' || frequency == 'سایر';
    if (needsConfirmation) {
      if (custom.text.trim().isEmpty || reason.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مقدار سفارشی و علت آن ضروری هستند.')));
        return;
      }
      final snapshot = [drug.text, amount.text, days.text, dosageForm, route, frequency, custom.text, reason.text].join('|');
      bool accepted = false;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, update) => AlertDialog(
            title: const Text('تأیید ورودی سفارشی'),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('مقدار: ${custom.text}\nدلیل: ${reason.text}\nاین تأیید به معنی ایمنی بالینی نیست.'),
              CheckboxListTile(value: accepted, title: const Text('ورود عمدی این مقدار را تأیید می‌کنم.'), onChanged: (v) => update(() => accepted = v ?? false)),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('اصلاح')),
              FilledButton(onPressed: accepted ? () => Navigator.pop(dialogContext, true) : null, child: const Text('تأیید پیش‌نویس')),
            ],
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
      if (snapshot != [drug.text, amount.text, days.text, dosageForm, route, frequency, custom.text, reason.text].join('|')) return;
    }
    setState(() { entries.add('${drug.text.trim()} — ${amount.text} — $dosageForm — $route — $frequency — ${days.text} روز'); });
    drug.clear(); amount.clear(); days.clear(); custom.clear(); reason.clear();
  }

  Widget editor() => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('ثبت نسخه آزمایشی', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    const Text('فقط داده ساختگی؛ امکان نسخه‌نویسی رسمی یا تأیید بالینی وجود ندارد.'),
    const SizedBox(height: 16),
    TextField(controller: drug, decoration: const InputDecoration(labelText: 'نام داروی نمونه', border: OutlineInputBorder())),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(initialValue: dosageForm, decoration: const InputDecoration(labelText: 'شکل دارویی', border: OutlineInputBorder()), items: forms.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (x) => setState(() => dosageForm = x ?? dosageForm)),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(initialValue: route, decoration: const InputDecoration(labelText: 'مسیر مصرف آزمایشی', border: OutlineInputBorder()), items: routes.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (x) => setState(() => route = x ?? route)),
    const SizedBox(height: 12),
    TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مقدار هر نوبت — عدد آزمایشی', border: OutlineInputBorder())),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(initialValue: frequency, decoration: const InputDecoration(labelText: 'نوبت مصرف', border: OutlineInputBorder()), items: frequencies.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (x) => setState(() => frequency = x ?? frequency)),
    const SizedBox(height: 12),
    TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مدت (روز)', border: OutlineInputBorder())),
    if (dosageForm == 'سایر' || route == 'سایر' || frequency == 'سایر') ...[
      const SizedBox(height: 12), TextField(controller: custom, decoration: const InputDecoration(labelText: 'مقدار سفارشی', border: OutlineInputBorder())),
      const SizedBox(height: 12), TextField(controller: reason, decoration: const InputDecoration(labelText: 'علت مقدار سفارشی', border: OutlineInputBorder())),
    ],
    const SizedBox(height: 18),
    FilledButton(onPressed: addDraft, child: const Text('افزودن به پیش‌نویس')),
    const SizedBox(height: 16),
    const Text('اقلام پیش‌نویس محلی (با خروج پاک می‌شوند):'),
    ...entries.map((x) => ListTile(title: Text(x), leading: const Icon(Icons.medication_outlined))),
  ]);

  Widget about() => ListView(padding: const EdgeInsets.all(20), children: const [
    Text('درباره RxBridge', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    SizedBox(height: 10), Text('پل ارتباط پزشک و داروساز؛ نسخه آزمایشی Flutter برای Android و iOS.', style: TextStyle(fontSize: 16)),
    SizedBox(height: 20), Text('قابلیت‌های نمایشی', style: TextStyle(fontWeight: FontWeight.bold)),
    Text('• پیش‌نویس دارو و مسیر مصرف\n• زمان‌بندی\n• مقدار سفارشی با تأیید صریح\n• رابط فارسی و راست‌چین'),
    SizedBox(height: 18), Text('نقشه راه', style: TextStyle(fontWeight: FontWeight.bold)),
    Text('v0.2 رابط موبایل و درباره برنامه\nv0.3 مدل پیشرفته نسخه\nv0.4 API و احراز هویت\nv0.5 بانک دارویی معتبر\nv0.6 قیمت‌گذاری منبع‌دار\nv0.9 تست بالینی و امنیت\nv1.0 انتشار مشروط به تأییدهای قانونی'),
    SizedBox(height: 18), Text('توجه: نمونه غیرکلینیکی است، هیچ داده بیمار واقعی وارد نکنید.', style: TextStyle(color: Colors.red)),
  ]);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('RxBridge • نسخه آزمایشی'), backgroundColor: Theme.of(context).colorScheme.surfaceContainer),
    body: selected == 0 ? editor() : about(),
    bottomNavigationBar: NavigationBar(selectedIndex: selected, onDestinationSelected: (i) => setState(() => selected=i),
      destinations: const [NavigationDestination(icon: Icon(Icons.edit_note), label: 'پیش‌نویس'), NavigationDestination(icon: Icon(Icons.info_outline), label: 'معرفی و نقشه راه')]),
  );
}
