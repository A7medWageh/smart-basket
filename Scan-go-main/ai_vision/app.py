import io
import os
import cv2
import numpy as np
import onnxruntime as ort
from PIL import Image
from fastapi import FastAPI, File, UploadFile, Query, Request
import requests

app = FastAPI(title="Scan & Go - AI Vision Service")

# 1. Load Classes
CLASSES_PATH = os.path.join(os.path.dirname(__file__), "classes.txt")
if os.path.exists(CLASSES_PATH):
    with open(CLASSES_PATH, "r", encoding="utf-8") as f:
        CLASSES = [line.strip() for line in f if line.strip()]
else:
    CLASSES = [
        "doritos sweet chili",
        "indomie chicken curry",
        "pepsi diet",
        "tea el_arosa"
    ]

# 2. Load ONNX Model
MODEL_PATH = os.path.join(os.path.dirname(__file__), "best.onnx")
opts = ort.SessionOptions()
opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
opts.intra_op_num_threads = 4

session = ort.InferenceSession(MODEL_PATH, sess_options=opts, providers=["CPUExecutionProvider"])
input_node = session.get_inputs()[0]
input_name = input_node.name
output_name = session.get_outputs()[0].name

# Detect model input size dynamically (e.g. 320x320 vs 640x640)
try:
    MODEL_INPUT_SIZE = int(input_node.shape[2])
    if MODEL_INPUT_SIZE <= 0:
        MODEL_INPUT_SIZE = 320
except Exception:
    MODEL_INPUT_SIZE = 320

# 3. Backend URL (can be overridden via environment variable)
BACKEND_URL = os.getenv("BACKEND_URL", "https://cytoplast-courier-dandelion.ngrok-free.dev/api/ai/detection")

print(f"✅ [AI Service] Model loaded successfully from {MODEL_PATH}")
print(f"📐 [AI Service] Model Input Dimensions: {input_node.shape} -> target: {MODEL_INPUT_SIZE}x{MODEL_INPUT_SIZE}")
print(f"📦 [AI Service] Supported Classes: {CLASSES}")
print(f"📡 [AI Service] Target Backend API: {BACKEND_URL}")


def preprocess_image(image_bytes: bytes, input_size: int = MODEL_INPUT_SIZE):
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    frame = np.array(image)
    oh, ow = frame.shape[:2]
    scale = input_size / max(oh, ow)
    nw, nh = int(ow * scale), int(oh * scale)
    resized = cv2.resize(frame, (nw, nh), interpolation=cv2.INTER_LINEAR)

    canvas = np.full((input_size, input_size, 3), 114, dtype=np.uint8)
    pad_top = (input_size - nh) // 2
    pad_left = (input_size - nw) // 2
    canvas[pad_top:pad_top + nh, pad_left:pad_left + nw] = resized

    blob = canvas.transpose(2, 0, 1).astype(np.float32) / 255.0
    blob = np.expand_dims(blob, axis=0)
    return blob


@app.get("/")
def home():
    return {
        "status": "Online",
        "service": "Scan & Go AI Vision Service",
        "model_input_size": MODEL_INPUT_SIZE,
        "classes": CLASSES,
        "backend_url": BACKEND_URL
    }


@app.post("/predict")
async def predict_product(
    request: Request,
    cart_code: str = Query("CART_01"),
    action: str = Query("added")
):
    try:
        # Check if received as multipart form-data or raw bytes from ESP32
        content_type = request.headers.get("content-type", "")
        
        if "multipart/form-data" in content_type:
            form = await request.form()
            image_file = form.get("image")
            if not image_file:
                return {"success": False, "message": "Missing 'image' file field"}
            contents = await image_file.read()
        else:
            # Raw bytes directly from ESP32
            contents = await request.body()

        if not contents or len(contents) == 0:
            return {"success": False, "message": "Empty image payload received"}

        # 1. Preprocess using model's exact input size (320x320)
        blob = preprocess_image(contents, MODEL_INPUT_SIZE)
        outputs = session.run([output_name], {input_name: blob})[0]

        predictions = outputs[0]
        if predictions.shape[0] < predictions.shape[1]:
            predictions = predictions.T

        # predictions format: [x, y, w, h, class0_score, class1_score, ...]
        scores = predictions[:, 4:]
        if scores.shape[1] == 0:
            return {"success": False, "message": "No classification scores found in model output"}

        class_ids = np.argmax(scores, axis=1)
        confidences = np.max(scores, axis=1)

        best_idx = np.argmax(confidences)
        best_conf = float(confidences[best_idx])
        best_class_id = int(class_ids[best_idx])

        if best_class_id < len(CLASSES):
            best_class = CLASSES[best_class_id]
        else:
            best_class = f"product_{best_class_id}"

        print(f"🎯 [Prediction] Detected: {best_class} (Confidence: {best_conf:.2f}) for Cart {cart_code}")

        if best_conf < 0.35:
            return {
                "success": False,
                "message": f"Confidence too low ({best_conf:.2f}). Item not recognized with certainty.",
                "detected": best_class,
                "confidence": round(best_conf, 2)
            }

        # 2. Automatically notify your Backend to sync cart with mobile app!
        backend_payload = {
            "cart_code": cart_code,
            "label": best_class,
            "confidence": round(best_conf, 2),
            "action": action
        }

        backend_res_data = None
        try:
            res = requests.post(BACKEND_URL, json=backend_payload, timeout=4)
            backend_res_data = res.json()
            print(f"📡 [Backend Sync] Notified Backend successfully -> Status: {res.status_code}")
        except Exception as err:
            print(f"⚠️ [Backend Sync Error]: {err}")
            backend_res_data = {"error": f"Failed to notify backend: {str(err)}"}

        return {
            "success": True,
            "cart_code": cart_code,
            "detected_product": best_class,
            "confidence": round(best_conf, 2),
            "backend_response": backend_res_data
        }

    except Exception as e:
        print(f"❌ [AI Error]: {e}")
        return {"success": False, "error": str(e)}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
