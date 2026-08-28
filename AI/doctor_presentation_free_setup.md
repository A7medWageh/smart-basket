# 🎓 خطة رفع المشروع مجاناً 100% على Vercel (بدون فيزا نهائياً)

موقع **Vercel** من أفضل المنصات العالمية لاستضافة تطبيقات Node.js و Express، وهو **مجاني 100% ولا يطلب فيزا أو وسائل دفع نهائياً** للتسجيل أو الاستخدام.

---

## 🚀 خطوة بخطوة: رفع الباك إند على Vercel

### 1️⃣ الخطوة الأولى: إنشاء ملف `vercel.json`
- قم بإضافة ملف باسم `vercel.json` داخل مجلد `backend` في ريبو `Oxeldif/Scan-go` وضع فيه الكود التالي:

```json
{
  "version": 2,
  "builds": [
    {
      "src": "src/app.ts",
      "use": "@vercel/node"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "src/app.ts"
    }
  ]
}
```
*(الملف مجهز وجاهز للنسخ في [AI/vercel.json](file:///c:/Users/user/Desktop/Smart-Basket-main/AI/vercel.json))*

---

### 2️⃣ الخطوة الثانية: التسجيل في Vercel بحساب جيت هاب
1. ادخل على [Vercel.com](https://vercel.com).
2. اضغط على **Sign Up**.
3. اختر **Continue with GitHub**.
*(لن يطلب منك أي بطاقة فيزا أو تفعيل دفع)*.

---

### 3️⃣ الخطوة الثالثة: استيراد مشروع الباك إند (Deploying Project)
1. من لوحة التحكم في Vercel اضغط على زر **Add New...** ثم **Project**.
2. ابحث عن ريبو مشروعك: `Oxeldif/Scan-go` واضغط **Import**.
3. في خانة **Root Directory** اختر مجلد `backend`.
4. في خانة **Environment Variables** اضف متغيّرات قاعدة البيانات إن وجدت مثل `DATABASE_URL`.
5. اضغط على زر **Deploy**.

---

### 4️⃣ الخطوة الرابعة: الحصول على الرابط المجاني
- خلال 30 ثانية فقط، سيعطيك Vercel رابطاً مجانياً ودائماً مثل:
  `https://scan-go-backend.vercel.app`

---

### 5️⃣ الخطوة الأخيرة: ربط الذكاء الاصطناعي مع Vercel
في ملف [esp32_ai_production_engine.py](file:///c:/Users/user/Desktop/Smart-Basket-main/AI/esp32_ai_production_engine.py)، قم بتعديل السطر الخاص بالرابط ليكون:

```python
AI_WEBHOOK_URL = "https://scan-go-backend.vercel.app/api/ai/detection"
```

وبذلك يصبح المشروع كاملاً مرفوعاً ومربوطاً على خوادم Vercel المجانية 24/7 دون الحاجة لأي بطاقة فيزا أو فتح لابتوبات أثناء العرض أمام الدكتور! 🚀
