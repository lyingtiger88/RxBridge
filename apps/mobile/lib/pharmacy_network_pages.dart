import 'package:flutter/material.dart';

const _phInk=Color(0xFF183247), _phNavy=Color(0xFF102A43), _phTeal=Color(0xFF16A6A1), _phMuted=Color(0xFF6C8293), _phLine=Color(0xFFE6EEF2);

class PharmacyNetworkWorkspace extends StatefulWidget {
  const PharmacyNetworkWorkspace({super.key});
  @override State<PharmacyNetworkWorkspace> createState()=>_PharmacyNetworkWorkspaceState();
}
class _PharmacyNetworkWorkspaceState extends State<PharmacyNetworkWorkspace> {
  int tab=0; bool published=false;
  final name=TextEditingController(text:'داروخانه مهر');
  final address=TextEditingController(text:'زنجان، خیابان اصلی، پلاک ۱۲');
  final search=TextEditingController();
  final stock=<List<dynamic>>[
    ['استامینوفن ۵۰۰','قرص • بسته ۲۰ عددی',42,380000],
    ['ایبوپروفن ۴۰۰','قرص • بسته ۲۰ عددی',18,520000],
    ['شربت دیفن‌هیدرامین','شربت • ۱۲۰ میلی‌لیتر',0,690000],
    ['سرم شست‌وشو','محلول • ۵۰۰ میلی‌لیتر',12,850000],
  ];
  @override void dispose(){name.dispose();address.dispose();search.dispose();super.dispose();}
  void notice(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:const LinearGradient(colors:[_phNavy,Color(0xFF176B78)]),borderRadius:BorderRadius.circular(22)),child:Row(children:[
      const CircleAvatar(backgroundColor:Color(0x33FFFFFF),child:Icon(Icons.local_pharmacy_rounded,color:Colors.white)),
      const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('پنل داروخانه',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:19)),
        Text(name.text,style:const TextStyle(color:Colors.white70,fontSize:12)),
      ])),
      Text(published?'منتشرشده':'پیش‌نویس',style:const TextStyle(color:Colors.white,fontSize:10)),
    ])),
    const SizedBox(height:13),
    Row(children:[_tab('نمای کلی',0),const SizedBox(width:6),_tab('موجودی و قیمت',1),const SizedBox(width:6),_tab('پروفایل',2)]),
    const SizedBox(height:14),
    if(tab==0)_overview() else if(tab==1)_inventory() else _profile(),
  ]));
  Widget _tab(String s,int i)=>Expanded(child:InkWell(onTap:()=>setState(()=>tab=i),child:Container(padding:const EdgeInsets.symmetric(vertical:12),decoration:BoxDecoration(color:tab==i?_phTeal.withValues(alpha:.1):Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:tab==i?_phTeal:_phLine)),child:Text(s,textAlign:TextAlign.center,style:TextStyle(fontSize:11,fontWeight:FontWeight.w800,color:tab==i?_phTeal:_phMuted)))));
  Widget _box(String title,List<Widget> children)=>Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:_phLine),borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w900,color:_phInk,fontSize:14)),const SizedBox(height:10),...children]));
  Widget _overview()=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    const Text('وضعیت امروز',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900,color:_phInk)),const SizedBox(height:10),
    Row(children:[
      _metric('اقلام فهرست‌شده',stock.length.toString(),Icons.medication_outlined),
      const SizedBox(width:7),_metric('موجود',stock.where((x)=>x[2]>0).length.toString(),Icons.inventory_2_outlined),
      const SizedBox(width:7),_metric('ناموجود',stock.where((x)=>x[2]==0).length.toString(),Icons.remove_shopping_cart_outlined),
    ]),
    const SizedBox(height:12),
    _box('چک‌لیست انتشار داروخانه',[
      _check('اطلاعات و نشانی داروخانه',true),_check('موقعیت جغرافیایی تأییدشده',false),_check('فهرست قیمت و موجودی',true),_check('تأیید مجوز داروخانه',false),
      const SizedBox(height:6),const Text('تا تکمیل و بررسی اطلاعات، داروخانه در جست‌وجوی بیماران نمایش داده نمی‌شود.',style:TextStyle(color:_phMuted,fontSize:11)),
    ]),
    const SizedBox(height:12),
    _box('آخرین فعالیت‌ها',[
      _activity(Icons.price_change_outlined,'به‌روزرسانی قیمت استامینوفن','امروز • ۰۹:۴۰'),
      _activity(Icons.inventory_outlined,'ثبت موجودی سرم شست‌وشو','دیروز • ۱۷:۱۵'),
      _activity(Icons.location_on_outlined,'موقعیت مکانی در انتظار تأیید','نیازمند اقدام'),
    ]),
    const SizedBox(height:12),FilledButton.icon(onPressed:()=>setState(()=>tab=1),icon:const Icon(Icons.edit_note),label:const Text('مدیریت موجودی و قیمت‌ها')),
  ]);
  Widget _metric(String label,String value,IconData icon)=>Expanded(child:Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:_phLine)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:_phTeal),const SizedBox(height:8),Text(value,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:_phInk)),Text(label,style:const TextStyle(fontSize:9,color:_phMuted))])));
  Widget _check(String s,bool done)=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(children:[Icon(done?Icons.check_circle:Icons.radio_button_unchecked,color:done?_phTeal:_phMuted,size:18),const SizedBox(width:8),Expanded(child:Text(s,style:const TextStyle(fontSize:12,color:_phInk))),Text(done?'تکمیل':'باقی‌مانده',style:const TextStyle(fontSize:10,color:_phMuted))]));
  Widget _activity(IconData i,String s,String d)=>ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:Icon(i,color:_phTeal),title:Text(s,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),subtitle:Text(d,style:const TextStyle(fontSize:10,color:_phMuted)));
  Widget _inventory()=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Row(children:[const Expanded(child:Text('فهرست داروها',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900,color:_phInk))),FilledButton.tonalIcon(onPressed:_addItem,icon:const Icon(Icons.add,size:18),label:const Text('افزودن'))]),
    const SizedBox(height:10),TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'جست‌وجوی نام دارو')),
    const SizedBox(height:9),Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:const Color(0xFFEAF6F5),borderRadius:BorderRadius.circular(12)),child:const Text('قیمت‌ها به ریال ثبت می‌شوند. زمان آخرین به‌روزرسانی به بیمار نمایش داده خواهد شد.',style:TextStyle(fontSize:10,color:_phInk))),
    const SizedBox(height:8),
    for(final x in stock.where((x)=>(x[0] as String).contains(search.text))) _stockTile(x),
  ]);
  Widget _stockTile(List<dynamic> x)=>Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:_phLine),borderRadius:BorderRadius.circular(16)),child:Row(children:[
    const CircleAvatar(backgroundColor:Color(0xFFEAF6F5),child:Icon(Icons.medication,color:_phTeal)),const SizedBox(width:9),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(x[0],style:const TextStyle(fontWeight:FontWeight.w800,fontSize:12,color:_phInk)),Text(x[1],style:const TextStyle(fontSize:10,color:_phMuted)),Text((x[3].toString())+' ریال',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:12))])),
    Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(x[2]>0?'موجود':'ناموجود',style:TextStyle(color:x[2]>0?_phTeal:Colors.red,fontSize:10,fontWeight:FontWeight.bold)),Text('تعداد: '+x[2].toString(),style:const TextStyle(fontSize:10,color:_phMuted)),IconButton(onPressed:()=>_editItem(x),icon:const Icon(Icons.edit_outlined,size:18))]),
  ]));
  Future<void> _addItem()async{
    final n=TextEditingController(),d=TextEditingController(text:'قرص • بسته'),p=TextEditingController(),q=TextEditingController(text:'0');
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('افزودن قلم دارویی'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:n,decoration:const InputDecoration(labelText:'نام دقیق دارو')),TextField(controller:d,decoration:const InputDecoration(labelText:'شکل، قدرت و بسته‌بندی')),TextField(controller:p,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'قیمت (ریال)')),TextField(controller:q,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'موجودی'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت'))]));
    if(ok==true&&n.text.trim().isNotEmpty&&int.tryParse(p.text)!=null&&int.tryParse(q.text)!=null)setState(()=>stock.add([n.text.trim(),d.text.trim(),int.parse(q.text),int.parse(p.text)]));
    n.dispose();d.dispose();p.dispose();q.dispose();
    if(ok==true)notice('در فهرست نمایشی ثبت شد؛ هنوز به سرور ارسال نشده است.');
  }
  Future<void> _editItem(List<dynamic> x)async{
    final p=TextEditingController(text:x[3].toString()),q=TextEditingController(text:x[2].toString());
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('ویرایش '+x[0]),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:p,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'قیمت (ریال)')),TextField(controller:q,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'موجودی'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره'))]));
    if(ok==true&&int.tryParse(p.text)!=null&&int.tryParse(q.text)!=null)setState(() { x[2]=int.parse(q.text); x[3]=int.parse(p.text); });
    p.dispose();q.dispose();
  }
  Widget _profile()=>_box('مشخصات عمومی داروخانه',[
    TextField(controller:name,decoration:const InputDecoration(labelText:'نام داروخانه')),const SizedBox(height:9),
    TextField(controller:address,maxLines:2,decoration:const InputDecoration(labelText:'نشانی کامل')),const SizedBox(height:10),
    const Text('موقعیت جغرافیایی',style:TextStyle(fontWeight:FontWeight.w800,color:_phInk)),
    const SizedBox(height:8),Container(height:145,decoration:BoxDecoration(color:const Color(0xFFE6F0E8),borderRadius:BorderRadius.circular(14)),child:Stack(children:[Positioned.fill(child:CustomPaint(painter:_MapPainter())),const Center(child:Icon(Icons.location_on,color:Color(0xFFD65F55),size:36)),const Positioned(bottom:8,right:8,child:Text('مختصات نمایشی • نیازمند تأیید',style:TextStyle(fontSize:9,color:_phMuted)))])),
    OutlinedButton.icon(onPressed:()=>notice('اتصال نقشه و تأیید موقعیت در مرحله بعد انجام می‌شود.'),icon:const Icon(Icons.my_location),label:const Text('ثبت موقعیت روی نقشه')),
    SwitchListTile(contentPadding:EdgeInsets.zero,value:published,onChanged:(v)=>setState(()=>published=v),title:const Text('نمایش در جست‌وجوی بیماران',style:TextStyle(fontSize:12,fontWeight:FontWeight.bold)),subtitle:const Text('انتشار واقعی پس از تأیید هویت و موقعیت انجام می‌شود.',style:TextStyle(fontSize:10))),
    FilledButton(onPressed:()=>notice('پروفایل فقط در پیش‌نمایش ذخیره شد.'),child:const Text('ذخیره پیش‌نمایش پروفایل')),
  ]);
}

class PatientPharmacyFinder extends StatefulWidget {
  const PatientPharmacyFinder({super.key});
  @override State<PatientPharmacyFinder> createState()=>_PatientPharmacyFinderState();
}
class _PatientPharmacyFinderState extends State<PatientPharmacyFinder>{
  int sort=0;bool fullOnly=false;
  final results=<List<dynamic>>[
    ['داروخانه مهر','۱٫۲ کیلومتر',100,1840000,'۵ دقیقه پیش',1.2],
    ['داروخانه سلامت','۰٫۸ کیلومتر',70,1090000,'۱۲ دقیقه پیش',0.8],
    ['داروخانه مرکزی','۳ کیلومتر',100,1690000,'۸ دقیقه پیش',3.0],
    ['داروخانه شبانه‌روزی','۰٫۵ کیلومتر',40,620000,'۲ دقیقه پیش',0.5],
  ];
  @override Widget build(BuildContext context){
    final list=results.where((x)=>!fullOnly||x[2]==100).toList();
    if(sort==0)list.sort((a,b){final c=(b[2] as int).compareTo(a[2] as int);return c!=0?c:(a[3] as int).compareTo(b[3] as int);});
    if(sort==1)list.sort((a,b)=>(a[3] as int).compareTo(b[3] as int));
    if(sort==2)list.sort((a,b)=>(a[5] as double).compareTo(b[5] as double));
    return Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Text('پیدا کردن داروخانه',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:_phInk)),
      const Text('داروخانه‌های نزدیک با موجودی نسخه شما',style:TextStyle(fontSize:11,color:_phMuted)),
      const SizedBox(height:12),_prescription(),
      const SizedBox(height:12),_map(),
      const SizedBox(height:13),const Text('بهترین گزینه‌ها برای نسخه شما',style:TextStyle(fontSize:15,fontWeight:FontWeight.w900,color:_phInk)),
      Row(children:[Expanded(child:DropdownButtonFormField<int>(initialValue:sort,decoration:const InputDecoration(labelText:'مرتب‌سازی'),items:const [DropdownMenuItem(value:0,child:Text('پوشش و قیمت')),DropdownMenuItem(value:1,child:Text('اقتصادی‌ترین')),DropdownMenuItem(value:2,child:Text('نزدیک‌ترین'))],onChanged:(v)=>setState(()=>sort=v??0))),const SizedBox(width:8),FilterChip(label:const Text('فقط موجودی کامل',style:TextStyle(fontSize:10)),selected:fullOnly,onSelected:(v)=>setState(()=>fullOnly=v))]),
      const SizedBox(height:8),for(final p in list)_result(p),
      const Text('قیمت و موجودی اعلام‌شده توسط داروخانه است و تا تأیید نهایی ممکن است تغییر کند. جایگزینی دارو نیازمند رعایت ضوابط و تأیید لازم است.',style:TextStyle(fontSize:10,color:_phMuted,height:1.6)),
    ]));
  }
  Widget _prescription()=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:_phLine),borderRadius:BorderRadius.circular(17)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Row(children:[Icon(Icons.receipt_long,color:_phTeal),SizedBox(width:7),Text('نسخه انتخاب‌شده',style:TextStyle(fontWeight:FontWeight.w900,color:_phInk)),Spacer(),Text('۳ قلم',style:TextStyle(fontSize:10,color:_phMuted))]),
    for(final d in ['استامینوفن ۵۰۰','ایبوپروفن ۴۰۰','سرم شست‌وشو'])Padding(padding:const EdgeInsets.only(top:7),child:Row(children:[const Icon(Icons.check_circle_outline,size:15,color:_phTeal),const SizedBox(width:7),Text(d,style:const TextStyle(fontSize:11,color:_phInk))])),
    const SizedBox(height:5),const Text('اقلام نسخه فعال بیمار در نسخه متصل از سرور خوانده می‌شوند.',style:TextStyle(fontSize:10,color:_phMuted)),
  ]));
  Widget _map()=>Container(height:190,clipBehavior:Clip.antiAlias,decoration:BoxDecoration(color:const Color(0xFFE6F0E8),borderRadius:BorderRadius.circular(18),border:Border.all(color:_phLine)),child:Stack(children:[
    Positioned.fill(child:CustomPaint(painter:_MapPainter())),
    const Positioned(top:9,right:9,child:Chip(avatar:Icon(Icons.my_location,size:14,color:_phTeal),label:Text('محدوده جست‌وجو',style:TextStyle(fontSize:9)))),
    for(int i=0;i<4;i++)Positioned(left:[30.0,120.0,230.0,175.0][i],top:[70.0,112.0,48.0,145.0][i],child:Column(children:[Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(8)),child:Text(results[i][2].toString()+'٪',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:_phTeal))),const Icon(Icons.location_on,color:Color(0xFF177C83),size:26)])),
    const Positioned(left:140,top:78,child:Icon(Icons.person_pin_circle,size:34,color:Color(0xFF315B9A))),
    const Positioned(left:9,bottom:7,child:Text('نقشه نمایشی • سرویس نقشه واقعی بعداً متصل می‌شود',style:TextStyle(fontSize:8,color:_phMuted))),
  ]));
  Widget _result(List<dynamic> p)=>Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:p[2]==100?const Color(0xFFBCE5DA):_phLine),borderRadius:BorderRadius.circular(17)),child:Column(children:[
    Row(children:[const CircleAvatar(backgroundColor:Color(0xFFEAF6F5),child:Icon(Icons.local_pharmacy,color:_phTeal)),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p[0],style:const TextStyle(fontSize:12,fontWeight:FontWeight.w900,color:_phInk)),Text('فاصله '+p[1]+' • موجودی: '+p[4],style:const TextStyle(fontSize:9,color:_phMuted))])),Text(p[2].toString()+'٪',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900,color:_phTeal))]),
    const SizedBox(height:8),ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(value:(p[2] as int)/100,minHeight:7,backgroundColor:const Color(0xFFF0F3F5),color:_phTeal)),
    const SizedBox(height:8),Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p[2]==100?'هزینه کل نسخه':'جمع اقلام موجود',style:const TextStyle(fontSize:9,color:_phMuted)),Text(p[3].toString()+' ریال',style:const TextStyle(fontSize:14,fontWeight:FontWeight.w900,color:_phNavy))])),OutlinedButton(onPressed:()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('رزرو واقعی پس از اتصال به سرور فعال می‌شود.'))),child:const Text('جزئیات و رزرو'))]),
    if(p[2]<100)const Align(alignment:Alignment.centerRight,child:Text('قیمت فقط مربوط به اقلام موجود است.',style:TextStyle(fontSize:9,color:Color(0xFF9A6A2B)))),
  ]));
}
class _MapPainter extends CustomPainter{
  @override void paint(Canvas canvas,Size s){
    canvas.drawRect(Offset.zero&s,Paint()..color=const Color(0xFFDCE9DF));
    final blocks=Paint()..color=const Color(0xFFEAF0E8);
    for(int y=0;y<4;y++)for(int x=0;x<5;x++)canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x*s.width/4.8+4,y*s.height/3.8+3,s.width/7,s.height/7),const Radius.circular(6)),blocks);
    final road=Paint()..color=Colors.white..strokeWidth=11..style=PaintingStyle.stroke..strokeCap=StrokeCap.round;
    final a=Path()..moveTo(-8,s.height*.25)..cubicTo(s.width*.25,s.height*.43,s.width*.52,s.height*.1,s.width+8,s.height*.35);
    final b=Path()..moveTo(s.width*.18,-8)..cubicTo(s.width*.3,s.height*.35,s.width*.55,s.height*.65,s.width*.48,s.height+8);
    final c=Path()..moveTo(-8,s.height*.82)..lineTo(s.width+8,s.height*.68);
    canvas.drawPath(a,road);canvas.drawPath(b,road);canvas.drawPath(c,road);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width*.68,s.height*.05,s.width*.2,s.height*.18),const Radius.circular(10)),Paint()..color=const Color(0xFFC9DFC9));
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}
