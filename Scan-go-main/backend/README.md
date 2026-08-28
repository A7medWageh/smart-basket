# 🛒 Scan & Go - السيرفر الخلفي لنظام السلة الذكية (Smart Shopping Cart Backend)

خادم متكامل مبني باستخدام **Node.js, TypeScript, Express, Socket.io, Prisma ORM** للربط اللحظي بين تطبيق الموبايل، وسيرفر معالجة صور الكاميرا (ESP32-CAM AI)، ونظام الدفع وإصدار رمز الخروج (Exit QR Pass).

---

## 🚀 طريقة تشغيل السيرفر

```bash
# 1. الدخول لمجلد الباك إند
cd backend

# 2. تشغيل السيرفر في وضع التطوير
npm run dev

# 3. بناء النسخة النهائية (Build)
npm run build
npm start
```

* **رابط السيرفر:** `http://localhost:5001`
* **لوحة المحاكاة التفاعلية (Simulator):** افتح `http://localhost:5001` في المتصفح لتجربة كل الوظائف فوراً.
* **فحص الحالة (Health Check):** `http://localhost:5001/api/health`

---

## 📂 شرح هيكل الملفات والمشروع (Codebase Architecture)

```
backend/
├── src/
│   ├── config/
│   │   └── env.ts                 # إعدادات البيئة والمنافذ والـ JWT Secret
│   ├── lib/
│   │   └── prisma.ts              # كائن اتصال قاعدة البيانات (Prisma Client Singleton)
│   ├── services/
│   │   ├── socketService.ts       # محرك الـ WebSockets (Socket.io) لإرسال التحديثات اللحظية
│   │   └── cartService.ts         # المنطق البرمجي لحسابات السلة، إضافة وحذف العناصر
│   ├── middlewares/
│   │   ├── authMiddleware.ts      # التحقق من صلاحية توكن المستخدم (JWT Protection)
│   │   └── errorHandler.ts        # معالج الأخطاء العام
│   ├── controllers/
│   │   ├── authController.ts      # تسجيل المستخدمين وتسجيل الدخول
│   │   ├── productController.ts   # استعراض كتالوج منتجات السوبرماركت
│   │   ├── cartController.ts      # ربط السلة بالـ QR وإدارتها
│   │   ├── aiController.ts        # الـ Webhook المستلم لنتائج معالجة صور الكاميرا
│   │   └── orderController.ts     # إتمام الدفع (Mock Pay) وتوليد كود الخروج Exit QR
│   ├── routes/                    # توجيه الـ Endpoints
│   │   ├── authRoutes.ts
│   │   ├── productRoutes.ts
│   │   ├── cartRoutes.ts
│   │   ├── aiRoutes.ts
│   │   └── orderRoutes.ts
│   ├── app.ts                     # تهيئة تطبيق Express و الـ Middlewares
│   └── server.ts                  # نقطة الدخول وتشغيل سيرفر الـ HTTP و Socket.io
├── prisma/
│   ├── schema.prisma              # جداول قاعدة البيانات (Users, Carts, Products, Sessions, Orders)
│   └── seed.ts                    # بيانات تجريبية للمنتجات وسلات السوبرماركت
└── public/
    └── index.html                 # لوحة محاكاة تفاعلية (Live Web Simulator)
```

---

## 📡 دليل التكامل للفريق (Team Integration Guide)

### 1. دليل مطور الموبايل (Mobile App Developer)

#### أ. تسجيل الدخول والحصول على Token
```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "ahmed@scango.com",
  "password": "password123"
}
```
*احتفظ بالـ `token` في الـ Secure Storage واستخدمه في ترويسة الطلبات: `Authorization: Bearer <TOKEN>`*.

#### ب. ربط التطبيق بالسلة عند عمل Scan للـ QR
عندما يمسح المستخدم الـ QR الملصوق على السلة:
```http
POST /api/cart/pair
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "cartCode": "CART_01"
}
```

#### ج. الاتصال بالـ WebSockets لتحديث السلة لحظياً
استخدم مكتبة `socket_io_client` في Flutter أو `socket.io-client` في React Native:
```javascript
// 1. الاتصال بالسيرفر
const socket = io("http://<YOUR_BACKEND_IP>:5000");

// 2. الانضمام لغرفة السلة
socket.emit("join:cart", "CART_01");

// 3. الاستماع للتحديثات التلقائية (أول ما الـ AI يكتشف منتج أو يتم الحذف)
socket.on("cart:updated", (data) => {
  console.log("السلة اتحدثت:", data.cart);
  // حدث الـ UI فوراً بـ data.cart.items و data.cart.grandTotal
});

// 4. الاستماع لانتهاء الدفع
socket.on("checkout:completed", (receipt) => {
  // عرض شاشة الفاتورة ورمز Exit QR
});
```

#### د. الدفع والمغادرة (Checkout)
```http
POST /api/orders/checkout
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "paymentMethod": "INSTAPAY" // أو "VODAFONE_CASH" أو "VISA"
}
```
*يُرجع السيرفر الفاتورة وكود الـ `exitQrCode` (صورة Base64) لعرضها للمستخدم لمسحها عند البوابة.*

---

### 2. دليل مطور الـ AI / الرؤية الحاسوبية (Computer Vision Developer)

عندما يلتقط الـ ESP32 صورة المنتج ويتعرف الموديل عليه:
يقوم سيرفر الـ AI بإرسال طلب HTTP POST مباشر للـ Backend:

```http
POST /api/ai/detection
Content-Type: application/json

{
  "cart_code": "CART_01",
  "product_id": 1,
  "confidence": 0.96,
  "action": "added"
}
```
*يدعم السيرفر أيضاً إرسال `"barcode": "6221001001"` أو `"label": "pepsi"` بدلاً من `product_id`.*

---

## 🗄️ الأوامر المساعدة لقاعدة البيانات

* **تحديث وتعديل الجداول:** `npx prisma db push`
* **إعادة إدخال البيانات التجريبية:** `npm run db:seed`
* **فتح لوحة تحكم بصرية لقاعدة البيانات:** `npm run db:studio`
