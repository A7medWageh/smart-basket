# 🛒 Smart Basket — AI Subsystem Architecture & Documentation
**Project:** Smart Shopping Cart System  
**Module:** AI & Computer Vision Subsystem  

---

## 📁 Directory Structure Overview

The AI module directory has been organized into clear, structured, and production-ready components:

```
Smart-Basket/AI/
│
├── 01_DOCTOR_PRESENTATION_DEMO/    ← 🎓 Live Doctor Demo & Simulation
│   ├── run_doctor_demo.py          ← Interactive CLI Controller for Demo
│   └── doctor_app_demo.html        ← Flutter Mobile App Web Interface Simulator
│
├── 02_TRAINING_PIPELINE/           ← ⚙️ Complete Model Training & Export Pipeline
│   ├── Smart_Basket_Training.ipynb ← Google Colab Training Notebook
│   ├── train.py                    ← Standalone Training Script (YOLO26n)
│   ├── validation.py               ← Model Validation & Metrics Calculator
│   ├── predict.py                  ← Local Webcam / Image Prediction Script
│   ├── export.py                   ← ONNX FP32, INT8 & NCNN Exporter Script
│   ├── data.yaml                   ← Dataset Config File
│   └── requirements.txt            ← Python Dependencies List
│
└── 03_MODELS_AND_EXPORTS/          ← 📦 Model Weights & Deployment Packages
    ├── best.onnx                   ← ONNX FP32 Model (~9.2 MB)
    ├── best_int8.onnx              ← ONNX INT8 Quantized Model (~2.7 MB - Recommended)
    ├── laptop_package.zip          ← Desktop Testing Deployment Zip
    ├── rpi5_package.zip            ← Raspberry Pi 5 Deployment Zip
    ├── classes.txt                 ← Product Class Labels
    └── data.yaml                   ← Export Dataset Reference Config
```

---

## 🚀 Quick Execution Guide

### 1. For Doctor Presentation Demo:
Run the interactive CLI simulator:
```bash
python AI/01_DOCTOR_PRESENTATION_DEMO/run_doctor_demo.py
```
Open `doctor_app_demo.html` in your browser to view the real-time mobile app interface.

### 2. For Re-training Model:
Upload `Smart_Basket_Training.ipynb` to Google Colab with GPU T4 enabled.

### 3. For Raspberry Pi Deployment:
Extract `rpi5_package.zip` directly on your Raspberry Pi 5 environment.
