#!/usr/bin/env python3
"""
Smart Basket — Prediction / Inference Script
=============================================
الملف ده بيستخدم الموديل المدرب عشان يكتشف المنتجات
في صور، فيديوهات، أو كاميرا live.

ازاي تشغله:
  على صورة:
    python predict.py --model best.pt --source image.jpg

  على مجلد صور:
    python predict.py --model best.pt --source ./test_images/

  على كاميرا live (webcam):
    python predict.py --model best.pt --source 0

  على فيديو:
    python predict.py --model best.pt --source video.mp4

  بدون رسم (أسرع):
    python predict.py --model best.pt --source 0 --no-display

  حفظ النتائج:
    python predict.py --model best.pt --source image.jpg --save
"""

import argparse
import time
from collections import Counter
from pathlib import Path

import cv2
import numpy as np
from ultralytics import YOLO


# ─────────────────────────────────────────────────────────────
# PREDICT CONFIGURATION
# ─────────────────────────────────────────────────────────────
PREDICT_CONFIG = {
    # conf: Confidence Threshold
    # في الـ inference الحقيقي (مش validation) نرفع الـ threshold
    # 0.45 = بس detections اللي الموديل واثق منها بـ 45%+
    # لو كتير false positives → ارفع لـ 0.55 أو 0.60
    # لو بيفوته منتجات → انزل لـ 0.35
    "conf": 0.45,

    # iou: IoU threshold للـ NMS
    # لو اتنين boxes على نفس المنتج → شيل الأضعف
    # 0.45 مناسب لمعظم scenarios
    "iou": 0.45,

    # imgsz: حجم الصورة عند الـ inference
    # لازم يتطابق مع حجم التدريب (640)
    "imgsz": 640,

    # max_det: أقصى عدد detections في صورة واحدة
    # السلة مش هيكون فيها أكتر من 30 منتج
    "max_det": 30,

    # device
    "device": "",

    # show: يعرض الصورة مع الـ bounding boxes
    "show": True,

    # save: يحفظ النتائج
    "save": False,

    # save_dir: مجلد حفظ النتائج
    "save_dir": "runs/predict",

    # line_width: سماكة خط الـ bounding box
    "line_width": 2,
}

# ─────────────────────────────────────────────────────────────
# PRICE MAP
# ─────────────────────────────────────────────────────────────
# في الـ production: الأسعار هتيجي من Firebase
# في الـ predict.py: نستخدم هذا كـ fallback للـ testing
# لازم تعدل الأسعار دي على حسب بلدك ومنتجاتك
PRICE_MAP = {
    "water_bottle":  5.0,    # جنيه — عدل الرقم
    "pepsi_can":    12.0,
    "coca_cola_can": 12.0,
    "juice_box":    15.0,
    "milk_carton":  20.0,
    "chocolate_bar": 15.0,
    "chips_bag":    10.0,
    "biscuits_pack": 8.0,
    "rice_bag":     45.0,
    "sugar_bag":    30.0,
}

# ألوان لكل class (BGR format لـ OpenCV)
# كل class ليها لون مميز عشان يسهل التمييز
CLASS_COLORS = {
    "water_bottle":   (255, 200, 0),    # أزرق فاتح
    "pepsi_can":      (255, 0,   0),    # أزرق غامق
    "coca_cola_can":  (0,   0,   255),  # أحمر
    "juice_box":      (0,   200, 0),    # أخضر
    "milk_carton":    (200, 200, 200),  # رمادي فاتح
    "chocolate_bar":  (0,   100, 200),  # بني
    "chips_bag":      (0,   165, 255),  # برتقالي
    "biscuits_pack":  (147, 20,  255),  # بنفسجي
    "rice_bag":       (0,   255, 255),  # أصفر فاتح
    "sugar_bag":      (255, 255, 255),  # أبيض
}


# ─────────────────────────────────────────────────────────────
# BASKET STATE TRACKER (مبسط للـ testing)
# ─────────────────────────────────────────────────────────────
class SimpleBasketTracker:
    """
    نسخة مبسطة من الـ BasketStateTracker للـ testing.
    الـ production version موجودة في version_pi.py.

    بيحسب:
    - منتجات مستقرة (شايفة لـ N frames متتالية)
    - السعر الإجمالي
    """

    def __init__(self, confirm_frames=3, hold_frames=5):
        """
        confirm_frames: عدد الـ frames اللازمة عشان نعتبر المنتج مؤكد
                        3 = المنتج لازم يظهر في 3 frames متتالية
                        بيمنع الـ false positives اللحظية

        hold_frames: عدد الـ frames قبل ما نمسح منتج اختفى
                     5 = لو المنتج اختفى 5 frames → يتمسح
                     بيمنع flickering لو الكاميرا شافت الـ product بصعوبة
        """
        self.confirm_frames = confirm_frames
        self.hold_frames    = hold_frames

        # counter لكل class: كام frame شفناه
        self.seen_count = Counter()

        # counter لكل class: كام frame ما شفناهش
        self.miss_count = Counter()

        # الـ basket الـ confirmed
        self.basket = Counter()

    def update(self, detections: list) -> dict:
        """
        بيأخد detections من frame واحد وبيرجع basket state.

        Args:
            detections: list من {class_name, confidence, bbox}

        Returns:
            dict: {class_name: quantity}
        """
        # collect class names in this frame
        current_classes = Counter(d["class_name"] for d in detections)

        # update seen and miss counters
        all_tracked = set(self.seen_count.keys()) | set(current_classes.keys())

        for cls in all_tracked:
            if cls in current_classes:
                # رأينا المنتج في الـ frame ده
                self.seen_count[cls] += 1
                self.miss_count[cls] = 0  # reset المفقودية

                # لو وصل الـ confirm threshold → ضيفه للـ basket
                if self.seen_count[cls] >= self.confirm_frames:
                    self.basket[cls] = current_classes[cls]
            else:
                # ما رأيناهش في الـ frame ده
                if cls in self.basket:
                    self.miss_count[cls] += 1
                    if self.miss_count[cls] >= self.hold_frames:
                        # مشى من الـ basket
                        del self.basket[cls]
                        del self.seen_count[cls]
                        del self.miss_count[cls]

        return dict(self.basket)

    def get_total_price(self) -> float:
        """بيحسب السعر الإجمالي للـ basket"""
        total = 0.0
        for cls, qty in self.basket.items():
            price = PRICE_MAP.get(cls, 0.0)
            total += price * qty
        return total


# ─────────────────────────────────────────────────────────────
# DRAWING FUNCTIONS
# ─────────────────────────────────────────────────────────────

def draw_detection(frame: np.ndarray, box, label: str, conf: float,
                   color: tuple) -> np.ndarray:
    """
    بيرسم bounding box وlabel على الـ frame.

    Args:
        frame: الصورة كـ numpy array (BGR)
        box: [x1, y1, x2, y2] coordinates
        label: اسم الـ class
        conf: الـ confidence score
        color: (B, G, R) tuple
    """
    x1, y1, x2, y2 = map(int, box)

    # رسم الـ rectangle
    cv2.rectangle(frame, (x1, y1), (x2, y2), color,
                  PREDICT_CONFIG["line_width"])

    # النص فوق الـ box
    text = f"{label} {conf:.2f}"

    # حجم النص
    font       = cv2.FONT_HERSHEY_SIMPLEX
    font_scale = 0.5
    thickness  = 1
    (text_w, text_h), baseline = cv2.getTextSize(text, font, font_scale, thickness)

    # خلفية للنص (عشان يقرأ بسهولة)
    cv2.rectangle(
        frame,
        (x1, y1 - text_h - baseline - 4),
        (x1 + text_w, y1),
        color,
        -1  # filled rectangle
    )

    # كتابة النص
    cv2.putText(
        frame, text,
        (x1, y1 - baseline - 2),
        font, font_scale,
        (0, 0, 0),  # أسود على الخلفية الملونة
        thickness
    )

    return frame


def draw_basket_overlay(frame: np.ndarray, basket: dict, total_price: float,
                         fps: float) -> np.ndarray:
    """
    بيرسم overlay بمحتوى السلة والسعر الإجمالي.
    """
    h, w = frame.shape[:2]

    # خلفية شفافة للـ overlay
    overlay = frame.copy()
    cv2.rectangle(overlay, (0, 0), (300, h), (0, 0, 0), -1)
    cv2.addWeighted(overlay, 0.4, frame, 0.6, 0, frame)

    # عنوان
    cv2.putText(frame, "Smart Basket", (10, 30),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)

    # FPS
    cv2.putText(frame, f"FPS: {fps:.1f}", (10, 55),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)

    # محتوى السلة
    y_pos = 85
    cv2.putText(frame, "Items:", (10, y_pos),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
    y_pos += 20

    if basket:
        for cls, qty in sorted(basket.items()):
            price      = PRICE_MAP.get(cls, 0)
            line_price = price * qty
            color      = CLASS_COLORS.get(cls, (255, 255, 255))

            # اسم المنتج مختصر عشان يناسب الـ overlay
            short_name = cls.replace("_", " ")[:15]
            text = f"  {short_name} x{qty}"
            cv2.putText(frame, text, (10, y_pos),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.4, color, 1)
            y_pos += 18

            price_text = f"  {line_price:.1f} EGP"
            cv2.putText(frame, price_text, (10, y_pos),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.4, (200, 200, 200), 1)
            y_pos += 22
    else:
        cv2.putText(frame, "  (empty)", (10, y_pos),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.4, (150, 150, 150), 1)
        y_pos += 20

    # الخط الفاصل
    cv2.line(frame, (10, y_pos + 5), (290, y_pos + 5), (100, 100, 100), 1)
    y_pos += 20

    # السعر الإجمالي
    cv2.putText(frame, f"TOTAL: {total_price:.1f} EGP",
                (10, y_pos + 15),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)

    return frame


# ─────────────────────────────────────────────────────────────
# MAIN PREDICT FUNCTION
# ─────────────────────────────────────────────────────────────

def run_predict(model_path: str, source: str, args):
    """
    بيشغل الـ prediction على source معين.

    Args:
        model_path: مسار الموديل
        source: مصدر الصور (كاميرا/ملف/مجلد)
        args: CLI arguments
    """
    print(f"\n  🔄 Loading model: {model_path}")
    model  = YOLO(model_path)
    names  = model.names  # {0: 'water_bottle', 1: 'pepsi_can', ...}
    tracker = SimpleBasketTracker(confirm_frames=3, hold_frames=5)

    print(f"  ✅ Model loaded with {len(names)} classes")
    print(f"  🎯 Source: {source}")
    print(f"  📊 Confidence threshold: {PREDICT_CONFIG['conf']}")

    # FPS tracking
    fps_history = []
    display = not args.no_display

    # ── Run YOLO prediction ────────────────────────────────────
    # YOLO.predict() بيقدر يشتغل على:
    #   - صورة واحدة
    #   - مجلد صور
    #   - كاميرا (source=0 or 1)
    #   - URL
    #   - فيديو
    results_gen = model.predict(
        source   = source,
        conf     = PREDICT_CONFIG["conf"],
        iou      = PREDICT_CONFIG["iou"],
        imgsz    = PREDICT_CONFIG["imgsz"],
        max_det  = PREDICT_CONFIG["max_det"],
        device   = PREDICT_CONFIG["device"],
        stream   = True,    # بيرجع generator مش list
                            # مهم للـ video وcamera عشان ما تملأش الـ RAM
        verbose  = False,   # quiet mode
    )

    print("\n  Press 'q' to quit, 's' to save current frame\n")

    for result in results_gen:
        t_start = time.perf_counter()

        # ── استخلاص الـ detections ─────────────────────────────
        detections = []

        if result.boxes is not None and len(result.boxes) > 0:
            for box in result.boxes:
                cls_id    = int(box.cls[0])
                cls_name  = names[cls_id]
                conf      = float(box.conf[0])
                xyxy      = box.xyxy[0].cpu().numpy()

                detections.append({
                    "class_id":   cls_id,
                    "class_name": cls_name,
                    "confidence": conf,
                    "bbox":       xyxy,
                })

        # ── تحديث الـ basket state ─────────────────────────────
        basket      = tracker.update(detections)
        total_price = tracker.get_total_price()

        # ── الرسم على الـ frame ────────────────────────────────
        frame = result.orig_img.copy()  # الصورة الأصلية

        # رسم كل detection
        for det in detections:
            color = CLASS_COLORS.get(det["class_name"], (0, 255, 0))
            frame = draw_detection(
                frame,
                det["bbox"],
                det["class_name"],
                det["confidence"],
                color
            )

        # حساب الـ FPS
        t_end = time.perf_counter()
        fps_current = 1.0 / max(t_end - t_start, 1e-9)
        fps_history.append(fps_current)
        if len(fps_history) > 30:
            fps_history.pop(0)
        fps_avg = sum(fps_history) / len(fps_history)

        # رسم الـ overlay
        if display or args.save:
            frame = draw_basket_overlay(frame, basket, total_price, fps_avg)

        # ── عرض الـ frame ──────────────────────────────────────
        if display:
            cv2.imshow("Smart Basket — Press Q to quit", frame)

        # ── حفظ لو مطلوب ──────────────────────────────────────
        if args.save:
            save_path = Path(PREDICT_CONFIG["save_dir"])
            save_path.mkdir(parents=True, exist_ok=True)
            out_file = save_path / f"pred_{Path(str(source)).stem}.jpg"
            cv2.imwrite(str(out_file), frame)

        # ── keyboard control ───────────────────────────────────
        key = cv2.waitKey(1) & 0xFF
        if key == ord("q"):
            print("\n  Quit requested by user.")
            break
        elif key == ord("s"):
            # حفظ يدوي للـ frame الحالي
            snap_path = Path("snapshots")
            snap_path.mkdir(exist_ok=True)
            snap_file = snap_path / f"snap_{int(time.time())}.jpg"
            cv2.imwrite(str(snap_file), frame)
            print(f"  📸 Snapshot saved: {snap_file}")

        # ── طباعة summary في الـ console ──────────────────────
        if detections:
            det_summary = ", ".join(
                f"{d['class_name']}({d['confidence']:.2f})"
                for d in detections[:5]  # أول 5 بس
            )
            print(f"  [{fps_avg:.1f} FPS] Detected: {det_summary}"
                  f" | Basket: {sum(basket.values())} items"
                  f" | Total: {total_price:.1f} EGP",
                  end="\r")

    cv2.destroyAllWindows()
    print("\n  ✅ Prediction session ended")


# ─────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────

def parse_args():
    parser = argparse.ArgumentParser(
        description="Smart Basket — Prediction & Inference"
    )
    parser.add_argument(
        "--model",
        type=str,
        required=True,
        help="Path to model (.pt or .onnx)"
    )
    parser.add_argument(
        "--source",
        type=str,
        default="0",
        help="Source: '0' (webcam), image.jpg, video.mp4, ./images/ (default: 0)"
    )
    parser.add_argument(
        "--conf",
        type=float,
        default=None,
        help="Confidence threshold (default: 0.45)"
    )
    parser.add_argument(
        "--no-display",
        action="store_true",
        help="Disable window display (headless mode)"
    )
    parser.add_argument(
        "--save",
        action="store_true",
        help="Save output images/video"
    )
    return parser.parse_args()


# ─────────────────────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    args = parse_args()

    if args.conf:
        PREDICT_CONFIG["conf"] = args.conf

    print("\n" + "🎯 " * 20)
    print("  Smart Basket — YOLO Prediction")
    print("🎯 " * 20)

    run_predict(args.model, args.source, args)
