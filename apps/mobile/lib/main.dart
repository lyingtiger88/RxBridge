import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'care_pages.dart';

void main() => runApp(const RxBridgeApp());

const navy = Color(0xFF102A43);
const teal = Color(0xFF16A6A1);
const canvas = Color(0xFFF3F7FA);
const ink = Color(0xFF183247);
const muted = Color(0xFF6C8293);

enum AppRole { doctor, patient, pharmacy, insurance, laboratory }

extension AppRoleInfo on AppRole {
  String get title => switch (this) {
    AppRole.doctor => 'پزشک',
    AppRole.patient => 'بیمار',
    AppRole.pharmacy => 'داروساز',
    AppRole.insurance => 'مسئول بیمه',
    AppRole.laboratory => 'آزمایشگاه',
  };
  String get subtitle => switch (this) {
    AppRole.doctor => 'مدیریت بیماران، نسخه و پیگیری درمان',
    AppRole.patient => 'پرونده سلامت، پزشک و روند درمان',
    AppRole.pharmacy => 'نسخه‌های ورودی، موجودی و تحویل دارو',
    AppRole.insurance => 'گزارش‌ها و آمار خدمات بیمه‌ای',
    AppRole.laboratory => 'دریافت درخواست و ارسال گزارش آزمایش',
  };
  IconData get icon => switch (this) {
    AppRole.doctor => Icons.medical_services_rounded,
    AppRole.patient => Icons.person_rounded,
    AppRole.pharmacy => Icons.local_pharmacy_rounded,
    AppRole.insurance => Icons.health_and_safety_rounded,
    AppRole.laboratory => Icons.science_rounded,
  };
  Color get tint => switch (this) {
    AppRole.doctor => const Color(0xFFE3F3F8),
    AppRole.patient => const Color(0xFFE7F5F0),
    AppRole.pharmacy => const Color(0xFFFFF2E5),
    AppRole.insurance => const Color(0xFFEDEBFA),
    AppRole.laboratory => const Color(0xFFE6F2FF),
  };
}

class RxBridgeApp extends StatelessWidget {
  const RxBridgeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'پل سلامت | RxBridge',
    debugShowCheckedModeBanner: false,
    locale: const Locale('fa'),
    supportedLocales: const [Locale('fa'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(seedColor: teal, primary: teal, secondary: navy, surface: Colors.white),
      fontFamily: null,
      appBarTheme: const AppBarTheme(backgroundColor: canvas, foregroundColor: navy, elevation: 0, centerTitle: false),
      cardTheme: CardThemeData(color: Colors.white, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFFE8EFF3)))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: const Color(0xFFF7FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2EAF0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2EAF0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: teal, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white, indicatorColor: const Color(0xFFDDF4F1),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(fontSize: 11, fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500, color: s.contains(WidgetState.selected) ? teal : muted)),
      ),
    ),
    home: const RoleSelectionPage(),
  );
}

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 54});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF20C4B8), Color(0xFF147A9A), navy]),
      borderRadius: BorderRadius.circular(size * .32),
      boxShadow: [BoxShadow(color: teal.withValues(alpha: .20), blurRadius: 18, offset: const Offset(0, 8))],
    ),
    child: Icon(Icons.hub_rounded, color: Colors.white, size: size * .56),
  );
}

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: ListView(padding: const EdgeInsets.fromLTRB(22, 30, 22, 28), children: [
        const SizedBox(height: 12),
        Center(child: Column(children: [
          const BrandMark(size: 76),
          const SizedBox(height: 18),
          const Text('پل سلامت', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: navy, letterSpacing: .3)),
          const SizedBox(height: 6),
          Text('RxBridge • ارتباط هوشمند در مسیر مراقبت سلامت', style: TextStyle(color: muted, fontSize: 13)),
        ])),
        const SizedBox(height: 36),
        const Text('به RxBridge خوش آمدید', textAlign: TextAlign.right, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 7),
        const Text('برای ورود، محیط کاری خود را انتخاب کنید.', textAlign: TextAlign.right, style: TextStyle(color: muted)),
        const SizedBox(height: 20),
        for (final role in AppRole.values) ...[
          _RoleCard(role: role, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoleWorkspace(role: role)))),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFFFF6E8), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF4E5C9))),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFFB7791F), size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('نسخه نمایشی است؛ انتخاب نقش به‌تنهایی احراز هویت یا مجوز دسترسی ایجاد نمی‌کند. از اطلاعات واقعی بیمار استفاده نکنید.', style: TextStyle(fontSize: 12, color: Color(0xFF805A24), height: 1.6))),
          ]),
        ),
        const SizedBox(height: 20),
        Center(child: Text('نسخه آزمایشی • v0.3.0', style: TextStyle(color: muted.withValues(alpha: .8), fontSize: 11))),
      ]),
    ))),
  );
}

class _RoleCard extends StatelessWidget {
  final AppRole role;
  final VoidCallback onTap;
  const _RoleCard({required this.role, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white, borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5EDF2))),
        child: Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: role.tint, borderRadius: BorderRadius.circular(16)), child: Icon(role.icon, color: navy, size: 27)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ورود به پنل ${role.title}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 4),
            Text(role.subtitle, style: const TextStyle(fontSize: 11, color: muted)),
          ])),
          const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: muted),
        ]),
      ),
    ),
  );
}

class RoleWorkspace extends StatefulWidget {
  final AppRole role;
  const RoleWorkspace({super.key, required this.role});
  @override
  State<RoleWorkspace> createState() => _RoleWorkspaceState();
}

class _RoleWorkspaceState extends State<RoleWorkspace> {
  int tab = 0;
  String? consentGranted;
  bool showConfidential = false;
  final search = TextEditingController();
  final messageController = TextEditingController();
  final drugController = TextEditingController();
  final noteController = TextEditingController();

  @override
  void dispose() {
    search.dispose(); messageController.dispose(); drugController.dispose(); noteController.dispose();
    super.dispose();
  }

  List<_NavItem> get nav => switch (widget.role) {
    AppRole.doctor => const [_NavItem('خانه', Icons.grid_view_rounded), _NavItem('بیماران', Icons.people_alt_rounded), _NavItem('نسخه‌ها', Icons.receipt_long_rounded), _NavItem('پیام‌ها', Icons.chat_bubble_outline_rounded), _NavItem('آزمایش‌ها', Icons.science_rounded)],
    AppRole.patient => const [_NavItem('خانه', Icons.home_rounded), _NavItem('پرونده من', Icons.folder_shared_rounded), _NavItem('پزشک من', Icons.medical_services_rounded), _NavItem('پیام‌ها', Icons.chat_bubble_outline_rounded), _NavItem('قند و آزمایش', Icons.bloodtype_outlined)],
    AppRole.pharmacy => const [_NavItem('خانه', Icons.grid_view_rounded), _NavItem('نسخه‌ها', Icons.receipt_long_rounded), _NavItem('موجودی', Icons.inventory_2_rounded), _NavItem('تحویل', Icons.local_shipping_rounded)],
    AppRole.insurance => const [_NavItem('خانه', Icons.grid_view_rounded), _NavItem('گزارش‌ها', Icons.analytics_rounded), _NavItem('خدمات', Icons.health_and_safety_rounded), _NavItem('حساب', Icons.account_circle_rounded)],
    AppRole.laboratory => const [_NavItem('آزمایشگاه', Icons.science_rounded), _NavItem('درخواست‌ها', Icons.assignment_rounded)],
  };

  String get heading => switch ((widget.role, tab)) {
    (AppRole.doctor, 0) => 'داشبورد پزشک',
    (AppRole.doctor, 1) => 'بیماران من',
    (AppRole.doctor, 2) => 'مدیریت نسخه‌ها',
    (AppRole.doctor, 4) => 'آزمایش‌ها و پایش',
    (AppRole.doctor, _) => 'پیام‌های بیماران',
    (AppRole.patient, 0) => 'سلام، خوش آمدید',
    (AppRole.patient, 1) => 'پرونده سلامت من',
    (AppRole.patient, 2) => 'پزشک من',
    (AppRole.patient, 4) => 'قند خون و آزمایش',
    (AppRole.patient, _) => 'ارتباط با پزشک',
    (AppRole.pharmacy, 0) => 'داشبورد داروخانه',
    (AppRole.pharmacy, 1) => 'نسخه‌های دریافتی',
    (AppRole.pharmacy, 2) => 'مدیریت موجودی',
    (AppRole.pharmacy, _) => 'تحویل دارو',
    (AppRole.insurance, 0) => 'داشبورد بیمه',
    (AppRole.laboratory, _) => 'پنل آزمایشگاه',
    (AppRole.insurance, 1) => 'گزارش‌های آماری',
    (AppRole.insurance, 2) => 'خدمات تحت پوشش',
    _ => 'حساب کاربری',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(tooltip: 'تغییر نقش', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_forward_rounded)),
      title: Row(children: [const BrandMark(size: 34), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('پل سلامت', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: navy)),
        Text('پنل ${widget.role.title}', style: const TextStyle(fontSize: 10, color: muted)),
      ])]),
      actions: [IconButton(tooltip: 'اعلان‌ها', onPressed: () => _toast('اعلان جدیدی وجود ندارد.'), icon: const Icon(Icons.notifications_none_rounded)), const SizedBox(width: 6)],
    ),
    body: AnimatedSwitcher(duration: const Duration(milliseconds: 240), child: KeyedSubtree(key: ValueKey('${widget.role.name}-$tab'), child: _page())),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (v) => setState(() => tab = v),
      destinations: [for (var i = 0; i < nav.length; i++) NavigationDestination(icon: Icon(nav[i].icon), label: nav[i].label)],
    ),
  );

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  Widget _page() => switch (widget.role) {
    AppRole.doctor => _doctorPage(),
    AppRole.patient => _patientPage(),
    AppRole.pharmacy => _pharmacyPage(),
    AppRole.insurance => _insurancePage(),
    AppRole.laboratory => const LaboratoryPage(),
  };

  Widget _wrap(List<Widget> children) => ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 26), children: children);
  Widget _heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: navy)),
      const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
    ]),
  );
  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) => Container(
    padding: padding, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE7EEF2))),
    child: child,
  );
  Widget _section(String title, {Widget? action}) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 12),
    child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 15))), if (action != null) action]),
  );
  Widget _stat(String label, String value, IconData icon, Color tint) => Expanded(child: _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 36, height: 36, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 19, color: navy)),
    const SizedBox(height: 13), Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: navy)),
    const SizedBox(height: 3), Text(label, style: const TextStyle(fontSize: 10, color: muted)),
  ])));
  Widget _action(String label, IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(16),
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14), decoration: BoxDecoration(color: const Color(0xFFF6FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7EEF2))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: teal, size: 19), const SizedBox(width: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: ink))])),
  );
  Widget _rowItem(IconData icon, String title, String subtitle, {Color color = teal, Widget? trailing}) => Material(
    color: Colors.transparent,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ink)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: muted)),
      trailing: trailing,
    ),
  );
  Widget _banner(String text, IconData icon, Color bg, Color fg) => Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: fg, size: 19), const SizedBox(width: 9), Expanded(child: Text(text, style: TextStyle(color: fg, fontSize: 11, height: 1.55)))]));
  Widget _doctorPage() {
    if (tab == 4) { return const CareTrackingPage(clinician: true); }
    if (tab == 1) {
      return _wrap([
      _heading('بیماران من', 'دسترسی به پرونده بیماران دارای رابطه درمانی مجاز'),
      TextField(controller: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'جستجوی بیمار یا شناسه')),
      const SizedBox(height: 14),
      _card(child: Column(children: [
        _rowItem(Icons.person_rounded, 'بیمار آزمایشی ۰۰۱', 'آخرین مراجعه: ۱۴۰۵/۰۸/۱۰', trailing: const Icon(Icons.chevron_left_rounded)),
        const Divider(height: 1),
        _rowItem(Icons.person_rounded, 'بیمار آزمایشی ۰۰۲', 'پیگیری درمان: نیازمند بررسی', color: const Color(0xFFB7791F), trailing: const Icon(Icons.chevron_left_rounded)),
      ])),
      const SizedBox(height: 14), _banner('این فهرست نمایشی است. در نسخه عملیاتی، فقط بیماران دارای رابطه درمانی فعال و مجوز معتبر نمایش داده می‌شوند.', Icons.lock_outline_rounded, const Color(0xFFEAF3F8), navy),
    ]);
    }
    if (tab == 2) {
      return _wrap([
      _heading('نسخه‌ها', 'مدیریت نسخه‌های ثبت‌شده و پیش‌نویس‌ها'),
      _card(child: Column(children: [
        _rowItem(Icons.description_rounded, 'نسخه پیش‌نویس #RX-001', '۲ قلم دارو • منتظر ثبت نهایی', trailing: const Chip(label: Text('پیش‌نویس'))),
        const Divider(height: 1),
        _rowItem(Icons.send_rounded, 'نسخه #RX-000', 'ارسال‌شده به داروخانه نمونه', color: teal, trailing: const Chip(label: Text('ارسال‌شده'))),
      ])),
      const SizedBox(height: 14), FilledButton.icon(onPressed: () => _toast('فرم نسخه‌نویسی در مرحله بعد به این پنل متصل می‌شود.'), icon: const Icon(Icons.add_rounded), label: const Text('ایجاد نسخه جدید')),
    ]);
    }
    if (tab == 3) {
      return _wrap([
      _heading('پیام‌ها', 'گفت‌وگوی امن با بیماران تحت درمان'),
      _card(child: Column(children: [
        _rowItem(Icons.chat_bubble_outline_rounded, 'بیمار آزمایشی ۰۰۱', 'پیام جدید: پیگیری روند درمان', color: teal, trailing: const Text('۰۹:۳۰')),
        const Divider(height: 1),
        TextField(controller: messageController, decoration: const InputDecoration(hintText: 'پیام نمایشی بنویسید...', prefixIcon: Icon(Icons.edit_rounded))),
        const SizedBox(height: 10), Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: () { if(messageController.text.trim().isEmpty)return; messageController.clear(); _toast('پیام در محیط نمایشی ارسال شد.'); }, icon: const Icon(Icons.send_rounded), label: const Text('ارسال'))),
      ])),
      const SizedBox(height: 12), _banner('پیام‌رسانی واقعی، زمان پاسخ‌گویی و حفاظت از پیوست‌ها به Backend امن نیاز دارد و جایگزین خدمات اورژانسی نیست.', Icons.info_outline_rounded, const Color(0xFFFFF5E6), const Color(0xFF94631A)),
    ]);
    }
    return _wrap([
      _heading('صبح بخیر، پزشک', 'نمای کلی فعالیت حرفه‌ای شما در RxBridge'),
      _card(child: Row(children: [
        const CircleAvatar(radius: 27, backgroundColor: Color(0xFFE3F3F8), child: Icon(Icons.person_rounded, color: navy, size: 30)),
        const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('پزشک نمونه', style: TextStyle(fontWeight: FontWeight.w900, color: navy, fontSize: 15)), SizedBox(height: 4), Text('پروفایل حرفه‌ای • تکمیل ۷۵٪', style: TextStyle(color: muted, fontSize: 11))])),
        const Icon(Icons.verified_rounded, color: teal),
      ])),
      const SizedBox(height: 14),
      Row(children: [_stat('بیماران فعال', '۲۴', Icons.people_alt_rounded, const Color(0xFFE3F3F8)), const SizedBox(width: 10), _stat('نسخه امروز', '۰۸', Icons.receipt_long_rounded, const Color(0xFFE7F5F0))]),
      _section('دسترسی سریع'),
      Wrap(spacing: 9, runSpacing: 9, children: [
        _action('برنامه آزمایش‌ها', Icons.science_outlined, () => setState(() => tab = 4)),
        _action('پرونده بیماران', Icons.folder_shared_rounded, () => setState(() => tab = 1)),
        _action('نسخه جدید', Icons.add_box_rounded, () => setState(() => tab = 2)),
        _action('پیام‌ها', Icons.chat_rounded, () => setState(() => tab = 3)),
      ]),
      _section('نیازمند پیگیری', action: TextButton(onPressed: () => setState(() => tab = 1), child: const Text('همه موارد'))),
      _card(child: Column(children: [
        _rowItem(Icons.event_note_rounded, 'پیگیری درمان بیمار ۰۰۲', 'یک درخواست پیگیری جدید', color: const Color(0xFFB7791F), trailing: const Icon(Icons.chevron_left_rounded)),
        const Divider(height: 1), _rowItem(Icons.rate_review_rounded, 'بازخورد جدید', 'یک ارزیابی ثبت‌شده برای پروفایل', color: teal, trailing: const Icon(Icons.chevron_left_rounded)),
      ])),
    ]);
  }

  Widget _patientPage() {
    if (tab == 4) { return const CareTrackingPage(clinician: false); }
    if (tab == 1) {
      return _wrap([
      _heading('پرونده سلامت من', 'اطلاعات درمانی و سوابق ثبت‌شده'),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('پرونده درمانی خصوصی', style: TextStyle(fontWeight: FontWeight.w900, color: navy, fontSize: 16)),
        const SizedBox(height: 5), const Text('قابل مشاهده برای شما و پزشک معالج مجاز', style: TextStyle(color: muted, fontSize: 11)),
        const SizedBox(height: 12),
        _rowItem(Icons.medical_information_rounded, 'سوابق ویزیت', '۳ مراجعه ثبت‌شده'),
        const Divider(height: 1), _rowItem(Icons.science_rounded, 'آزمایش‌ها', '۲ گزارش آزمایشگاهی'),
        const Divider(height: 1), _rowItem(Icons.medication_rounded, 'داروها و نسخه‌ها', '۱ نسخه فعال'),
        const Divider(height: 1), _rowItem(Icons.monitor_heart_rounded, 'تشخیص‌ها و روند درمان', 'نمایش تاریخچه'),
      ])),
      _section('بخش محرمانه'),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _banner('این بخش برای اطلاعات حساس سلامت است. در نسخه واقعی، دسترسی پزشک به رضایت جداگانه و قابل لغو شما نیاز دارد.', Icons.shield_rounded, const Color(0xFFFFF3E8), const Color(0xFF94631A)),
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: showConfidential,
            onChanged: (v) => setState(() => showConfidential = v),
            title: const Text('نمایش نمونه محرمانه'),
            subtitle: const Text('فقط نمایش ساختاری؛ فاقد داده واقعی'),
          ),
        ),
        if(showConfidential) const Text('هیچ اطلاعات حساسی در نمونه ذخیره نشده است.', style: TextStyle(color: muted, fontSize: 12)),
      ])),
      _section('مجوزهای دسترسی'),
      _card(child: Column(children: [
        _rowItem(Icons.person_search_rounded, 'پزشک معالج نمونه', 'درخواست دسترسی به پرونده عادی', color: teal),
        const SizedBox(height: 8), OutlinedButton.icon(onPressed: () => setState(() => consentGranted = consentGranted == 'granted' ? 'revoked' : 'granted'), icon: Icon(consentGranted == 'granted' ? Icons.lock_open_rounded : Icons.lock_outline_rounded), label: Text(consentGranted == 'granted' ? 'لغو مجوز نمایشی' : 'اعطای مجوز نمایشی')),
        if(consentGranted != null) Text(consentGranted == 'granted' ? 'مجوز نمایشی فعال شد.' : 'مجوز نمایشی لغو شد.', style: const TextStyle(color: muted, fontSize: 11)),
      ])),
    ]);
    }
    if (tab == 2) {
      return _wrap([
      _heading('پزشک من', 'اطلاعات عمومی پزشک و تجربه دریافت خدمات'),
      _card(child: Column(children: [
        const CircleAvatar(radius: 34, backgroundColor: Color(0xFFE3F3F8), child: Icon(Icons.person_rounded, size: 38, color: navy)),
        const SizedBox(height: 10), const Text('دکتر نمونه', style: TextStyle(fontWeight: FontWeight.w900, color: navy, fontSize: 17)),
        const Text('تخصص نمونه • پروفایل نمایشی', style: TextStyle(color: muted, fontSize: 11)),
        const SizedBox(height: 8), const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.star_rounded, color: Color(0xFFE6A23C)), Text('۴٫۸  •  ۱۲ ارزیابی نمونه', style: TextStyle(fontWeight: FontWeight.w700))]),
        const SizedBox(height: 12), FilledButton.icon(onPressed: () => _toast('امتیازدهی فقط پس از مراجعه تأییدشده فعال می‌شود.'), icon: const Icon(Icons.star_rate_rounded), label: const Text('ارزیابی تجربه مراجعه')),
      ])),
      const SizedBox(height: 12), _banner('امتیازدهی عمومی در نسخه واقعی فقط برای مراجعه تأییدشده مجاز است؛ اطلاعات پزشکی شما هرگز در نظر عمومی نمایش داده نمی‌شود.', Icons.verified_user_rounded, const Color(0xFFEAF6F2), const Color(0xFF27745F)),
    ]);
    }
    if (tab == 3) {
      return _wrap([
      _heading('پیام به پزشک', 'برای پرسش‌های غیر اورژانسی درباره روند درمان'),
      _card(child: Column(children: [
        const Align(alignment: Alignment.centerRight, child: Text('گفت‌وگوی نمونه با پزشک معالج', style: TextStyle(fontWeight: FontWeight.w800, color: navy))),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerRight, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEAF6F2), borderRadius: BorderRadius.circular(14)), child: const Text('سلام، وضعیت پیگیری درمان شما چگونه است؟'))),
        const SizedBox(height: 14), TextField(controller: messageController, maxLines: 3, decoration: const InputDecoration(hintText: 'پیام خود را بنویسید...')),
        const SizedBox(height: 10), Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: () { if(messageController.text.trim().isEmpty)return; messageController.clear(); _toast('پیام نمایشی ثبت شد.'); }, icon: const Icon(Icons.send_rounded), label: const Text('ارسال پیام'))),
      ])),
      const SizedBox(height: 12), _banner('این محیط پیام‌رسانی آزمایشی است و برای موارد اورژانسی طراحی نشده است.', Icons.info_outline_rounded, const Color(0xFFFFF5E6), const Color(0xFF94631A)),
    ]);
    }
    return _wrap([
      _heading('سلام، خوش آمدید', 'سلامت شما؛ در یک نگاه'),
      _card(child: Row(children: [
        const CircleAvatar(radius: 26, backgroundColor: Color(0xFFE7F5F0), child: Icon(Icons.favorite_rounded, color: teal, size: 27)),
        const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('پرونده سلامت شما', style: TextStyle(fontWeight: FontWeight.w900, color: navy)), SizedBox(height: 4), Text('آخرین به‌روزرسانی: نمونه', style: TextStyle(color: muted, fontSize: 11))])),
        const Icon(Icons.verified_user_rounded, color: teal),
      ])),
      const SizedBox(height: 14),
      Row(children: [_stat('نسخه فعال', '۰۱', Icons.medication_rounded, const Color(0xFFE7F5F0)), const SizedBox(width: 10), _stat('نتیجه جدید', '۰۲', Icons.science_rounded, const Color(0xFFE3F3F8))]),
      _section('دسترسی سریع'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _action('قند خون و آزمایش', Icons.bloodtype_rounded, () => setState(() => tab = 4)),
        _action('پرونده من', Icons.folder_shared_rounded, () => setState(() => tab = 1)),
        _action('پزشک من', Icons.medical_services_rounded, () => setState(() => tab = 2)),
        _action('پیام‌ها', Icons.chat_rounded, () => setState(() => tab = 3)),
      ]),
      _section('آخرین فعالیت‌ها'),
      _card(child: Column(children: [
        _rowItem(Icons.science_rounded, 'گزارش آزمایش نمونه', 'برای مشاهده در پرونده شما', color: teal),
        const Divider(height: 1), _rowItem(Icons.receipt_long_rounded, 'نسخه جدید', 'در انتظار بررسی داروخانه', color: const Color(0xFFB7791F)),
      ])),
    ]);
  }

  Widget _pharmacyPage() {
    if (tab == 1) {
      return _wrap([
      _heading('نسخه‌های دریافتی', 'نسخه‌های ارجاع‌شده به داروخانه'),
      TextField(controller: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'کد نسخه یا شناسه تست')),
      const SizedBox(height: 12),
      _card(child: Column(children: [
        _rowItem(Icons.receipt_long_rounded, 'نسخه #RX-TEST-024', '۳ قلم • در انتظار بررسی', color: const Color(0xFFB7791F), trailing: const Icon(Icons.chevron_left_rounded)),
        const Divider(height: 1), _rowItem(Icons.receipt_long_rounded, 'نسخه #RX-TEST-023', '۲ قلم • تحویل ناقص', color: teal, trailing: const Icon(Icons.chevron_left_rounded)),
      ])),
    ]);
    }
    if (tab == 2) {
      return _wrap([
      _heading('موجودی داروخانه', 'مدیریت موجودی و اعلام کمبود'),
      TextField(controller: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'جستجوی دارو')),
      const SizedBox(height: 12),
      _card(child: Column(children: [
        _rowItem(Icons.medication_rounded, 'فرآورده آزمایشی A', 'موجودی: ۲۴ بسته', color: teal, trailing: const Chip(label: Text('موجود'))),
        const Divider(height: 1), _rowItem(Icons.medication_rounded, 'فرآورده آزمایشی B', 'موجودی: ۰ بسته', color: const Color(0xFFC65B52), trailing: const Chip(label: Text('ناموجود'))),
      ])),
    ]);
    }
    if (tab == 3) {
      return _wrap([
      _heading('تحویل دارو', 'ثبت وضعیت هر قلم نسخه'),
      _card(child: Column(children: [
        _rowItem(Icons.medication_rounded, 'فرآورده آزمایشی A', 'نسخه #RX-TEST-024 • تعداد ۱', color: teal),
        Wrap(spacing: 8, children: [
          OutlinedButton(onPressed: () => _toast('تحویل کامل (نمایشی) ثبت شد.'), child: const Text('تحویل شد')),
          OutlinedButton(onPressed: () => _toast('ناموجودی به بیمار اعلام شد (نمایشی).'), child: const Text('ناموجود')),
        ]),
        const Divider(height: 24),
        _rowItem(Icons.medication_rounded, 'فرآورده آزمایشی B', 'نسخه #RX-TEST-024 • تعداد ۱', color: const Color(0xFFC65B52)),
        FilledButton.tonalIcon(onPressed: () => _toast('اعلان کمبود برای بیمار ثبت شد (نمایشی).'), icon: const Icon(Icons.notifications_active_rounded), label: const Text('اعلام ناموجودی به بیمار')),
      ])),
    ]);
    }
    return _wrap([
      _heading('داشبورد داروخانه', 'مدیریت نسخه و تأمین دارو'),
      Row(children: [_stat('نسخه ورودی', '۱۸', Icons.receipt_long_rounded, const Color(0xFFE3F3F8)), const SizedBox(width: 10), _stat('کمبود موجودی', '۰۳', Icons.warning_amber_rounded, const Color(0xFFFFF2E5))]),
      _section('عملیات سریع'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _action('نسخه‌های ورودی', Icons.inbox_rounded, () => setState(() => tab = 1)),
        _action('مدیریت موجودی', Icons.inventory_2_rounded, () => setState(() => tab = 2)),
        _action('تحویل دارو', Icons.local_shipping_rounded, () => setState(() => tab = 3)),
      ]),
      _section('نیازمند اقدام'),
      _card(child: Column(children: [
        _rowItem(Icons.error_outline_rounded, 'دو قلم در انتظار تعیین موجودی', 'نسخه‌های ارجاعی امروز', color: const Color(0xFFB7791F)),
        const Divider(height: 1), _rowItem(Icons.check_circle_outline_rounded, 'تحویل‌های ثبت‌شده', '۱۶ تحویل در نمونه امروز', color: teal),
      ])),
    ]);
  }

  Widget _insurancePage() {
    if (tab == 1) {
      return _wrap([
      _heading('گزارش‌های آماری', 'گزارش‌های تجمیعی و فاقد اطلاعات هویتی'),
      _card(child: Column(children: [
        _rowItem(Icons.calendar_month_rounded, 'گزارش ماهانه', 'تعداد نسخه‌ها و اقلام تحویلی'),
        const Divider(height: 1), _rowItem(Icons.local_pharmacy_rounded, 'گزارش داروخانه‌ها', 'شاخص‌های تجمیعی خدمات'),
        const Divider(height: 1), _rowItem(Icons.payments_rounded, 'گزارش مالی', 'مبالغ فرضی و سهم‌های ثبت‌شده'),
      ])),
      const SizedBox(height: 12), _banner('گزارش‌ها در این نسخه ساختگی‌اند. دسترسی بیمه به پرونده تفصیلی یا محرمانه بیمار وجود ندارد.', Icons.lock_outline_rounded, const Color(0xFFEAF3F8), navy),
    ]);
    }
    if (tab == 2) {
      return _wrap([
      _heading('خدمات تحت پوشش', 'نمایش ساختار نمونه خدمات بیمه'),
      _card(child: Column(children: [
        _rowItem(Icons.medication_rounded, 'داروهای مشمول', 'کاتالوگ و قواعد پوشش باید از منبع مجاز دریافت شود'),
        const Divider(height: 1), _rowItem(Icons.science_rounded, 'آزمایش و تصویربرداری', 'تعرفه و پوشش نیازمند اتصال رسمی'),
      ])),
    ]);
    }
    if (tab == 3) {
      return _wrap([
      _heading('حساب کاربری', 'نقش سازمانی و تنظیمات دسترسی'),
      _card(child: Column(children: [
        _rowItem(Icons.business_rounded, 'سازمان بیمه نمونه', 'حساب آزمایشی'),
        const Divider(height: 1), _rowItem(Icons.security_rounded, 'سطح دسترسی', 'گزارش‌های تجمیعی مجاز'),
      ])),
    ]);
    }
    return _wrap([
      _heading('داشبورد بیمه', 'نمای کلی عملکرد در سطح تجمیعی'),
      Row(children: [_stat('نسخه‌های نمونه', '۱٬۲۸۰', Icons.receipt_long_rounded, const Color(0xFFE3F3F8)), const SizedBox(width: 10), _stat('داروخانه‌ها', '۴۸', Icons.local_pharmacy_rounded, const Color(0xFFE7F5F0))]),
      _section('شاخص‌های مالی نمایشی'),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('سهم فرضی بیمه در دوره نمونه', style: TextStyle(color: muted, fontSize: 11)),
        const SizedBox(height: 8), const Text('۱۲٫۴ میلیارد ریال', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: navy)),
        const SizedBox(height: 12), ClipRRect(borderRadius: BorderRadius.circular(8), child: const LinearProgressIndicator(value: .72, minHeight: 9, backgroundColor: Color(0xFFEAF0F3), color: teal)),
        const SizedBox(height: 7), const Text('۷۲٪ از هدف نمایشی', style: TextStyle(color: muted, fontSize: 10)),
      ])),
      _section('دسترسی سریع'),
      _action('مشاهده گزارش‌ها', Icons.analytics_rounded, () => setState(() => tab = 1)),
      const SizedBox(height: 14), _banner('مسئول بیمه فقط گزارش‌های مجاز و تجمیعی را مشاهده می‌کند و به اطلاعات محرمانه فردی دسترسی ندارد.', Icons.shield_rounded, const Color(0xFFEAF6F2), const Color(0xFF27745F)),
    ]);
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem(this.label, this.icon);
}
