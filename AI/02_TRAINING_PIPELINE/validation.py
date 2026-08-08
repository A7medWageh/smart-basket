#!/usr/bin/env python3
"""
Smart Basket — Validation Script
==================================
الـ validation بيجاوب على السؤال:
  "الموديل كويس قد إيه على بيانات ما شافهاش قبل كده؟"

الفرق بين Train accuracy وValidation accuracy:
  Train accuracy   = الموديل بيحفظ ← مش مفيد
  Validation accuracy = الموديل بيفهم ← ده المقياس الحقيقي

ازاي تشغله:
  python validation.py --model runs/detect/smart_basket_v1/weights/best.pt
  python validation.py --model best.pt --split test   (للـ final evaluation)
  python validation.py --model best.pt --save-json    (للـ COCO evaluation)
"""

import argparse
import json
from pathlib import Path

import yaml
import torch
from ultralytics import YOLO


# ─────────────────────────────────────────────────────────────
# VALIDATION CONFIGURATION
# ─────────────────────────────────────────────────────────────
VAL_CONFIG = {
    # data: نفس ملف data.yaml اللي استخدمناه في التدريب
    "data": "data.yaml",

    # imgsz: لازم يتطابق مع حجم التدريب
    # لو غيرت الحجم هنا النتائج هتبقى مضللة
    "imgsz": 640,

    # batch: للـ validation ممكن تبقى أكبر (مش بيعمل backward pass)
    # backward pass = الحسابات اللي بتعدل الأوزان (مش موجودة في validation)
    "batch": 32,

    # conf: Confidence Threshold
    # بس تكون الـ confidence >= conf نحسب الـ detection ده
    # في الـ validation: نستخدم 0.001 (منخفض جداً)
    # ليه؟ عشان الـ mAP يتحسب على كل الـ detections
    # الـ mAP algorithm بيعمل sweep على كل الـ thresholds
    # لو رفعنا الـ conf هنا → هنخسر detections → mAP أقل بشكل غير حقيقي
    "conf": 0.001,

    # iou: IoU threshold للـ NMS
    # IoU = Intersection over Union
    # لو اتنين boxes عندهم IoU >= iou → يبقى نفس الـ object → شيل الأضعف
    "iou": 0.6,

    # split: أي partition تقيّم عليه
    # "val"  = validation set (أثناء التطوير)
    # "test" = test set (مرة واحدة بس في الآخر — الـ final score)
    "split": "val",

    # save_json: يحفظ النتائج في format الـ COCO JSON
    # مطلوب لو عايز تقدم نتائجك في بحث علمي أو مسابقة
    "save_json": False,

    # save_hybrid: يحفظ labels هجين (للـ debugging)
    "save_hybrid": False,

    # plots: يرسم confusion matrix, PR curve, etc
    "plots": True,

    # device
    "device": "",

    # verbose: يطبع تفاصيل per-class
    "verbose": True,
}


# ─────────────────────────────────────────────────────────────
# METRICS EXPLANATION
# ─────────────────────────────────────────────────────────────
"""
شرح الـ Metrics:
━━━━━━━━━━━━━━━

Precision (الدقة):
  من كل الـ detections اللي الموديل عملها، كام منها صح؟
  Precision = True Positives / (True Positives + False Positives)
  مثال: الموديل اكتشف 100 pepsi → 90 صح، 10 غلط (Coca-Cola)
  Precision = 90 / 100 = 0.90

Recall (الاستدعاء):
  من كل المنتجات الموجودة فعلاً، الموديل اكتشف كام؟
  Recall = True Positives / (True Positives + False Negatives)
  مثال: في الصورة 100 pepsi → الموديل اكتشف 85 بس
  Recall = 85 / 100 = 0.85

F1 Score:
  متوسط هارموني بين Precision وRecall
  F1 = 2 × (Precision × Recall) / (Precision + Recall)
  لما الاتنين كويسين → F1 كويس

mAP@50 (mean Average Precision at IoU=0.50):
  المقياس الأهم في الـ object detection
  - AP: المساحة تحت منحنى الـ Precision-Recall لكل class
  - mAP: متوسط الـ AP على كل الـ classes
  - @50: IoU threshold = 0.50 (تعتبر الـ detection صح لو overlap >= 50%)
  
  تفسير القيم:
  >= 0.95: ممتاز — يصلح للـ production
  >= 0.90: كويس جداً — مقبول للمشروع
  >= 0.80: مقبول — ممكن تحسين
  < 0.70:  ضعيف — راجع الـ dataset

mAP@50-95:
  نفس mAP@50 بس بياخد متوسط على thresholds من 0.50 لـ 0.95
  أصعم وأدق تقييم
  لو mAP@50 = 0.97 وmAP@50-95 = 0.85 → الموديل كويس في detection
  بس الـ boxes مش precise جداً (فرق كبير بين الاتنين)

Confusion Matrix:
  جدول بيوضح:
  - كل row: class فعلية
  - كل column: class اللي الموديل اتنبأ بيها
  - الـ diagonal: الصح (True Positives)
  - خارج الـ diagonal: الأخطاء
  
  مثال confusion matrix مشكلة:
  pepsi_can مرتبك مع coca_cola_can → لازم تعيد النظر في الـ augmentation
"""


# ─────────────────────────────────────────────────────────────
# VALIDATION FUNCTIONS
# ─────────────────────────────────────────────────────────────

def run_validation(model_path: str, args) -> dict:
    """
    بيشغل الـ validation الكاملة ويرجع الـ metrics.

    Args:
        model_path: مسار ملف الـ .pt أو .onnx
        args: الـ CLI arguments

    Returns:
        dict: الـ metrics الكاملة
    """
    print("\n" + "=" * 60)
    print("  Smart Basket — Model Validation")
    print("=" * 60)

    # Override config from args
    split  = args.split   if args.split   else VAL_CONFIG["split"]
    conf   = args.conf    if args.conf    else VAL_CONFIG["conf"]
    device = args.device  if args.device  else VAL_CONFIG["device"]

    print(f"\n  Model  : {model_path}")
    print(f"  Split  : {split}")
    print(f"  Conf   : {conf}")
    print(f"  Device : {device or 'auto'}")

    # تحذير مهم جداً
    if split == "test":
        print("\n  ⚠️  WARNING: You are evaluating on the TEST SET!")
        print("     This should only be done ONCE, after all development is complete.")
        print("     Do NOT use test results to make training decisions.")
        response = input("\n  Are you sure? (yes/no): ").strip().lower()
        if response != "yes":
            print("  Aborted. Use --split val for development.")
            return {}

    # ── تحميل الموديل ─────────────────────────────────────────
    print(f"\n  🔄 Loading model...")
    model = YOLO(model_path)

    # ── تشغيل الـ validation ────────────────────────────────────
    print(f"  🔄 Running validation on {split} set...\n")

    metrics = model.val(
        data       = VAL_CONFIG["data"],
        imgsz      = VAL_CONFIG["imgsz"],
        batch      = VAL_CONFIG["batch"],
        conf       = conf,
        iou        = VAL_CONFIG["iou"],
        split      = split,
        save_json  = args.save_json if args.save_json else VAL_CONFIG["save_json"],
        plots      = VAL_CONFIG["plots"],
        device     = device,
        verbose    = VAL_CONFIG["verbose"],
    )

    return metrics


def print_detailed_results(metrics):
    """
    بيطبع النتائج بطريقة مفصلة ومرتبة.
    """
    print("\n" + "=" * 60)
    print("  VALIDATION RESULTS")
    print("=" * 60)

    # ── Overall Metrics ────────────────────────────────────────
    print("\n  📊 Overall Performance:")
    print(f"     mAP@50       : {metrics.box.map50:.4f}  ({metrics.box.map50*100:.1f}%)")
    print(f"     mAP@50-95    : {metrics.box.map:.4f}  ({metrics.box.map*100:.1f}%)")
    print(f"     Precision    : {metrics.box.mp:.4f}  ({metrics.box.mp*100:.1f}%)")
    print(f"     Recall       : {metrics.box.mr:.4f}  ({metrics.box.mr*100:.1f}%)")

    # ── Per-Class Metrics ──────────────────────────────────────
    print("\n  📋 Per-Class Performance:")
    print(f"  {'Class':<20} {'Precision':>10} {'Recall':>10} {'mAP@50':>10} {'mAP@50-95':>12}")
    print("  " + "-" * 66)

    # اسماء الـ classes من الـ model
    class_names = metrics.names  # dict {id: name}

    for i, (p, r, ap50, ap) in enumerate(zip(
        metrics.box.p,
        metrics.box.r,
        metrics.box.ap50,
        metrics.box.ap
    )):
        class_name = class_names.get(i, f"class_{i}")
        # رمز تقييم لكل class
        if ap50 >= 0.95:  grade = "🟢"
        elif ap50 >= 0.85: grade = "🟡"
        else:              grade = "🔴"

        print(f"  {grade} {class_name:<18} {p:>10.4f} {r:>10.4f} {ap50:>10.4f} {ap:>12.4f}")

    # ── Speed ──────────────────────────────────────────────────
    print(f"\n  ⚡ Inference Speed:")
    print(f"     Preprocess   : {metrics.speed['preprocess']:.1f} ms/image")
    print(f"     Inference    : {metrics.speed['inference']:.1f} ms/image")
    print(f"     Postprocess  : {metrics.speed['postprocess']:.1f} ms/image")
    total_ms = sum(metrics.speed.values())
    print(f"     TOTAL        : {total_ms:.1f} ms/image  ({1000/total_ms:.1f} FPS)")

    # ── Analysis ───────────────────────────────────────────────
    print("\n  🔍 Analysis:")

    # find worst class
    worst_idx  = metrics.box.ap50.argmin()
    worst_name = class_names.get(int(worst_idx), f"class_{worst_idx}")
    worst_ap50 = float(metrics.box.ap50[worst_idx])
    print(f"     Weakest class: {worst_name} (mAP@50={worst_ap50:.4f})")

    # find best class
    best_idx  = metrics.box.ap50.argmax()
    best_name = class_names.get(int(best_idx), f"class_{best_idx}")
    best_ap50 = float(metrics.box.ap50[best_idx])
    print(f"     Strongest    : {best_name} (mAP@50={best_ap50:.4f})")

    # Precision vs Recall analysis
    if metrics.box.mp > metrics.box.mr + 0.05:
        print("     ⚠️  High Precision, Low Recall → model is too conservative")
        print("         Fix: lower confidence threshold, or add more diverse training data")
    elif metrics.box.mr > metrics.box.mp + 0.05:
        print("     ⚠️  High Recall, Low Precision → model has too many false positives")
        print("         Fix: raise confidence threshold, or add negative (background) images")

    # Overall grade
    map50 = metrics.box.map50
    if map50 >= 0.95:
        print(f"\n  ✅ EXCELLENT: mAP@50={map50:.4f} — Ready for deployment on Pi!")
    elif map50 >= 0.90:
        print(f"\n  ✅ GOOD: mAP@50={map50:.4f} — Acceptable for graduation project")
        print("     Consider: more data for weak classes, or stronger augmentation")
    elif map50 >= 0.80:
        print(f"\n  🟡 FAIR: mAP@50={map50:.4f} — Needs improvement")
        print("     Action: Add 100-200 more images for weak classes")
    else:
        print(f"\n  ❌ POOR: mAP@50={map50:.4f} — Significant issues")
        print("     Action: Review labels, check class balance, increase dataset size")

    print("=" * 60 + "\n")

    return {
        "map50":     float(metrics.box.map50),
        "map50_95":  float(metrics.box.map),
        "precision": float(metrics.box.mp),
        "recall":    float(metrics.box.mr),
    }


def save_results_json(results_dict: dict, save_path: str):
    """
    بيحفظ النتائج في JSON عشان تقدر تقارن بين experiments مختلفة.
    """
    path = Path(save_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        json.dump(results_dict, f, indent=2)
    print(f"  ✅ Results saved to: {path}")


# ─────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────

def parse_args():
    parser = argparse.ArgumentParser(
        description="Smart Basket — Model Validation"
    )
    parser.add_argument(
        "--model",
        type=str,
        required=True,
        help="Path to model weights (.pt or .onnx)"
    )
    parser.add_argument(
        "--split",
        type=str,
        default="val",
        choices=["train", "val", "test"],
        help="Dataset split to validate on (default: val)"
    )
    parser.add_argument(
        "--conf",
        type=float,
        default=None,
        help="Confidence threshold (default: 0.001 for mAP)"
    )
    parser.add_argument(
        "--device",
        type=str,
        default=None,
        help="Device: '0', 'cpu'"
    )
    parser.add_argument(
        "--save-json",
        action="store_true",
        help="Save results in COCO JSON format"
    )
    parser.add_argument(
        "--save-results",
        type=str,
        default=None,
        help="Save metrics to JSON file (e.g., results/v1_val.json)"
    )
    return parser.parse_args()


# ─────────────────────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    args = parse_args()

    print("\n" + "🔍 " * 20)
    print("  Smart Basket — YOLO Validation Pipeline")
    print("🔍 " * 20)

    # تشغيل الـ validation
    metrics = run_validation(args.model, args)

    if metrics:
        # طباعة النتائج
        results_dict = print_detailed_results(metrics)

        # حفظ النتائج لو المستخدم طلب
        if args.save_results:
            results_dict["model"] = args.model
            results_dict["split"] = args.split
            save_results_json(results_dict, args.save_results)

        print("\n  Next steps:")
        print(f"  - Export for Pi : python export.py --model {args.model}")
        print(f"  - Live predict  : python predict.py --model {args.model} --source 0")
