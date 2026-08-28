# 🍓 دليل تشغيل الذكاء الاصطناعي تلقائياً على Raspberry Pi عند فتح السلة

هذا الدليل يشرح كيفية إعداد الراسبيري باي لتشغيل محرك الذكاء الاصطناعي تلقائياً (Auto-Start on Boot) فور توصيل الباوربنك وبدون الحاجة لفتح لابتوب أو كتابة أي أوامر يوم العرض.

---

## 📋 الخطوات العملية:

### 1️⃣ الخطوة الأولى: نقل الملفات إلى Raspberry Pi
قم بنقل المجلد `ai_vision` إلى الراسبيري باي في المسار التالـي:
`/home/pi/ai_vision/`

تأكد من وجود الملفات التالية داخل المجلد:
- `esp32_ai_production_engine.py`
- `best_int8.onnx`
- `classes.txt`

---

### 2️⃣ الخطوة الثانية: تثبيت المكتبات (تُنفذ مرة واحدة فقط)
افتح الـ Terminal في الراسبيري باي وشغّل الأمر التالـي:

```bash
pip install opencv-python onnxruntime requests numpy
```

---

### 3️⃣ الخطوة الثالثة: إنشاء خدمة التشغيل التلقائي (systemd)
افتح التيرمنال وشغّل الأمر لإنشاء ملف الخدمة:

```bash
sudo nano /etc/systemd/system/smart_basket.service
```

ضع الكود التالي داخل الملف:

```ini
[Unit]
Description=Smart Basket AI Vision Engine
After=network.target

[Service]
ExecStart=/usr/bin/python3 /home/pi/ai_vision/esp32_ai_production_engine.py
WorkingDirectory=/home/pi/ai_vision
StandardOutput=inherit
StandardError=inherit
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
```

اضغط `Ctrl + O` ثم `Enter` للحفظ، ثم `Ctrl + X` للخروج.

---

### 4️⃣ الخطوة الرابعة: تفعيل وتجربة الخدمة
شغّل الأوامر التالية لتفعيل الخدمة تلقائياً عند الإقلاع:

```bash
sudo systemctl daemon-reload
sudo systemctl enable smart_basket.service
sudo systemctl start smart_basket.service
```

---

## 🎯 النتيجة يوم العرض قدام الدكتور:
1. قم بتوصيل الباوربنك بالـ Raspberry Pi وكاميرا ESP32 في السلة.
2. تفتح الـ Raspberry Pi وتبدأ خدمة الذكاء الاصطناعي تلقائياً خلال ثوانٍ.
3. قم بوضع المنتجات (`v7_can` أو `big_chips`) أمام الكاميرا، وستظهر فوراً على تطبيق الموبايل بدون أي لابتوب! 🚀
