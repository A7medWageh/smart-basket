#!/usr/bin/env python3
"""
Smart Basket — Model Export Script
=====================================
بعد التدريب، الموديل بيكون في format PyTorch (.pt)
الـ Pi 5 مش بيستخدم PyTorch مباشرة — محتاجين نحوله

الـ Export Pipeline:
  best.pt (PyTorch, 5MB)
    ├── best.onnx        → للاب توب والـ Pi (ONNX Runtime)
    ├── best_int8.onnx   → للـ Pi (أسرع 3x، أصغر 3x)
    └── best_ncnn/       → للـ Pi (الأسرع على ARM)

ازاي تشغله:
  python export.py --model best.pt
  python export.py --model best.pt --formats onnx ncnn
  python export.py --model best.pt --formats onnx --imgsz 416
"""

import argparse
import os
import shutil
import zipfile
from pathlib import Path

from ultralytics import YOLO

# ─────────────────────────────────────────────────────────────
# WHY DIFFERENT EXPORT FORMATS?
# ─────────────────────────────────────────────────────────────
"""
شرح الـ Export Formats:
━━━━━━━━━━━━━━━━━━━━━━━

PyTorch (.pt) — الأصل:
  ✅ سهل التحميل في Python
  ✅ يدعم resume التدريب
  ❌ يحتاج PyTorch مثبت (كبير — 1GB+)
  ❌ بطيء على الـ CPU
  → استخدامه: التدريب والتطوير فقط

ONNX (.onnx) — Open Neural Network Exchange:
  ✅ يشتغل على أي platform بدون PyTorch
  ✅ يدعم GPU وCPU
  ✅ ONNX Runtime سريع على Intel/AMD
  ✅ حجم أصغر (9MB FP32)
  → استخدامه: الاب توب للتجربة، الـ Pi مع ONNX Runtime

ONNX INT8 — Quantized:
  ✅ 3-4x أصغر من FP32 (2.7MB!)
  ✅ 2-3x أسرع على CPU
  ✅ دقة قريبة جداً من FP32
  ❌ يحتاج calibration dataset لأفضل دقة
  → استخدامه: الـ Pi 5 (الخيار الأمثل!)

NCNN — Tencent Mobile Framework:
  ✅ الأسرع على ARM processors
  ✅ ARM NEON SIMD instructions
  ✅ مصمم خصيصاً للـ mobile وembedded
  ✅ 30-50% أسرع من ONNX Runtime على Pi 5
  ❌ أصعب في الـ debugging
  ❌ يحتاج compilation من source على Pi أحياناً
  → استخدامه: الـ Pi 5 Production (الخيار المثالي)

مقارنة السرعة على Raspberry Pi 5:
  ONNX FP32  : ~180ms/frame  (~5.5 FPS)
  ONNX INT8  : ~80ms/frame   (~12.5 FPS)  ← recommended
  NCNN FP32  : ~120ms/frame  (~8.3 FPS)
  NCNN INT8  : ~55ms/frame   (~18 FPS)    ← best performance
"""

# ─────────────────────────────────────────────────────────────
# EXPORT CONFIGURATION
# ─────────────────────────────────────────────────────────────
EXPORT_CONFIG = {
    # imgsz: حجم الصورة للـ export
    # لازم يتطابق مع اللي هنستخدمه في الـ inference
    # 640 = دقة أعلى، بطيء أكثر
    # 416 = توازن جيد للـ Pi (recommended)
    # 320 = الأسرع، دقة أقل
    "imgsz": 416,

    # opset: ONNX opset version
    # 17 هو الأحدث والمدعوم من ONNX Runtime الحديث
    # لو عندك مشكلة compatibility → جرب 12 أو 11
    "opset": 17,

    # simplify: بيعمل optimize للـ ONNX graph
    # يحذف العمليات الزائدة، يدمج الـ layers المتتالية
    # دايماً True — بيصغر الملف ويسرعه بدون أي خسارة
    "simplify": True,

    # half: FP16 (نص الدقة)
    # على GPU: أسرع وأصغر
    # على CPU (Pi 5): مش مدعوم نيتيفلي → False
    # على HAILO: ممكن True
    "half": False,

    # dynamic: dynamic input shapes
    # False = الحجم fixed (أسرع وأبسط للـ embedded)
    # True = يقبل أحجام مختلفة (أبطأ)
    "dynamic": False,
}


# ─────────────────────────────────────────────────────────────
# QUANTIZATION
# ─────────────────────────────────────────────────────────────

def quantize_onnx_int8(onnx_fp32_path: str) -> str:
    """
    بيحول الـ ONNX FP32 لـ ONNX INT8.

    FP32: كل وزن 32-bit float (4 bytes)
    INT8: كل وزن 8-bit integer (1 byte)

    النتيجة:
    - الحجم: 4x أصغر
    - السرعة: 2-3x أسرع على CPU
    - الدقة: خسارة بسيطة جداً (<1% mAP عادةً)

    dynamic quantization:
    - لا يحتاج calibration dataset
    - يطبق quantization على الـ weights فقط
    - الـ activations تبقى FP32 أثناء الـ inference

    static quantization (أفضل):
    - يحتاج calibration dataset (100-200 صورة)
    - يطبق quantization على الـ weights والـ activations
    - أدق من dynamic
    - هنستخدم dynamic هنا للبساطة
    """
    try:
        from onnxruntime.quantization import quantize_dynamic, QuantType
    except ImportError:
        print("  ⚠️  onnxruntime-tools not found.")
        print("     pip install onnxruntime-tools")
        return None

    # اسم ملف الـ INT8
    onnx_int8_path = onnx_fp32_path.replace(".onnx", "_int8.onnx")

    print(f"\n  🔄 Quantizing to INT8...")
    print(f"     Input  : {onnx_fp32_path}")
    print(f"     Output : {onnx_int8_path}")

    quantize_dynamic(
        model_input  = onnx_fp32_path,
        model_output = onnx_int8_path,
        # QUInt8: unsigned 8-bit integer (0 to 255)
        # أنسب للـ activations بعد ReLU (دايماً positive)
        weight_type  = QuantType.QUInt8,
    )

    # قارن الأحجام
    fp32_size = os.path.getsize(onnx_fp32_path) / 1e6
    int8_size = os.path.getsize(onnx_int8_path) / 1e6
    compression = fp32_size / int8_size

    print(f"  ✅ Quantization complete!")
    print(f"     FP32 size: {fp32_size:.1f} MB")
    print(f"     INT8 size: {int8_size:.1f} MB")
    print(f"     Compression: {compression:.1f}x smaller")

    return onnx_int8_path


# ─────────────────────────────────────────────────────────────
# MAIN EXPORT FUNCTION
# ─────────────────────────────────────────────────────────────

def run_export(model_path: str, args) -> dict:
    """
    بيعمل export لـ formats المطلوبة.
    بيرجع dict بمسارات كل الملفات المصدرة.
    """

    print("\n" + "=" * 60)
    print("  Smart Basket — Model Export")
    print("=" * 60)

    formats  = args.formats if args.formats else ["onnx", "ncnn"]
    imgsz    = args.imgsz   if args.imgsz   else EXPORT_CONFIG["imgsz"]
    model_pt = Path(model_path)
    save_dir = model_pt.parent

    if not model_pt.exists():
        print(f"  ❌ Model not found: {model_path}")
        return {}

    print(f"\n  Model    : {model_path}")
    print(f"  Formats  : {', '.join(formats)}")
    print(f"  Img size : {imgsz}×{imgsz}")
    print(f"  Save to  : {save_dir}")

    exported_files = {"pt": str(model_pt)}

    # ── تحميل الموديل ─────────────────────────────────────────
    print(f"\n  🔄 Loading model...")
    model = YOLO(model_path)

    # ── Export ONNX ────────────────────────────────────────────
    if "onnx" in formats:
        print(f"\n  📦 Exporting to ONNX FP32...")
        print(f"     Input shape: (1, 3, {imgsz}, {imgsz})")
        print(f"     Opset: {EXPORT_CONFIG['opset']}")

        onnx_path = model.export(
            format   = "onnx",
            imgsz    = imgsz,
            opset    = EXPORT_CONFIG["opset"],
            simplify = EXPORT_CONFIG["simplify"],
            half     = EXPORT_CONFIG["half"],
            dynamic  = EXPORT_CONFIG["dynamic"],
        )

        onnx_size = os.path.getsize(onnx_path) / 1e6
        print(f"  ✅ ONNX exported: {onnx_path} ({onnx_size:.1f} MB)")
        exported_files["onnx_fp32"] = onnx_path

        # ── Export ONNX INT8 ───────────────────────────────────
        if "int8" in formats or "onnx_int8" in formats:
            int8_path = quantize_onnx_int8(onnx_path)
            if int8_path:
                exported_files["onnx_int8"] = int8_path

        # تلقائياً نعمل INT8 مع ONNX
        elif "onnx" in formats:
            print(f"\n  🔄 Auto-generating INT8 version...")
            int8_path = quantize_onnx_int8(onnx_path)
            if int8_path:
                exported_files["onnx_int8"] = int8_path

    # ── Export NCNN ────────────────────────────────────────────
    if "ncnn" in formats:
        print(f"\n  📦 Exporting to NCNN (ARM-optimized)...")
        print("     Note: NCNN export disables end2end NMS")
        print("     You'll need to apply NMS manually in inference code")

        try:
            ncnn_path = model.export(
                format = "ncnn",
                imgsz  = imgsz,
                half   = False,  # الـ Pi 5 مش بيدعم FP16
            )
            print(f"  ✅ NCNN exported: {ncnn_path}")
            exported_files["ncnn"] = ncnn_path
        except Exception as e:
            print(f"  ⚠️  NCNN export failed: {e}")
            print("     NCNN requires additional dependencies on some systems")
            print("     On Colab: !pip install ncnn pnnx")

    # ── Verify ONNX Output ─────────────────────────────────────
    if "onnx_fp32" in exported_files:
        print(f"\n  🔍 Verifying ONNX model...")
        verify_onnx(exported_files["onnx_fp32"])

    # ── Create Deployment Packages ─────────────────────────────
    print(f"\n  📦 Creating deployment packages...")
    packages = create_deployment_packages(exported_files, save_dir, imgsz)
    exported_files.update(packages)

    # ── Print Summary ──────────────────────────────────────────
    print_export_summary(exported_files)

    return exported_files


# ─────────────────────────────────────────────────────────────
# ONNX VERIFICATION
# ─────────────────────────────────────────────────────────────

def verify_onnx(onnx_path: str):
    """
    بيتحقق إن الـ ONNX model شغال صح.
    بيشغل inference sample ويتحقق من الـ output shape.
    """
    try:
        import onnx
        import onnxruntime as ort
        import numpy as np

        # التحقق من الـ ONNX model structure
        model_onnx = onnx.load(onnx_path)
        onnx.checker.check_model(model_onnx)
        print(f"  ✅ ONNX model structure: valid")

        # ONNX Runtime inference test
        session = ort.InferenceSession(
            onnx_path,
            providers=["CPUExecutionProvider"]
        )

        # مدخل وهمي
        input_name  = session.get_inputs()[0].name
        input_shape = session.get_inputs()[0].shape
        # الـ shape ممكن يبقى (1, 3, 416, 416) أو dynamic
        actual_shape = [1, 3, 416, 416]  # نستخدم fixed shape

        dummy_input = np.random.rand(*actual_shape).astype(np.float32)
        outputs     = session.run(None, {input_name: dummy_input})

        output_shape = outputs[0].shape
        print(f"  ✅ ONNX inference test: passed")
        print(f"     Input  shape: {actual_shape}")
        print(f"     Output shape: {output_shape}")
        # الـ output المتوقع: (1, num_detections, 6) أو (1, 6, 2100) حسب الـ format

    except Exception as e:
        print(f"  ⚠️  ONNX verification warning: {e}")


# ─────────────────────────────────────────────────────────────
# DEPLOYMENT PACKAGE CREATION
# ─────────────────────────────────────────────────────────────

def create_deployment_packages(exported_files: dict, save_dir: Path,
                                imgsz: int) -> dict:
    """
    بيعمل zip files للنشر على الـ Pi والاب توب.

    laptop_package.zip:
      best.onnx + best_int8.onnx + classes.txt + README.txt

    rpi5_package.zip:
      best_int8.onnx + best_ncnn/ + classes.txt + README.txt
    """
    packages = {}

    # ── إنشاء classes.txt ─────────────────────────────────────
    classes_txt = save_dir / "classes.txt"
    class_names = [
        "water_bottle", "pepsi_can", "coca_cola_can", "juice_box",
        "milk_carton", "chocolate_bar", "chips_bag", "biscuits_pack",
        "rice_bag", "sugar_bag"
    ]
    with open(classes_txt, "w") as f:
        f.write("\n".join(class_names))
    print(f"  ✅ Created: classes.txt")

    # ── README.txt ─────────────────────────────────────────────
    readme_txt = save_dir / "README.txt"
    with open(readme_txt, "w") as f:
        f.write(f"""Smart Basket — Model Export
================================
Export date: {__import__('datetime').date.today()}
Image size : {imgsz}×{imgsz}
Classes    : 10

Files:
  best.onnx       → FP32 ONNX, for laptop/desktop (GPU or CPU)
  best_int8.onnx  → INT8 ONNX, for Raspberry Pi 5 (CPU optimized)
  best_ncnn/      → NCNN format, fastest on ARM processors
  classes.txt     → Class names (one per line, line number = class_id)

Usage:
  Laptop : python predict.py --model best.onnx --source 0
  Pi 5   : python predict.py --model best_int8.onnx --source 0
""")

    # ── Laptop Package ─────────────────────────────────────────
    laptop_zip = save_dir / "laptop_package.zip"
    with zipfile.ZipFile(laptop_zip, "w", zipfile.ZIP_DEFLATED) as zf:
        if "onnx_fp32" in exported_files:
            zf.write(exported_files["onnx_fp32"],  "best.onnx")
        if "onnx_int8" in exported_files:
            zf.write(exported_files["onnx_int8"],  "best_int8.onnx")
        zf.write(classes_txt, "classes.txt")
        zf.write(readme_txt,  "README.txt")

    zip_size = os.path.getsize(laptop_zip) / 1e6
    print(f"  ✅ Laptop package : {laptop_zip} ({zip_size:.1f} MB)")
    packages["laptop_package"] = str(laptop_zip)

    # ── Pi Package ─────────────────────────────────────────────
    rpi5_zip = save_dir / "rpi5_package.zip"
    with zipfile.ZipFile(rpi5_zip, "w", zipfile.ZIP_DEFLATED) as zf:
        # INT8 ONNX للـ Pi
        if "onnx_int8" in exported_files:
            zf.write(exported_files["onnx_int8"], "best_int8.onnx")
        # NCNN لو موجود
        if "ncnn" in exported_files:
            ncnn_dir = Path(exported_files["ncnn"])
            if ncnn_dir.is_dir():
                for ncnn_file in ncnn_dir.rglob("*"):
                    if ncnn_file.is_file():
                        zf.write(ncnn_file,
                                 f"best_ncnn/{ncnn_file.name}")
        zf.write(classes_txt, "classes.txt")
        zf.write(readme_txt,  "README.txt")

    zip_size = os.path.getsize(rpi5_zip) / 1e6
    print(f"  ✅ RPi5 package   : {rpi5_zip} ({zip_size:.1f} MB)")
    packages["rpi5_package"] = str(rpi5_zip)

    return packages


# ─────────────────────────────────────────────────────────────
# SUMMARY PRINTER
# ─────────────────────────────────────────────────────────────

def print_export_summary(exported_files: dict):
    """
    بيطبع ملخص كل الملفات المصدرة وكيفية استخدامها.
    """
    print("\n" + "=" * 60)
    print("  EXPORT COMPLETE — Deployment Guide")
    print("=" * 60)

    print("\n  📁 Exported Files:")
    for fmt, path in exported_files.items():
        if path and Path(path).exists():
            size = os.path.getsize(path) / 1e6
            print(f"     {fmt:<15} : {Path(path).name} ({size:.1f} MB)")

    print("\n  🖥️  For Laptop Testing:")
    if "onnx_int8" in exported_files:
        print(f"     python predict.py --model {Path(exported_files['onnx_int8']).name} --source 0")

    print("\n  🍓 For Raspberry Pi 5:")
    print("     1. Copy rpi5_package.zip to Pi")
    print("     2. unzip rpi5_package.zip")
    print("     3. python version_pi.py --model best_int8.onnx")

    print("\n  📊 Performance Estimates on RPi5:")
    print("     ONNX FP32  : ~5-6   FPS (baseline)")
    print("     ONNX INT8  : ~10-15 FPS (use this!)")
    print("     NCNN INT8  : ~15-20 FPS (maximum performance)")

    print("\n  ⚠️  Important Notes:")
    print("     - Always use the SAME imgsz in export AND inference")
    print("     - INT8 model needs testing vs FP32 for your specific data")
    print("     - NCNN model needs version_pi.py adapted for NCNN calls")
    print("=" * 60 + "\n")


# ─────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────

def parse_args():
    parser = argparse.ArgumentParser(
        description="Smart Basket — Model Export Pipeline"
    )
    parser.add_argument(
        "--model",
        type=str,
        required=True,
        help="Path to trained model (.pt)"
    )
    parser.add_argument(
        "--formats",
        nargs="+",
        default=["onnx", "ncnn"],
        choices=["onnx", "ncnn", "int8", "tflite"],
        help="Export formats (default: onnx ncnn)"
    )
    parser.add_argument(
        "--imgsz",
        type=int,
        default=None,
        help="Export image size (default: 416)"
    )
    return parser.parse_args()


# ─────────────────────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    args = parse_args()

    print("\n" + "📦 " * 20)
    print("  Smart Basket — YOLO Export Pipeline")
    print("📦 " * 20)

    exported = run_export(args.model, args)

    if exported:
        print("\n  ✅ Export pipeline completed successfully!")
    else:
        print("\n  ❌ Export pipeline failed. Check errors above.")
