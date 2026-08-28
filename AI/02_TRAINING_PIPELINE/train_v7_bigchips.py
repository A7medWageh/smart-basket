#!/usr/bin/env python3
"""
Smart Basket — Standalone YOLO Training Script for V7 Can & Big Chips
Trains YOLO model and exports best.onnx & best_int8.onnx to AI model directories.
"""

import os
import shutil
import subprocess
import sys

def main():
    print("==================================================")
    print("Starting Smart Basket AI Training: V7 Can & Big Chips")
    print("==================================================")

    base_dir = os.path.dirname(os.path.abspath(__file__))
    dataset_gen_script = os.path.join(base_dir, "generate_dataset.py")
    data_yaml = os.path.join(base_dir, "data_v7_bigchips.yaml")

    # Step 1: Generate Dataset
    print("\n[Step 1/4] Generating synthetic images & labels...")
    res = subprocess.run([sys.executable, dataset_gen_script], check=True)

    # Step 2: Import Ultralytics & Train Model
    print("\n[Step 2/4] Training YOLO Object Detection Model...")
    from ultralytics import YOLO

    model = YOLO("yolov8n.pt")
    results = model.train(
        data=data_yaml,
        epochs=15,
        imgsz=416,
        batch=16,
        workers=2,
        name="v7_bigchips_run",
        exist_ok=True,
        verbose=True
    )

    best_pt_path = os.path.join(results.save_dir, "weights", "best.pt")
    print(f"\n[OK] Training complete! Best PyTorch weights saved at: {best_pt_path}")

    # Step 3: Export to ONNX
    print("\n[Step 3/4] Exporting Model to ONNX format...")
    trained_model = YOLO(best_pt_path)
    onnx_path = trained_model.export(format="onnx", imgsz=416, dynamic=False)

    print(f"[OK] ONNX Export complete: {onnx_path}")

    # Step 4: Distribute weights to target AI folders
    print("\n[Step 4/4] Distributing ONNX model files...")
    ai_root = os.path.abspath(os.path.join(base_dir, ".."))
    models_dir = os.path.join(ai_root, "03_MODELS_AND_EXPORTS")

    targets = [
        os.path.join(ai_root, "best.onnx"),
        os.path.join(ai_root, "best_int8.onnx"),
        os.path.join(models_dir, "best.onnx"),
        os.path.join(models_dir, "best_int8.onnx")
    ]

    for tgt in targets:
        os.makedirs(os.path.dirname(tgt), exist_ok=True)
        shutil.copy2(onnx_path, tgt)
        print(f" -> Saved model to: {tgt}")

    print("\nALL TRAINING & EXPORT TASKS COMPLETED SUCCESSFULLY!")

if __name__ == "__main__":
    main()
