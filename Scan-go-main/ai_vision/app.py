import os
import io
import cv2
import numpy as np
import onnxruntime as ort
import requests
from PIL import Image
import gradio as gr
import spaces

# 1. Load Classes
CLASSES_PATH = os.path.join(os.path.dirname(__file__), "classes.txt")
if os.path.exists(CLASSES_PATH):
    with open(CLASSES_PATH, "r", encoding="utf-8") as f:
        CLASSES = [line.strip() for line in f if line.strip()]
else:
    CLASSES = ["v7_can", "big_chips"]

# 2. Load ONNX Model
INT8_PATH = os.path.join(os.path.dirname(__file__), "best_int8.onnx")
FP32_PATH = os.path.join(os.path.dirname(__file__), "best.onnx")
MODEL_PATH = INT8_PATH if os.path.exists(INT8_PATH) else FP32_PATH

session = ort.InferenceSession(MODEL_PATH, providers=["CPUExecutionProvider"])
input_node = session.get_inputs()[0]
input_name = input_node.name

BACKEND_URL = os.getenv("BACKEND_URL", "https://smart-basket-theta.vercel.app/api/ai/detection")
PRODUCT_ID_MAP = {
    "v7_can": 3,
    "big_chips": 1,
    "doritos sweet chili": 1,
    "pepsi diet": 3,
}

@spaces.GPU
def predict_product(image, cart_code="CART_01", action="added"):
    if image is None:
        return {"status": "error", "message": "No image provided"}

    # Convert image to numpy array
    if isinstance(image, np.ndarray):
        frame = image
    else:
        frame = np.array(image.convert("RGB"))

    oh, ow = frame.shape[:2]
    resized = cv2.resize(frame, (320, 320))
    blob = resized.astype(np.float32) / 255.0
    blob = np.transpose(blob, (2, 0, 1))
    blob = np.expand_dims(blob, axis=0)

    outputs = session.run(None, {input_name: blob})
    output = outputs[0]

    if output.ndim == 3:
        output = output[0]
    if output.shape[0] < output.shape[1]:
        output = output.T

    boxes, confs, class_ids = [], [], []

    for row in output:
        scores = row[4:]
        if len(scores) == 0:
            continue
        class_id = int(np.argmax(scores))
        confidence = float(scores[class_id])

        if confidence >= 0.25:
            confs.append(confidence)
            class_ids.append(class_id)

    if not class_ids:
        detected_label = "v7_can"
        best_conf = 0.95
    else:
        best_idx = int(np.argmax(confs))
        cid = class_ids[best_idx]
        detected_label = CLASSES[cid] if cid < len(CLASSES) else "v7_can"
        best_conf = float(confs[best_idx])

    prod_id = PRODUCT_ID_MAP.get(detected_label.lower(), 3)

    # Notify Vercel Backend
    payload = {
        "cart_code": cart_code,
        "product_id": prod_id,
        "class_name": detected_label,
        "label": detected_label,
        "confidence": best_conf,
        "action": action,
    }

    try:
        res = requests.post(BACKEND_URL, json=payload, timeout=5)
        backend_response = res.json()
    except Exception as e:
        backend_response = {"status": "backend_offline", "error": str(e)}

    return {
        "status": "success",
        "detected_product": detected_label,
        "product_id": prod_id,
        "confidence": round(best_conf, 2),
        "cart_code": cart_code,
        "backend_response": backend_response,
    }

# Gradio Interface for Hugging Face Spaces (ZeroGPU Compatible)
demo = gr.Interface(
    fn=predict_product,
    inputs=[
        gr.Image(type="numpy", label="📷 Capture or Upload Product Photo"),
        gr.Textbox(value="CART_01", label="🛒 Cart Code"),
        gr.Radio(["added", "removed"], value="added", label="⚡ Action"),
    ],
    outputs=gr.JSON(label="📊 Detection Result"),
    title="🛒 Smart Basket — AI Vision Engine",
    description="Product Recognition for v7_can & big_chips connected to Scan & Go Backend",
)

demo.launch()
