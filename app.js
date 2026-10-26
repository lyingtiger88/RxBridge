/* RxBridge v0.1 demo: fabricated data only. Not clinical software. */
"use strict";
const $ = id => document.getElementById(id);
const ROUTES = {
 tablet:[["oral","خوراکی"],["sublingual","زیرزبانی"],["other","سایر / سفارشی"]],
 capsule:[["oral","خوراکی"],["other","سایر / سفارشی"]],
 syrup:[["oral","خوراکی"],["other","سایر / سفارشی"]],
 injectable:[["im","عضلانی"],["iv","وریدی"],["sc","زیرجلدی"],["other","سایر / سفارشی"]],
 suppository:[["rectal","مقعدی"],["vaginal","واژینال"],["other","سایر / سفارشی"]],
 topical:[["skin","موضعی پوست"],["other","سایر / سفارشی"]],
 drop:[["eye","چشمی"],["ear","گوشی"],["nose","بینی"],["oral","خوراکی"],["other","سایر / سفارشی"]],
 inhaler:[["inhaled","استنشاقی"],["other","سایر / سفارشی"]],
 other:[["other","سایر / سفارشی"]]
};
const fields = ["form","route","unit","frequency"];
const display = {form:"شکل دارویی",route:"مسیر مصرف",unit:"واحد مقدار",frequency:"برنامه نوبت مصرف"};
let items = [], events = [], phase = "DRAFT", pending = null;
function optionText(select){ return select.selectedOptions[0]?.textContent || ""; }
function updateRoutes() {
 const previous = $("route").value;
 $("route").replaceChildren();
 for(const [v,title] of ROUTES[$("form").value]) {
   const op = document.createElement("option"); op.value = v; op.textContent = title; $("route").append(op);
 }
 if(ROUTES[$("form").value].some(([v])=>v===previous)) $("route").value = previous;
 customInputs();
}
function customInputs() {
 const root = $("customFields"); root.replaceChildren();
 for(const id of fields){
   if($(id).value !== "other") continue;
   const wrap = document.createElement("div"); wrap.className = "grid";
   const l1 = document.createElement("label"); l1.textContent = display[id] + " سفارشی";
   const input = document.createElement("input"); input.id = "custom_"+id; input.required = true; input.maxLength=200; input.placeholder="مقدار را دقیق و خوانا وارد کنید"; l1.append(input);
   const l2=document.createElement("label"); l2.textContent="علت استفاده از مقدار سفارشی";
   const why=document.createElement("input"); why.id="reason_"+id; why.required=true; why.maxLength=300; why.placeholder="دلیل انتخاب را ذکر کنید"; l2.append(why);
   wrap.append(l1,l2);root.append(wrap);
 }
}
function capture() {
 const drug=$("drug").value.trim(),patient=$("patient").value.trim(),amount=Number($("amount").value),days=Number($("days").value),notes=$("instructions").value.trim();
 if(!drug||!patient||!/^بیمار آزمایشی|^TEST-/i.test(patient)) throw Error("فقط بیمار ساختگی (با نام «بیمار آزمایشی» یا TEST-) مجاز است.");
 if(!$("amount").value||!Number.isFinite(amount)||amount<=0||!$("days").value||!Number.isSafeInteger(days)||days<=0||days>3650) throw Error("مقدار هر نوبت و مدت را به صورت عدد مثبت معتبر وارد کنید.");
 const data={drug,patient,amount,days,notes, values:{}, custom:[]};
 for(const id of fields){
   const sel=$(id); const val=sel.value;
   if(val==="other"){
     const entered=$("custom_"+id)?.value.trim()||"";
     const reason=$("reason_"+id)?.value.trim()||"";
     if(!entered||!reason)throw Error("برای "+display[id]+" سفارشی، مقدار و دلیل را وارد کنید.");
     data.values[id]=entered;data.custom.push({field:id,value:entered,reason});
   }else data.values[id]=optionText(sel);
 }
 if($("frequency").value==="prn"&&!notes)throw Error("برای مصرف در صورت نیاز، دستور دقیق و حدود مصرف الزامی است.");
 if(($("form").value==="injectable"||$("route").value==="other")&&!notes) throw Error("برای تجویز تزریقی یا مسیر سفارشی، دستور دقیق تکمیلی الزامی است.");
 return data;
}
function log(message){events.unshift(new Date().toLocaleString("fa-IR")+": "+message);render();}
function render(){
 $("status").textContent=({DRAFT:"پیش‌نویس",SIGNED:"تأیید پزشک (نمایشی)",REVIEWED:"بررسی داروساز (نمایشی)",DISPENSED:"تحویل نمایشی"})[phase];
 const root=$("items");root.replaceChildren();
 if(!items.length){const p=document.createElement("p");p.className="muted";p.textContent="هنوز قلمی اضافه نشده است.";root.append(p);}
 items.forEach((d,i)=>{const e=document.createElement("div");e.className="item";
   const title=document.createElement("strong");title.textContent=(i+1)+". "+d.drug;
   const description=document.createElement("small");description.textContent=d.values.form+" | "+d.values.route+" | "+d.amount+" "+d.values.unit+" | "+d.values.frequency+" | "+d.days+" روز"+(d.notes?" | "+d.notes:"");
   e.append(title,description);
   if(d.custom.length){const warn=document.createElement("small");warn.textContent="مقدار سفارشی: ورود عمدی تأیید شد؛ فاقد تأیید بالینی";e.append(warn);}
   if(phase==="DRAFT"){const btn=document.createElement("button");btn.textContent="حذف قلم";btn.addEventListener("click",()=>{items.splice(i,1);log("قلم پیش‌نویس حذف شد");});e.append(btn);}
   root.append(e);
 });
 $("audit").replaceChildren();
 events.forEach(x=>{const li=document.createElement("li");li.textContent=x;$("audit").append(li);});
 $("sign").disabled=phase!=="DRAFT"||!items.length;
 $("review").disabled=phase!=="SIGNED";
 $("dispense").disabled=phase!=="REVIEWED";
}
function addItem(data){items.push(data);log("یک قلم آزمایشی به پیش‌نویس افزوده شد");$("drug").value="";$("amount").value="";$("days").value="";$("instructions").value="";fields.forEach(x=>{if($(x).value==="other")$(x).selectedIndex=0;});updateRoutes();}
$("form").addEventListener("change",updateRoutes);
for(const id of ["route","unit","frequency"])$(id).addEventListener("change",customInputs);
$("rxForm").addEventListener("submit",e=>{
 e.preventDefault();if(phase!=="DRAFT"){alert("این نسخه دیگر در وضعیت پیش‌نویس نیست.");return;}
 try{const data=capture();
  if(data.custom.length){
    pending=data;const lines=data.custom.map(x=>display[x.field]+": "+x.value+"\nعلت: "+x.reason).join("\n\n");
    $("modalText").textContent=lines; $("confirmCheck").checked=false;$("confirm").disabled=true;$("modal").classList.remove("hidden");$("confirm").focus();
  }else addItem(data);
 }catch(err){alert(err.message);}
});
$("confirmCheck").addEventListener("change",()=>{$("confirm").disabled=!$("confirmCheck").checked;});
$("cancel").addEventListener("click",()=>{pending=null;$("modal").classList.add("hidden");});
$("confirm").addEventListener("click",()=>{
 if(!pending||!$("confirmCheck").checked)return;
 try {
   const current=capture();
   if(JSON.stringify(current)!==JSON.stringify(pending)) throw Error("اطلاعات فرم تغییر کرده‌اند. ابتدا مجدداً بررسی و تأیید کنید.");
   addItem(pending);pending=null;$("modal").classList.add("hidden");
 }catch(err){pending=null;$("modal").classList.add("hidden");alert(err.message);}
});
$("reset").addEventListener("click",()=>{$("rxForm").reset();updateRoutes();});
$("sign").addEventListener("click",()=>{if(phase!=="DRAFT"||!items.length)return;phase="SIGNED";log("تأیید پزشک شبیه‌سازی شد (فاقد امضای واقعی)");});
$("review").addEventListener("click",()=>{if(phase!=="SIGNED")return;phase="REVIEWED";log("بررسی داروساز شبیه‌سازی شد (فاقد اعتبار بالینی)");});
$("dispense").addEventListener("click",()=>{if(phase!=="REVIEWED")return;phase="DISPENSED";log("تحویل دارو صرفاً شبیه‌سازی و ثبت شد");});
$("newRx").addEventListener("click",()=>{if(!confirm("تمام اقلام و رویدادهای نمایشی این جلسه پاک شوند؟"))return;items=[];events=[];phase="DRAFT";$("rxForm").reset();updateRoutes();render();});
function calc(){let d=Number($("calcDose").value),c=Number($("calcConc").value);
 $("calcResult").textContent=(!$("calcDose").value||!$("calcConc").value||!Number.isFinite(d)||!Number.isFinite(c)||d<=0||c<=0)?"—":(d*5/c).toLocaleString("fa-IR",{maximumFractionDigits:3})+" mL";
}
$("calcDose").addEventListener("input",calc);$("calcConc").addEventListener("input",calc);
updateRoutes();render();
