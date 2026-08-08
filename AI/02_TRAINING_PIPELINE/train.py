#!/usr/bin/env python3
"""
Smart Basket — Complete Training Script
========================================
الملف ده هو قلب التدريب بتاع مشروع Smart Basket.
بيشيل كل حاجة من تحميل الموديل لحد حفظ أفضل نتيجة.

ازاي تشغله:
  python train.py
  python train.py --model yolo26n --epochs 100 --batch 16
  python train.py --resume  (لو التدريب اتوقف في النص)

الـ Output هيكون في:
  runs/detect/smart_basket_v1/
    weights/
      best.pt   ← أفضل موديل (بنستخدمه)
      last.pt   ← آخر epoch
    results.csv ← كل الـ metrics
    confusion_matrix.png
    PR_curve.png
    labels.jpg
"""

# ─────────────────────────────────────────────────────────────
# IMPORTS
# ─────────────────────────────────────────────────────────────
import argparse          # بيقرأ الـ arguments من الـ command line
import os                # عمليات الـ file system
import sys               # بيتيح الخروج من البرنامج sys.exit()
import time              # قياس وقت التدريب
import shutil            # نسخ الملفات
from pathlib import Path # التعامل مع المسارات بطريقة حديثة

import torch             # PyTorch — المحرك الأساسي للـ neural networks
import yaml              # قراءة ملف data.yaml

from ultralytics import YOLO  # الـ YOLO framework نفسه


# ─────────────────────────────────────────────────────────────
# MODEL SELECTION — ليه YOLO26n؟
# ─────────────────────────────────────────────────────────────
"""
سؤال مهم: ليه YOLO26n مش YOLOv8n؟
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

YOLO26n (2026 - الأحدث) vs YOLOv8n (2023 - الأقدم)

المقارنة:
┌─────────────────┬──────────────┬──────────────┐
│ الخاصية         │ YOLO26n      │ YOLOv8n      │
├─────────────────┼──────────────┼──────────────┤
│ Parameters      │ 2.5M         │ 3.2M         │
│ GFLOPs          │ 5.8          │ 8.7          │
│ mAP@50 (COCO)   │ ~52%         │ ~49%         │
│ Speed (CPU)     │ أسرع         │ أبطأ         │
│ Architecture    │ C3k2 + C2PSA │ C2f          │
│ NMS             │ End-to-end   │ يحتاج NMS    │
└─────────────────┴──────────────┴──────────────┘

الخلاصة:
YOLO26n أصغر + أسرع + أدق من YOLOv8n
✅ مثالي للـ Raspberry Pi (موارد محدودة)

لو عندك منتجات أكتر من 100:
  استخدم yolo26s (11M params) — أدق بـ 3% على حساب السرعة

لو عندك HAILO accelerator:
  استخدم yolo26m (20M params) — دقة عالية جداً

الـ Family كامل:
  yolo26n → nano    (2.5M)   للـ Pi
  yolo26s → small   (11M)    للـ Pi + accelerator
  yolo26m → medium  (20M)    للـ edge server
  yolo26l → large   (43M)    للـ GPU server
  yolo26x → xlarge  (68M)    للـ datacenter
"""

# ─────────────────────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────────────────────
CONFIG = {
    # ─── MODEL ────────────────────────────────────────────────
    # اسم الموديل — YOLO هيحمل pretrained weights من COCO
    # COCO عنده 80 class — إحنا هنعمل fine-tune على 10 classes بتاعتنا
    # ميزة الـ pretrained: الموديل بيبدأ بمعرفة مسبقة بالأشكال والألوان
    # بيوصل لنتائج كويسة بمعادلة أقل بكتير من التدريب من الصفر
    "model": "yolo26n.pt",

    # ─── DATASET ──────────────────────────────────────────────
    # المسار لـ data.yaml — اللي بيعرّف الـ classes والمسارات
    "data": "data.yaml",

    # ─── TRAINING HYPERPARAMETERS ─────────────────────────────
    # epochs: عدد مرات مشاهدة الـ model للـ dataset كامل
    # كل epoch = model يشوف كل صورة في الـ training set مرة
    # لو epochs كتير جداً → overfitting (model حافظ مش فاهم)
    # لو epochs قليل → underfitting (model ما اتعلمش كويس)
    # 100 epochs مع patience=20 هو الـ sweet spot
    "epochs": 100,

    # imgsz: حجم الصورة عند التدريب (pixels)
    # الصور بتتـ resize لـ 640×640 قبل ما الـ model يشوفها
    # 640 هو الـ standard — توازن بين accuracy وsرعة
    # لو المنتجات صغيرة جداً في الفريم → جرب 1280 (بطيء أكتر)
    # لو عندك وقت وGPU محدود → جرب 416 (أسرع، دقة أقل قليلاً)
    "imgsz": 640,

    # batch: عدد الصور اللي الـ GPU بيشوفها مع بعض في خطوة واحدة
    # أكبر batch = أسرع تدريب + gradient أكثر استقراراً
    # أصغر batch = بيتناسب مع VRAM أقل
    #
    # قواعد البوم:
    #   GPU 4GB  → batch=8  أو 16
    #   GPU 8GB  → batch=16 أو 32
    #   GPU 16GB → batch=32 أو 64 (Tesla T4 على Colab)
    #   CPU only → batch=4  (بطيء جداً!)
    #
    # الـ -1 معناه: YOLO يحدد تلقائياً على حسب الـ VRAM المتاح
    "batch": -1,

    # patience: early stopping
    # لو الـ mAP ما تحسنش لـ 20 epochs متتالية → وقف التدريب
    # ده بيحمي من الـ overfitting ويوفر وقت
    # مثال: لو أحسن نتيجة كانت في epoch 55 وما تحسنتش لـ epoch 75
    #        التدريب بيوقف عند 75 مش 100
    "patience": 20,

    # ─── OPTIMIZER ────────────────────────────────────────────
    # optimizer: الـ algorithm اللي بيعدل أوزان الـ model
    #
    # MuSGD: ده optimizer خاص بـ YOLO26
    #   - يتعامل مع الـ learning rate بذكاء
    #   - أفضل من Adam لـ YOLO26
    #
    # Adam: خيار كلاسيكي كويس لـ YOLO8
    # SGD: الأساسي، بيحتاج learning rate tuning أكتر
    "optimizer": "MuSGD",

    # lr0: Initial Learning Rate (معدل التعلم الابتدائي)
    # ده بيحدد كبير إمتى تكون خطوة تعديل الأوزان
    # كبير جداً → تدريب غير مستقر، loss بيقفز
    # صغير جداً → تدريب بطيء جداً، ممكن يوقف في local minimum
    # 0.001 هو الـ default الكويس لـ fine-tuning
    "lr0": 0.001,

    # lrf: Learning Rate Final (نسبة)
    # الـ lr بيتقلل من lr0 لـ (lr0 × lrf) خلال التدريب
    # cosine schedule: بيقلل بشكل ناعم مش مفاجئ
    # 0.01 معناه: الـ lr هيوصل لـ 0.001 × 0.01 = 0.000010 في الآخر
    "lrf": 0.01,

    # momentum: بيحتفظ بـ "عجلة" من الخطوات السابقة
    # زي العربية في منحدر — بتاخد momentum وتكمل
    # 0.937 هو الـ default اللي Ultralytics اثبت كفاءته
    "momentum": 0.937,

    # weight_decay: بيعاقب الأوزان الكبيرة (L2 regularization)
    # بيمنع الـ overfitting — الموديل بيبقى أكثر generalization
    # 0.0005 قيمة مناسبة لمعظم الحالات
    "weight_decay": 0.0005,

    # ─── AUGMENTATION ─────────────────────────────────────────
    # كل قيمة دي بيأثر على تعقيد ووقت التدريب
    # الـ augmentation بيضاف online أثناء التدريب (مش بيحفظ صور جديدة)

    # mosaic: بيجمع 4 صور في صورة واحدة بـ random crop
    # مهم جداً لتعليم الموديل كشف منتجات صغيرة وكتيرة
    # 1.0 = دايماً شغال (100% من الصور)
    "mosaic": 1.0,

    # mixup: بيخلط صورتين مع بعض (alpha blending)
    # يعمل نوع من الـ regularization
    # 0.1 = 10% من الصور بس تتعمل لها mixup
    "mixup": 0.1,

    # copy_paste: بياخد object من صورة ويحطه في تانية
    # يحاكي scenarios مختلفة بدون تصوير إضافي
    "copy_paste": 0.1,

    # erasing: بيمسح جزء عشوائي من الصورة
    # يعلم الموديل التعرف من صورة ناقصة (occlusion)
    "erasing": 0.4,

    # fliplr: احتمال قلب الصورة أفقياً (mirror)
    # 0.5 = 50% من الصور بتتقلب — طبيعي للمنتجات الـ symmetric
    "fliplr": 0.5,

    # flipud: قلب عمودي — الـ 0.0 معناه معطل
    # منتجات السوبرماركت مش بتكون مقلوبة عادةً
    "flipud": 0.0,

    # degrees: rotation عشوائي (بالدرجات)
    # المنتجات في السلة ممكن تكون مدورة شوية (±10°)
    "degrees": 10.0,

    # scale: تكبير وتصغير عشوائي (نسبة)
    # 0.5 معناه: الصورة ممكن تتكبر أو تتصغر بـ ±50%
    # بيحاكي المنتجات في مسافات مختلفة
    "scale": 0.5,

    # translate: تحريك الصورة
    # 0.1 معناه: تحريك ±10% من أبعاد الصورة
    "translate": 0.1,

    # shear: تشويه perspective خفيف
    # 5.0 degrees ±
    "shear": 5.0,

    # HSV color space augmentation
    # hsv_h: تغيير الـ Hue (اللون الأساسي)
    # مهم جداً إن يكون صغير — Pepsi أزرق وCoca-Cola أحمر
    # لو كبرته الموديل هيخلط بينهم
    "hsv_h": 0.015,  # ±1.5% فقط

    # hsv_s: تغيير الـ Saturation (كثافة اللون)
    # 0.5 = يقدر يقلل أو يزيد الكثافة بـ 50%
    # يحاكي إضاءة مختلفة بتأثر على الكثافة
    "hsv_s": 0.5,

    # hsv_v: تغيير الـ Value (السطوع)
    # أهم augmentation للمشروع ده
    # يحاكي إضاءة ساطعة وإضاءة خافتة
    "hsv_v": 0.4,  # ±40% سطوع

    # close_mosaic: يوقف الـ mosaic في آخر N epochs
    # الـ mosaic ممكن يخلي الـ training غير مستقر في الآخر
    # إيقافه في آخر 10 epochs بيثبت الـ convergence
    "close_mosaic": 10,

    # ─── OUTPUT ───────────────────────────────────────────────
    # project: اسم المجلد الرئيسي للنتائج
    "project": "runs/detect",

    # name: اسم الـ experiment (هيتعمل مجلد بالاسم ده)
    # لو شغلت تدريبين بنفس الاسم: هيتعمل _2, _3, etc
    "name": "smart_basket_v1",

    # ─── MISC ─────────────────────────────────────────────────
    # device: أي hardware يستخدم
    # "0" = GPU الأول (لو عندك nvidia GPU)
    # "cpu" = CPU (بطيء جداً للتدريب)
    # "" (فاضي) = YOLO يحدد تلقائياً
    "device": "",

    # workers: عدد الـ CPU threads لتحميل الصور
    # أكتر workers = أسرع loading = GPU دايماً busy
    # 4 مناسب لمعظم الأجهزة
    "workers": 4,

    # cache: حفظ الصور في الذاكرة لسرعة أكتر
    # "ram" = حفظ في RAM (أسرع لو عندك RAM كتير)
    # "disk" = حفظ على SSD (أبطأ شوية بس أآمن)
    # False = بيقرأ من الـ disk كل مرة (أبطأ)
    # على Colab: "ram" — عندك 12GB RAM
    "cache": "ram",

    # amp: Automatic Mixed Precision
    # يستخدم float16 بدل float32 حيثما ممكن
    # بيقلل استهلاك VRAM بـ 50% ويسرع التدريب بـ 30-50%
    # مع نفس الدقة تقريباً
    # على GPU فقط — على CPU معطل تلقائياً
    "amp": True,

    # plots: يرسم الـ charts أثناء وبعد التدريب
    # loss curves, mAP curves, confusion matrix, etc
    "plots": True,

    # verbose: يطبع معلومات تفصيلية أثناء التدريب
    "verbose": True,

    # exist_ok: لو اسم الـ experiment موجود → استمر مش error
    "exist_ok": False,

    # seed: بيثبت الـ randomness للـ reproducibility
    # نفس الـ seed = نفس النتائج (لو نفس البيانات والموديل)
    "seed": 42,

    # pretrained: يبدأ من pretrained weights (COCO)
    # True = fine-tuning (ده اللي إحنا عايزينه)
    # False = training from scratch (بياخد وقت أكتر ومحتاج بيانات أكتر)
    "pretrained": True,
}


# ─────────────────────────────────────────────────────────────
# HELPER FUNCTIONS
# ─────────────────────────────────────────────────────────────

def check_environment():
    """
    بيتحقق إن البيئة مجهزة صح قبل التدريب.
    بيطبع معلومات مفيدة عن الـ hardware المتاح.
    """
    print("\n" + "=" * 60)
    print("  Smart Basket — Environment Check")
    print("=" * 60)

    # تحقق من PyTorch
    print(f"\n  PyTorch version : {torch.__version__}")

    # تحقق من الـ CUDA (GPU)
    cuda_available = torch.cuda.is_available()
    print(f"  CUDA available  : {cuda_available}")

    if cuda_available:
        gpu_count = torch.cuda.device_count()
        print(f"  GPU count       : {gpu_count}")
        for i in range(gpu_count):
            gpu_name = torch.cuda.get_device_name(i)
            gpu_mem  = torch.cuda.get_device_properties(i).total_memory / 1e9
            print(f"  GPU {i}           : {gpu_name} ({gpu_mem:.1f} GB)")
    else:
        print("  ⚠️  No GPU found — training will be very slow on CPU!")
        print("     Use Google Colab for GPU training.")

    # تحقق من الـ data.yaml
    data_path = Path(CONFIG["data"])
    if not data_path.exists():
        print(f"\n  ❌ ERROR: data.yaml not found at: {data_path.absolute()}")
        print("     Run this script from the directory containing data.yaml")
        sys.exit(1)
    else:
        print(f"\n  ✅ data.yaml found: {data_path.absolute()}")

    # اقرأ وتحقق من محتوى الـ YAML
    with open(data_path, "r") as f:
        data_cfg = yaml.safe_load(f)

    nc    = data_cfg.get("nc", 0)
    names = data_cfg.get("names", {})
    print(f"  ✅ Classes       : {nc} classes detected")
    for cls_id, cls_name in names.items():
        print(f"       {cls_id}: {cls_name}")

    if nc != len(names):
        print(f"\n  ❌ ERROR: nc={nc} but found {len(names)} class names. Fix data.yaml!")
        sys.exit(1)

    # تحقق من الـ dataset paths
    dataset_root = Path(data_cfg.get("path", "."))
    for split in ["train", "val", "test"]:
        split_path = dataset_root / data_cfg.get(split, "")
        if split_path.exists():
            img_count = len(list(split_path.glob("*.jpg")) +
                           list(split_path.glob("*.png")) +
                           list(split_path.glob("*.jpeg")))
            print(f"  ✅ {split:5s} images: {img_count} found at {split_path}")
        else:
            if split == "test":
                print(f"  ⚠️  test set not found (optional) — ok")
            else:
                print(f"  ❌ {split} images NOT found at {split_path}")
                sys.exit(1)

    print("\n" + "=" * 60 + "\n")


def save_training_config(save_dir: Path):
    """
    بيحفظ الـ config بتاع التدريب في ملف
    عشان تقدر تعيد التدريب بنفس الـ settings في المستقبل
    """
    config_path = save_dir / "training_config.yaml"
    with open(config_path, "w") as f:
        yaml.dump(CONFIG, f, default_flow_style=False)
    print(f"  ✅ Training config saved: {config_path}")


def print_results_summary(results):
    """
    بيطبع ملخص نتائج التدريب بطريقة مرتبة
    """
    print("\n" + "=" * 60)
    print("  TRAINING COMPLETE — Results Summary")
    print("=" * 60)

    # الـ metrics الأساسية
    metrics = results.results_dict

    print(f"\n  📊 Final Metrics (on validation set):")
    print(f"     mAP@50       : {metrics.get('metrics/mAP50(B)',    0):.4f}")
    print(f"     mAP@50-95    : {metrics.get('metrics/mAP50-95(B)', 0):.4f}")
    print(f"     Precision    : {metrics.get('metrics/precision(B)', 0):.4f}")
    print(f"     Recall       : {metrics.get('metrics/recall(B)',    0):.4f}")

    print(f"\n  📁 Results saved to: {results.save_dir}")
    print(f"     Best weights : {results.save_dir}/weights/best.pt")
    print(f"     Last weights : {results.save_dir}/weights/last.pt")
    print(f"     Metrics CSV  : {results.save_dir}/results.csv")

    # تقييم الأداء
    map50 = metrics.get("metrics/mAP50(B)", 0)
    if map50 >= 0.95:
        grade = "🟢 EXCELLENT — جاهز للـ deployment"
    elif map50 >= 0.90:
        grade = "🟡 GOOD — مقبول، ممكن تحسين بمزيد من البيانات"
    elif map50 >= 0.80:
        grade = "🟠 FAIR — محتاج مزيد من البيانات أو augmentation أقوى"
    else:
        grade = "🔴 POOR — راجع الـ dataset والـ labels"

    print(f"\n  Grade: {grade}")
    print("=" * 60 + "\n")


# ─────────────────────────────────────────────────────────────
# MAIN TRAINING FUNCTION
# ─────────────────────────────────────────────────────────────

def train(args):
    """
    الـ function الرئيسية للتدريب.
    كل الخطوات موثقة بالعربي.
    """

    # ── STEP 1: Environment Check ──────────────────────────────
    check_environment()

    # ── STEP 2: Override Config from CLI ──────────────────────
    # لو المستخدم بعت arguments من الـ command line، نحدث الـ config
    if args.model:    CONFIG["model"]   = args.model
    if args.epochs:   CONFIG["epochs"]  = args.epochs
    if args.batch:    CONFIG["batch"]   = args.batch
    if args.imgsz:    CONFIG["imgsz"]   = args.imgsz
    if args.device:   CONFIG["device"]  = args.device
    if args.name:     CONFIG["name"]    = args.name

    # ── STEP 3: Load Model ────────────────────────────────────
    print(f"  🔄 Loading model: {CONFIG['model']}")
    print(f"     (Downloading pretrained COCO weights if not cached...)")

    # لو args.resume → نكمل من آخر checkpoint
    if args.resume:
        # دور على آخر checkpoint محفوظ
        last_checkpoint = find_last_checkpoint(CONFIG["project"], CONFIG["name"])
        if last_checkpoint:
            print(f"  🔄 Resuming from: {last_checkpoint}")
            model = YOLO(last_checkpoint)
        else:
            print("  ⚠️  No checkpoint found, starting fresh...")
            model = YOLO(CONFIG["model"])
    else:
        model = YOLO(CONFIG["model"])
        # YOLO هيحمل الـ pretrained weights تلقائياً
        # لو الملف مش موجود محلياً → بيحمله من الإنترنت (حوالي 5MB)

    print(f"  ✅ Model loaded: {CONFIG['model']}")
    print(f"     Parameters   : {sum(p.numel() for p in model.model.parameters()):,}")

    # ── STEP 4: Start Training ────────────────────────────────
    print(f"\n  🚀 Starting training...")
    print(f"     Epochs       : {CONFIG['epochs']}")
    print(f"     Image size   : {CONFIG['imgsz']}×{CONFIG['imgsz']}")
    print(f"     Batch size   : {CONFIG['batch']} (auto if -1)")
    print(f"     Dataset      : {CONFIG['data']}")
    print(f"     Output dir   : {CONFIG['project']}/{CONFIG['name']}")

    t_start = time.time()

    # ── الـ YOLO .train() call ─────────────────────────────────
    # ده أهم سطر في الملف كله
    # كل الـ arguments موثقة فوق في CONFIG
    results = model.train(
        # ─── Dataset ─────────────────────────────────────────
        data         = CONFIG["data"],
        imgsz        = CONFIG["imgsz"],
        batch        = CONFIG["batch"],

        # ─── Training Schedule ───────────────────────────────
        epochs       = CONFIG["epochs"],
        patience     = CONFIG["patience"],
        pretrained   = CONFIG["pretrained"],

        # ─── Optimizer ───────────────────────────────────────
        optimizer    = CONFIG["optimizer"],
        lr0          = CONFIG["lr0"],
        lrf          = CONFIG["lrf"],
        momentum     = CONFIG["momentum"],
        weight_decay = CONFIG["weight_decay"],

        # ─── Geometric Augmentation ──────────────────────────
        fliplr       = CONFIG["fliplr"],
        flipud       = CONFIG["flipud"],
        degrees      = CONFIG["degrees"],
        scale        = CONFIG["scale"],
        translate    = CONFIG["translate"],
        shear        = CONFIG["shear"],
        perspective  = 0.0,         # بدون perspective distortion

        # ─── Photometric Augmentation ────────────────────────
        hsv_h        = CONFIG["hsv_h"],   # hue صغير (Pepsi vs Coke)
        hsv_s        = CONFIG["hsv_s"],   # saturation
        hsv_v        = CONFIG["hsv_v"],   # brightness (مهم جداً)

        # ─── Advanced Augmentation ───────────────────────────
        mosaic       = CONFIG["mosaic"],      # 4-image mosaic
        mixup        = CONFIG["mixup"],       # image blending
        copy_paste   = CONFIG["copy_paste"],  # object transplant
        erasing      = CONFIG["erasing"],     # random erasing
        close_mosaic = CONFIG["close_mosaic"],# stop mosaic near end

        # ─── Hardware ────────────────────────────────────────
        device       = CONFIG["device"],
        workers      = CONFIG["workers"],
        amp          = CONFIG["amp"],
        cache        = CONFIG["cache"],

        # ─── Output ──────────────────────────────────────────
        project      = CONFIG["project"],
        name         = CONFIG["name"],
        plots        = CONFIG["plots"],
        verbose      = CONFIG["verbose"],
        exist_ok     = CONFIG["exist_ok"],
        seed         = CONFIG["seed"],

        # ─── Loss Weights ────────────────────────────────────
        # الـ loss بيتكون من 3 أجزاء:
        # box_loss: مدى دقة الـ bounding box
        # cls_loss: مدى دقة الـ classification
        # dfl_loss: Distribution Focal Loss (للـ box regression)
        box          = 7.5,   # وزن الـ box loss
        cls          = 0.5,   # وزن الـ classification loss
        dfl          = 1.5,   # وزن الـ DFL loss

        # ─── Warmup ──────────────────────────────────────────
        # في أول N epochs، الـ learning rate بيبدأ صغير وبيكبر
        # ده بيمنع الـ gradient explosion في البداية
        warmup_epochs     = 3.0,   # عدد epochs الـ warmup
        warmup_momentum   = 0.8,   # momentum أثناء الـ warmup
        warmup_bias_lr    = 0.1,   # lr للـ bias weights في الـ warmup

        # ─── Resume ──────────────────────────────────────────
        resume       = args.resume,
    )

    t_end = time.time()
    duration = (t_end - t_start) / 3600  # convert to hours

    print(f"\n  ⏱️  Training completed in {duration:.2f} hours")

    # ── STEP 5: Save Config ───────────────────────────────────
    save_training_config(Path(results.save_dir))

    # ── STEP 6: Print Summary ────────────────────────────────
    print_results_summary(results)

    # ── STEP 7: Return Best Model Path ───────────────────────
    best_pt = Path(results.save_dir) / "weights" / "best.pt"
    print(f"\n  ✅ Best model: {best_pt}")
    print(f"     Use this file in validation.py, export.py\n")

    return str(best_pt)


# ─────────────────────────────────────────────────────────────
# HELPER: Find Last Checkpoint
# ─────────────────────────────────────────────────────────────

def find_last_checkpoint(project: str, name: str) -> str | None:
    """
    بيدور على آخر checkpoint محفوظ لـ experiment معين.
    بيستخدم في الـ --resume flag.
    """
    last_pt = Path(project) / name / "weights" / "last.pt"
    if last_pt.exists():
        return str(last_pt)
    return None


# ─────────────────────────────────────────────────────────────
# CLI ARGUMENT PARSER
# ─────────────────────────────────────────────────────────────

def parse_args():
    """
    بيقرأ الـ arguments من الـ command line.
    مثال:
      python train.py --model yolo26n --epochs 50 --batch 16
      python train.py --resume
      python train.py --device cpu  (للاختبار على laptop)
    """
    parser = argparse.ArgumentParser(
        description="Smart Basket — YOLO Training Pipeline",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python train.py
  python train.py --model yolo26n --epochs 100
  python train.py --resume
  python train.py --device cpu --batch 4 --epochs 5  (debug only)
        """
    )

    parser.add_argument(
        "--model",
        type=str,
        default=None,
        help="Model name or path (default: yolo26n.pt)"
    )
    parser.add_argument(
        "--epochs",
        type=int,
        default=None,
        help="Number of training epochs (default: 100)"
    )
    parser.add_argument(
        "--batch",
        type=int,
        default=None,
        help="Batch size, -1 for auto (default: -1)"
    )
    parser.add_argument(
        "--imgsz",
        type=int,
        default=None,
        help="Image size for training (default: 640)"
    )
    parser.add_argument(
        "--device",
        type=str,
        default=None,
        help="Device: '0', 'cpu', '0,1' (default: auto)"
    )
    parser.add_argument(
        "--name",
        type=str,
        default=None,
        help="Experiment name (default: smart_basket_v1)"
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Resume training from last checkpoint"
    )

    return parser.parse_args()


# ─────────────────────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    # ده بيتنفذ لما تشغل: python train.py
    # مش بيتنفذ لما ملف تاني يعمل import للـ train.py

    args = parse_args()

    print("\n" + "🛒 " * 20)
    print("  Smart Basket — YOLO26n Training Pipeline")
    print("🛒 " * 20)

    best_model_path = train(args)

    print("=" * 60)
    print("  NEXT STEPS:")
    print("=" * 60)
    print(f"  1. Validate  : python validation.py --model {best_model_path}")
    print(f"  2. Export    : python export.py --model {best_model_path}")
    print(f"  3. Predict   : python predict.py --model {best_model_path} --source 0")
    print("=" * 60 + "\n")
