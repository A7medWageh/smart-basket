# 🤖 Scan & Go - AI Vision Service (YOLO ONNX)

خدمة معالجة وتحليل صور الكاميرا لمنتجات السوبرماركت باستخدام نموذج **ONNX** فائق السرعة وخفيف الوزن.

---

## 📦 المنتجات المدعومة (Supported Classes)

1. `doritos sweet chili` (دوريتوس فلفل حلو)
2. `indomie chicken curry` (إندومي فراخ كاري)
3. `pepsi diet` (بيبسي دايت كانز)
4. `tea el_arosa` (شاي العروسة)

---

## 🚀 طريقة التشغيل (How to Run)

### 1. تثبيت المتطلبات:
```bash
cd ai_vision
pip install -r requirements.txt
```

### 2. تشغيل السيرفر:
```bash
python app.py
```
*سيعمل السيرفر على: `http://localhost:8000`*.

---

## 📡 كيفية استقبال الصور من الـ ESP32-CAM

يقوم الـ **ESP32** بإرسال الصورة الملتقطة عبر طلب `HTTP POST`:

```http
POST http://<AI_SERVER_IP>:8000/predict?cart_code=CART_01
Content-Type: image/jpeg
[Image Bytes]
```

يقوم سيرفر الـ AI بتحليل الصورة في **0.03 ثانية** ثم إرسال النتيجة تلقائياً للـ **Backend (`http://localhost:5001/api/ai/detection`)** ليتم تحديث سلة الموبايل فوراً عبر Socket.io!
