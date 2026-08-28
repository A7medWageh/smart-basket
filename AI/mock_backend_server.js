/**
 * Smart Basket — Mock Express Backend Server (Scan & Go API Simulator)
 * ====================================================================
 * يستقبل طلبات الكاميرا ومحرك الذكاء الاصطناعي على:
 * POST /api/ai/detection
 *
 * ويقوم بعرض تفاصيل المنتج المكتشف وصورته المقتطعة وتحديث السلة الافتراضية.
 */

const express = require('express');
const app = express();
const PORT = 5001;

// زيادة حد حجم الـ Body لاستقبال صور Base64 الخاصة بالمنتجات المقتطعة
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// قاعدة بيانات السلة المؤقتة بالذاكرة
const activeCart = {
    cart_code: "CART_01",
    items: [],
    total_price: 0
};

// أسعار المنتجات
const PRICING = {
    "v7_can": 15.0,
    "big_chips": 20.0
};

// ─── AI DETECTION WEBHOOK ENDPOINT ─────────────────────────────
app.post('/api/ai/detection', (req, res) => {
    const { cart_code, product_id, class_name, confidence, action, image } = req.body;

    console.log("\n==================================================");
    console.log(`📡 [Backend AI Detection Received]`);
    console.log(`🛒 Cart Code   : ${cart_code}`);
    console.log(`📦 Product     : ${class_name} (ID: ${product_id})`);
    console.log(`🎯 Confidence  : ${(confidence * 100).toFixed(1)}%`);
    console.log(`⚡ Action      : ${action.toUpperCase()}`);
    if (image) {
        console.log(`🖼️  Product Image Received (Base64 Size: ${Math.round(image.length / 1024)} KB)`);
    } else {
        console.log(`🖼️  No image payload provided`);
    }

    const price = PRICING[class_name] || 10.0;

    if (action === "added") {
        const existing = activeCart.items.find(i => i.class_name === class_name);
        if (existing) {
            existing.quantity += 1;
        } else {
            activeCart.items.push({
                product_id,
                class_name,
                unit_price: price,
                quantity: 1
            });
        }
    } else if (action === "removed") {
        const existingIdx = activeCart.items.findIndex(i => i.class_name === class_name);
        if (existingIdx !== -1) {
            activeCart.items[existingIdx].quantity -= 1;
            if (activeCart.items[existingIdx].quantity <= 0) {
                activeCart.items.splice(existingIdx, 1);
            }
        }
    }

    // حساب الإجمالي
    activeCart.total_price = activeCart.items.reduce((sum, item) => sum + (item.unit_price * item.quantity), 0);

    console.log("--------------------------------------------------");
    console.log("🛒 Current Cart Snapshot:", JSON.stringify(activeCart, null, 2));
    console.log("==================================================\n");

    return res.status(200).json({
        success: true,
        message: `Product ${class_name} (${action}) successfully processed`,
        cart: activeCart
    });
});

app.get('/api/cart/status', (req, res) => {
    return res.json(activeCart);
});

app.listen(PORT, () => {
    console.log(`🚀 Mock Scan & Go Backend Server running at http://localhost:${PORT}`);
    console.log(`📡 Ready to receive AI Product Detections at http://localhost:${PORT}/api/ai/detection`);
});
