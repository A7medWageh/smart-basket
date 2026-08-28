# 🤖 دليل رفع الذكاء الاصطناعي مجاناً 100% على Hugging Face Spaces

يقدم موقع **Hugging Face Spaces** استضافة سحابية مجانية 100% لسيرفرات الذكاء الاصطناعي (Python + Docker) بدون الحاجة لأي فيزا وبدون أي قيود، لتشغيل الموديل 24/7 أونلاين على النت!

---

## 🚀 خطوات الرفع خطوة بخطوة (تستغرق دقيقتين فقط):

### 1️⃣ الخطوة الأولى: إنشاء حساب مجاني
1. ادخل على [HuggingFace.co](https://huggingface.co/join) وسجل حساباً مجانياً.

### 2️⃣ الخطوة الثانية: إنشاء Space جديدة
1. اضغط على صورة حسابك أعلى اليمين واختر **New Space** (أو ادخل على [huggingface.co/new-space](https://huggingface.co/new-space)).
2. اكتب اسم الـ Space مثلاً: `smart-basket-ai`
3. في خيار **Space SDK**: اختر **Docker** (ثم اختر Blank Docker).
4. اترك الخيار **Public** كما هو واضغط **Create Space**.

---

### 3️⃣ الخطوة الثالثة: رفع الملفات (Drag & Drop)
داخل صفحة الـ Space الجديدة التي أنشأتها:
1. اضغط على تبويب **Files and versions** أعلى الصفحة.
2. اضغط على **Add file** -> **Upload files**.
3. قم بسحب وإسقاط الملفات التالية الموجودة داخل المجلد [Scan-go-main/ai_vision](file:///c:/Users/user/Desktop/Smart-Basket-main/Scan-go-main/ai_vision):
   - `Dockerfile`
   - `requirements.txt`
   - `app.py`
   - `classes.txt`
   - `best_int8.onnx`
4. اضغط **Commit changes to main**.

---

## 🎯 النتيجة الفورية:
- يبدأ Hugging Face فوراً في بناء وتشغيل السيرفر تلقائياً (`Building` -> `Running`).
- ستحصل على رابط سحابي حي وشغال 24/7 لسيرفر الذكاء الاصطناعي مثل:
  `https://your-username-smart-basket-ai.hf.space/predict`
- كاميرا ESP32 في السلة ستقوم بإرسال الصور لهذا الرابط المباشر، والذكاء الاصطناعي سيتعرف على `v7_can` و `big_chips` ويرسل النتيجة لـ Vercel والموبايل فوراُ بدون أي لابتوب! 🚀
