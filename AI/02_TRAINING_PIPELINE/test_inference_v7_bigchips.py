#!/usr/bin/env python3
"""
Smart Basket — Test Inference Script for V7 Can & Big Chips Model
"""

import os
import cv2
import numpy as np
from ultralytics import YOLO

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    model_path = os.path.abspath(os.path.join(base_dir, "..", "best.onnx"))
    
    if not os.path.exists(model_path):
        model_path = "yolov8n.pt"

    print(f"Testing inference with model: {model_path}")
    model = YOLO(model_path)
    
    # Run test on a valid image from dataset
    test_img = os.path.abspath(os.path.join(base_dir, "..", "dataset_v7_bigchips", "valid", "images", "sample_0000.jpg"))
    if not os.path.exists(test_img):
        print(f"Test image not found at {test_img}")
        return

    results = model.predict(test_img, conf=0.35, verbose=True)
    
    print("\n--- Detection Results ---")
    for r in results:
        boxes = r.boxes
        for box in boxes:
            cls_id = int(box.cls[0])
            conf = float(box.conf[0])
            name = model.names[cls_id] if hasattr(model, 'names') and cls_id in model.names else str(cls_id)
            print(f"Detected: Product '{name}' | Confidence: {conf*100:.1f}%")

if __name__ == "__main__":
    main()
