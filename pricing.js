"use strict";
/* Demo-only estimate. No official pricing or insurance adjudication. */
(() => {
 const byId=id=>document.getElementById(id);
 const form=byId("priceForm");
 if(!form) return;
 const output=byId("priceResults");
 const money=n=>n.toLocaleString("fa-IR")+" ریال";
 function reset(){output.hidden=true;output.replaceChildren();}
 function parseAmount(id,optional=false){
   const raw=byId(id).value.trim();
   if(raw===""&&optional) return null;
   if(!/^(0|[1-9][0-9]*)$/.test(raw)) throw Error("مقدار «"+id+"» باید عدد صحیح نامنفی با ارقام انگلیسی باشد.");
   const n=Number(raw);
   if(!Number.isSafeInteger(n))throw Error("مقدار از محدوده عددی ایمن خارج است.");
   return n;
 }
 function safeMul(a,b){const n=a*b;if(!Number.isSafeInteger(n))throw Error("حاصل محاسبه از محدوده عددی ایمن خارج است.");return n;}
 function line(title,val){const row=document.createElement("div");row.className="price-row";const key=document.createElement("span");key.textContent=title;const value=document.createElement("strong");value.textContent=val;row.append(key,value);output.append(row);}
 for(const el of form.elements){el.addEventListener("input",reset);el.addEventListener("change",reset);}
 form.addEventListener("reset",()=>setTimeout(reset,0));
 form.addEventListener("submit",ev=>{
  ev.preventDefault();reset();
  try{
   if(!form.reportValidity())return;
   const product=byId("priceProduct").value.trim(), name=byId("priceName").value.trim();
   if(!product||!name)throw Error("شناسه و نام فرآورده الزامی‌اند.");
   if(!/^TEST[-_]/i.test(product))throw Error("در محیط آزمایشی شناسه فرآورده باید با TEST- یا TEST_ آغاز شود.");
   if(!byId("priceConsent").checked)throw Error("تأیید محیط آزمایشی الزامی است.");
   const qty=parseAmount("priceQuantity"),unit=parseAmount("priceUnit"),purchase=parseAmount("purchaseUnit",true),insurance=parseAmount("insuranceAmount");
   if(qty<=0)throw Error("تعداد باید مثبت باشد.");
   if(!byId("priceDate").value)throw Error("تاریخ بررسی قیمت لازم است.");
   if(byId("priceSource").value==="manual"&&!byId("priceReason").value.trim()) throw Error("قیمت دستی نیازمند ثبت دلیل است.");
   const gross=safeMul(qty,unit);
   if(insurance>gross)throw Error("سهم بیمه نمی‌تواند از مبلغ کل بیشتر باشد.");
   const cost=purchase===null?null:safeMul(qty,purchase);
   output.hidden=false;
   line("فرآورده آزمایشی",name+" — "+product);
   line("مبلغ کل قبل از سهم بیمه (فرضی)",money(gross));
   line("سهم بیمه ورودی (تأییدنشده)",money(insurance));
   line("مانده پس از کسر سهم ورودی",money(gross-insurance));
   if(cost!==null)line("بهای خرید واردشده (فرضی)",money(cost));
   line("وضعیت منبع","آزمایشی؛ فاقد استعلام رسمی");
   line("تاریخ ثبت منبع",byId("priceDate").value);
  }catch(e){output.hidden=false;const p=document.createElement("p");p.setAttribute("role","alert");p.textContent=e.message;output.append(p);}
 });
})();