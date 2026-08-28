#!/usr/bin/env python3
"""
Smart Basket — Scan & Go AI Engine (Express Backend & ESP32-CAM Production Integration)
========================================================================================
محرك الذكاء الاصطناعي المجهز للربط المباشر مع سيرفر الباك إند (Scan & Go Node.js API):
1. يسحب الصور حياً من كاميرا ESP32-CAM.
2. يشغل موديل YOLO26n INT8 المطور + خوارزمية التتبع وقواعد Debouncing.
3. يرسل الـ Webhook مباشرة لنقطة الاتصال البرمجية في الباك إند: POST /api/ai/detection
"""

import os
import sys
import time
import json
import threading
import urllib.request
from collections import Counter
import cv2
import numpy as np

# حاول استيراد المكتبات الأساسية
try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False

try:
    import onnxruntime as ort
    HAS_ONNX = True
except ImportError:
    HAS_ONNX = False

try:
    from ultralytics import YOLO
    HAS_YOLO = True
except ImportError:
    HAS_YOLO = False

# ─── CONFIGURATION (إعدادات الربط الخاصة بالباك إند) ───────────

# 1. رابط الـ AI Webhook في الباك إند الحي (Scan & Go Ngrok API)
AI_WEBHOOK_URL = "https://cytoplast-courier-dandelion.ngrok-free.dev/api/ai/detection"

# 2. كود السلة الخاص بالربط (Cart Code)
CART_CODE = "CART_01"

# 3. رابط كاميرا ESP32-CAM الحقيقي
ESP32_CAM_URL = "http://192.168.1.35:81/stream"

# 4. إعدادات الموديل ومساراته
MODEL_PATH = "best_int8.onnx"
CLASSES_PATH = "classes.txt"
IMGSZ = 416
CONF_THRESH = 0.45      # حد الثقة
CONFIRM_FRAMES = 3      # تكرار الفريمات لتأكيد الإضافة
HOLD_FRAMES = 5         # فريمات السماح قبل الحذف

# الخريطة البرمجية للمنتجات والـ ID الخاص بها في قاعدة بيانات الباك إند (Scan-go DB)
PRODUCT_ID_MAP = {
    "v7_can": 3,      # Pepsi/Drinks Can ID في قاعدة بيانات Scan-go
    "big_chips": 1    # Chips/Snacks ID في قاعدة بيانات Scan-go
}

# ─── SEND AI WEBHOOK TO BACKEND ──────────────────────────────
def send_ai_detection_webhook(product_id, class_name, confidence, action="added", image_base64=None):
    """
    إرسال حدث الاكتشاف مع صورة المنتج المقتطعة لسيرفر الباك إند:
    POST /api/ai/detection
    """
    payload = {
        "cart_code": CART_CODE,
        "product_id": product_id,
        "class_name": class_name,
        "confidence": round(float(confidence), 2),
        "action": action,
        "image": image_base64
    }
    headers = {
        "Content-Type": "application/json",
        "ngrok-skip-browser-warning": "true"
    }

    if HAS_REQUESTS:
        try:
            res = requests.post(AI_WEBHOOK_URL, json=payload, headers=headers, timeout=5)
            print(f"🔥 [AI Webhook Sent] {action.upper()}: {class_name} (ID: {product_id}) | Status: {res.status_code} | Msg: {res.json().get('message','')}")
        except Exception as e:
            print(f"⚠️ خطأ في الإرسال لـ Backend Webhook: {e}")
    else:
        try:
            req = urllib.request.Request(
                AI_WEBHOOK_URL,
                data=json.dumps(payload).encode('utf-8'),
                headers=headers,
                method='POST'
            )
            with urllib.request.urlopen(req, timeout=5) as resp:
                print(f"🔥 [AI Webhook Sent] {action.upper()}: {class_name} (ID: {product_id})")
        except Exception as e:
            print(f"⚠️ خطأ في الإرسال لـ Backend Webhook: {e}")

# ─── ROBUST TRACKER ──────────────────────────────────────────
class ProductionTracker:
    def __init__(self):
        self.seen_count = Counter()
        self.miss_count = Counter()
        self.basket = Counter()
        self.last_signature = None

    def update(self, detected_items):
        # detected_items عبارة عن قائمة من dict: {"class_name": ..., "confidence": ...}
        current_names = [d["class_name"] for d in detected_items]
        current_counts = Counter(current_names)
        all_classes = set(self.seen_count.keys()) | set(current_counts.keys())

        events = []

        for cls in all_classes:
            if cls in current_counts:
                self.seen_count[cls] += 1
                self.miss_count[cls] = 0
                if self.seen_count[cls] == CONFIRM_FRAMES:
                    # حدث إضافة منتج جديد
                    self.basket[cls] = current_counts[cls]
                    conf = next((d["confidence"] for d in detected_items if d["class_name"] == cls), 0.90)
                    events.append({"class_name": cls, "action": "added", "confidence": conf})
            else:
                if cls in self.basket:
                    self.miss_count[cls] += 1
                    if self.miss_count[cls] >= HOLD_FRAMES:
                        # حدث إخراج منتج
                        del self.basket[cls]
                        del self.seen_count[cls]
                        del self.miss_count[cls]
                        events.append({"class_name": cls, "action": "removed", "confidence": 1.0})

        return events

# ─── ESP32 STREAM READER ─────────────────────────────────────
class ESP32StreamReader:
    def __init__(self, url):
        self.url = url
        self.frame = None
        self.stopped = False

    def start(self):
        threading.Thread(target=self.update, daemon=True).start()
        return self

    def update(self):
        while not self.stopped:
            try:
                req = urllib.request.urlopen(self.url, timeout=4)
                content_type = req.headers.get('Content-Type', '')
                if 'multipart' in content_type:
                    bytes_data = b''
                    while not self.stopped:
                        bytes_data += req.read(4096)
                        a = bytes_data.find(b'\xff\xd8')
                        b = bytes_data.find(b'\xff\xd9')
                        if a != -1 and b != -1:
                            jpg = bytes_data[a:b+2]
                            bytes_data = bytes_data[b+2:]
                            img = cv2.imdecode(np.frombuffer(jpg, dtype=np.uint8), cv2.IMREAD_COLOR)
                            if img is not None:
                                self.frame = img
                else:
                    arr = np.asarray(bytearray(req.read()), dtype=np.uint8)
                    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
                    if img is not None:
                        self.frame = img
                    time.sleep(0.1)
            except Exception as e:
                time.sleep(1)

    def read(self):
        return self.frame

    def stop(self):
        self.stopped = True

# ─── MAIN ENGINE ─────────────────────────────────────────────
def main():
    print("="*65)
    print("🚀 AI Vision Engine — Connected to Scan & Go Backend API")
    print("="*65)
    print(f"📡 Webhook URL : {AI_WEBHOOK_URL}")
    print(f"🛒 Cart Code   : {CART_CODE}")
    print(f"📷 Camera URL  : {ESP32_CAM_URL}\n")

    # تحميل الموديل
    classes = list(PRODUCT_ID_MAP.keys())

    if os.path.exists(CLASSES_PATH):
        with open(CLASSES_PATH) as f:
            classes = [l.strip() for l in f if l.strip()]

    if os.path.exists(MODEL_PATH) and HAS_ONNX:
        print(f"✅ تم تحميل الموديل المحسن: {MODEL_PATH}")
        opts = ort.SessionOptions()
        opts.intra_op_num_threads = 4
        model = ort.InferenceSession(MODEL_PATH, opts, providers=['CPUExecutionProvider'])
        is_onnx = True
    elif HAS_YOLO:
        print("💡 تم استخدام موديل YOLO/PyTorch...")
        model = YOLO("best_int8.onnx" if os.path.exists("best_int8.onnx") else "yolov8n.pt")
        is_onnx = False
    else:
        print("❌ لم يتم العثور على موديل ذكاء اصطناعي جاهز!")
        return

    cam = ESP32StreamReader(ESP32_CAM_URL).start()
    time.sleep(1.5)

    tracker = ProductionTracker()
    print("🟢 المحرك شغال ومستعد لمراقبة الكاميرا وإرسال الـ Webhooks لـ Node.js Backend...")

    try:
        while True:
            frame = cam.read()
            if frame is None:
                time.sleep(0.1)
                continue

            detected_items = []

            if is_onnx:
                h, w = frame.shape[:2]
                scale = IMGSZ / max(h, w)
                nh, nw = int(h * scale), int(w * scale)
                resized = cv2.resize(frame, (nw, nh))
                canvas = np.full((IMGSZ, IMGSZ, 3), 114, dtype=np.uint8)
                canvas[(IMGSZ - nh)//2:(IMGSZ - nh)//2 + nh, (IMGSZ - nw)//2:(IMGSZ - nw)//2 + nw] = resized
                blob = cv2.cvtColor(canvas, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
                blob = np.transpose(blob, (2, 0, 1))[None, ...]
                
                input_name = model.get_inputs()[0].name
                preds = model.run(None, {input_name: blob})[0][0]
                
                for det in preds:
                    if len(det) >= 6 and det[4] >= CONF_THRESH:
                        cls_id = int(det[5])
                        if cls_id < len(classes):
                            cls_name = classes[cls_id]
                            detected_items.append({
                                "class_name": cls_name,
                                "confidence": det[4]
                            })
            else:
                results = model.predict(frame, conf=CONF_THRESH, verbose=False)
                if results[0].boxes is not None:
                    for box in results[0].boxes:
                        cls_id = int(box.cls[0])
                        cls_name = model.names[cls_id]
                        detected_items.append({
                            "class_name": cls_name,
                            "confidence": float(box.conf[0])
                        })

            # تحديث الـ Tracker واستخراج الأحداث الجديدة (إضافة / حذف)
            events = tracker.update(detected_items)

            for event in events:
                cls_name = event["class_name"]
                prod_id = PRODUCT_ID_MAP.get(cls_name, 1) # ID افتراضي لو مش موجود
                send_ai_detection_webhook(
                    product_id=prod_id,
                    class_name=cls_name,
                    confidence=event["confidence"],
                    action=event["action"]
                )

            time.sleep(0.05)

    except KeyboardInterrupt:
        print("\nإيقاف المحرك...")
        cam.stop()

if __name__ == "__main__":
    main()
