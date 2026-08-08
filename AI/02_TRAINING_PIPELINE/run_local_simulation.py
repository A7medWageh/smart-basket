#!/usr/bin/env python3
"""
Smart Basket — Local Full System Simulator (Fixed Event Loop)
============================================================
السكريبت المحسن ليتوافق مع أحدث إصدار من websockets و Python asyncio.
"""

import sys
import os
import time
import json
import asyncio
import threading
from collections import Counter

try:
    import websockets
except ImportError:
    print("🔄 جاري تثبيت مكتبة websockets الخفيفة...")
    os.system(f"{sys.executable} -m pip install websockets --trusted-host pypi.org --trusted-host files.pythonhosted.org")
    import websockets

PORT = 8765

PRICE_MAP = {
    "pepsi_can": {"name": "Pepsi Can", "price": 12.0},
    "coca_cola_can": {"name": "Coca-Cola Can", "price": 12.0},
    "chips_bag": {"name": "Doritos Chips", "price": 10.0},
    "indomie": {"name": "Indomie Noodles", "price": 8.0},
    "water_bottle": {"name": "Water Bottle", "price": 5.0},
    "chocolate_bar": {"name": "Chocolate Bar", "price": 15.0},
    "juice_box": {"name": "Juice Box", "price": 15.0},
    "milk_carton": {"name": "Milk Carton", "price": 20.0}
}

current_basket = Counter()
latest_payload = {"items": {}, "total_price": 0.0}
CONNECTED_CLIENTS = set()
MAIN_LOOP = None

# ─── WEBSOCKET HANDLER ────────────────────────────────
async def ws_handler(websocket):
    CONNECTED_CLIENTS.add(websocket)
    print("\n🟢 تم اتصال واجهة الموبايل (simulator_app.html) بنجاح!")
    await websocket.send(json.dumps(latest_payload))
    try:
        async for message in websocket:
            pass
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        CONNECTED_CLIENTS.remove(websocket)
        print("\n🔴 تم قطع اتصال الواجهة.")

async def broadcast_state(payload):
    if CONNECTED_CLIENTS:
        message = json.dumps(payload)
        await asyncio.gather(*[client.send(message) for client in CONNECTED_CLIENTS], return_exceptions=True)

async def start_ws_server():
    async with websockets.serve(ws_handler, "localhost", PORT):
        print(f"🚀 خادم محاكاة السلة الذكية شغال على: ws://localhost:{PORT}")
        await asyncio.Future()  # run forever

def run_event_loop(loop):
    asyncio.set_event_loop(loop)
    loop.run_until_complete(start_ws_server())

def update_and_broadcast():
    global latest_payload
    items_payload = {}
    total_price = 0.0

    for item_key, qty in current_basket.items():
        if qty > 0:
            info = PRICE_MAP.get(item_key, {"name": item_key.title(), "price": 10.0})
            price = info["price"]
            total_price += price * qty
            items_payload[item_key] = {
                "name": info["name"],
                "quantity": qty,
                "price": price
            }

    latest_payload = {
        "items": items_payload,
        "total_price": total_price
    }
    if MAIN_LOOP and MAIN_LOOP.is_running():
        asyncio.run_coroutine_threadsafe(broadcast_state(latest_payload), MAIN_LOOP)

# ─── INTERACTIVE TERMINAL SIMULATOR ──────────────────
def run_interactive_simulation():
    print("\n" + "="*60)
    print("🛒 محاكاة السلة الذكية (Smart Basket Interactive Simulator)")
    print("="*60)
    print("👉 افتح ملف simulator_app.html في متصفحك لمشاهدة التحديثات مباشرة!")
    print("\nالمنتجات المتاحة للمحاكاة:")
    
    keys = list(PRICE_MAP.keys())
    for idx, k in enumerate(keys, 1):
        print(f"  [{idx}] إضافة/زيادة {PRICE_MAP[k]['name']} ({PRICE_MAP[k]['price']} ج.م)")

    print("  [r] مسح/تفريغ السلة بالكامل")
    print("  [q] خروج من المحاكاة\n")

    while True:
        try:
            cmd = input("أدخل رقم المنتج لإضافته للسلة (أو r للتفريغ / q للخروج): ").strip().lower()
            if cmd == 'q':
                print("👋 تم إغلاق المحاكاة.")
                os._exit(0)
            elif cmd == 'r':
                current_basket.clear()
                print("🧹 تم تفريغ السلة بالكامل!")
                update_and_broadcast()
            elif cmd.isdigit():
                idx = int(cmd) - 1
                if 0 <= idx < len(keys):
                    item_key = keys[idx]
                    current_basket[item_key] += 1
                    print(f"✅ تم وضع {PRICE_MAP[item_key]['name']} في السلة! (العدد الحالي: {current_basket[item_key]})")
                    update_and_broadcast()
                else:
                    print("⚠️ رقم غير صحيح!")
            else:
                print("⚠️ أمر غير معروف!")
        except (KeyboardInterrupt, EOFError):
            break

if __name__ == "__main__":
    MAIN_LOOP = asyncio.new_event_loop()
    ws_thread = threading.Thread(target=run_event_loop, args=(MAIN_LOOP,), daemon=True)
    ws_thread.start()
    time.sleep(0.5)
    run_interactive_simulation()
