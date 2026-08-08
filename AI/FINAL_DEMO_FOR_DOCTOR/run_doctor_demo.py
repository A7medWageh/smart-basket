#!/usr/bin/env python3
"""
Smart Basket — Standalone Live Doctor Demo Engine (English Output)
=================================================================
English interface to prevent PowerShell Arabic text flipping.
"""

import sys
import os
import time
import json
import asyncio
import threading
from collections import Counter

# Import websockets
try:
    import websockets
except ImportError:
    os.system(f"{sys.executable} -m pip install websockets --trusted-host pypi.org --trusted-host files.pythonhosted.org")
    import websockets

PORT = 8765

# Product catalog for doctor presentation
PRODUCTS = {
    "1": {"id": "pepsi_can", "name": "Pepsi Can", "price": 12.0},
    "2": {"id": "coca_cola_can", "name": "Coca-Cola Can", "price": 12.0},
    "3": {"id": "chips_bag", "name": "Doritos Chips", "price": 10.0},
    "4": {"id": "indomie", "name": "Indomie Noodles", "price": 8.0},
    "5": {"id": "water_bottle", "name": "Nestle Water Bottle", "price": 5.0},
    "6": {"id": "chocolate_bar", "name": "KitKat Chocolate", "price": 15.0},
    "7": {"id": "juice_box", "name": "Juhayna Juice", "price": 15.0},
    "8": {"id": "milk_carton", "name": "Juhayna Milk", "price": 20.0}
}

current_basket = Counter()
latest_payload = {"items": {}, "total_price": 0.0, "total_items": 0}
CONNECTED_CLIENTS = set()
MAIN_LOOP = None

# ─── WEBSOCKET SERVER ─────────────────────────────────
async def ws_handler(websocket):
    CONNECTED_CLIENTS.add(websocket)
    print("\n🟢 [SUCCESS] Flutter Mobile App Simulator connected successfully!")
    await websocket.send(json.dumps(latest_payload))
    try:
        async for message in websocket:
            pass
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        CONNECTED_CLIENTS.remove(websocket)
        print("\n🔴 [DISCONNECT] App Interface disconnected.")

async def broadcast_state(payload):
    if CONNECTED_CLIENTS:
        message = json.dumps(payload)
        await asyncio.gather(*[client.send(message) for client in CONNECTED_CLIENTS], return_exceptions=True)

async def start_ws_server():
    async with websockets.serve(ws_handler, "localhost", PORT):
        print(f"🚀 AI Engine running live at: ws://localhost:{PORT}")
        await asyncio.Future()

def run_event_loop(loop):
    asyncio.set_event_loop(loop)
    loop.run_until_complete(start_ws_server())

def update_and_broadcast():
    global latest_payload
    items_payload = {}
    total_price = 0.0
    total_items = 0

    for item_id, qty in current_basket.items():
        if qty > 0:
            info = next((v for v in PRODUCTS.values() if v["id"] == item_id), {"name": item_id, "price": 10.0})
            price = info["price"]
            total_price += price * qty
            total_items += qty
            items_payload[item_id] = {
                "name": info["name"],
                "quantity": qty,
                "price": price
            }

    latest_payload = {
        "items": items_payload,
        "total_price": total_price,
        "total_items": total_items
    }
    if MAIN_LOOP and MAIN_LOOP.is_running():
        asyncio.run_coroutine_threadsafe(broadcast_state(latest_payload), MAIN_LOOP)

# ─── INTERACTIVE CONTROLLER ───────────────────────────
def run_demo_controller():
    print("\n" + "="*65)
    print("🎓 SMART BASKET — DOCTOR PRESENTATION LIVE DEMO")
    print("="*65)
    print("📌 Step 1: Open (doctor_app_demo.html) in your browser to view mobile screen.")
    print("📌 Step 2: Select a product number below to simulate camera detection.\n")
    print("Available Products List:")
    
    for k, v in PRODUCTS.items():
        print(f"  [{k}] Add/Detect: {v['name']:<22} ─── Price: {v['price']} EGP")

    print("\nControl Commands:")
    print("  [r] Reset/Empty Basket")
    print("  [q] Quit Demo\n")

    while True:
        try:
            cmd = input("👉 Enter Product Number or Command: ").strip().lower()
            if cmd == 'q':
                print("👋 Demo closed.")
                os._exit(0)
            elif cmd == 'r':
                current_basket.clear()
                print("🧹 Basket reset successfully! Total: 0.00 EGP")
                update_and_broadcast()
            elif cmd in PRODUCTS:
                prod = PRODUCTS[cmd]
                current_basket[prod["id"]] += 1
                print(f"✅ [AI DETECTED] Product: {prod['name']} | Cart Quantity: {current_basket[prod['id']]}")
                update_and_broadcast()
            else:
                print("⚠️ Invalid Option! Enter a number from 1 to 8, or 'r' to reset, 'q' to quit.")
        except (KeyboardInterrupt, EOFError):
            break

if __name__ == "__main__":
    MAIN_LOOP = asyncio.new_event_loop()
    ws_thread = threading.Thread(target=run_event_loop, args=(MAIN_LOOP,), daemon=True)
    ws_thread.start()
    time.sleep(0.5)
    run_demo_controller()
