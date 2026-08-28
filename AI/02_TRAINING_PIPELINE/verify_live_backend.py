#!/usr/bin/env python3
"""
Smart Basket — Live Backend Verification Script
Tests sending detected product payloads (v7_can and big_chips) to the live ngrok backend server.
"""

import sys
import requests

LIVE_BACKEND_URL = "https://cytoplast-courier-dandelion.ngrok-free.dev/api/ai/detection"

def test_product_detection(class_name, product_id, confidence=0.98):
    print(f"\n📡 Sending test detection event for product: '{class_name}' (ID: {product_id})...")
    payload = {
        "cart_code": "CART_01",
        "product_id": product_id,
        "class_name": class_name,
        "confidence": confidence,
        "action": "added"
    }
    headers = {
        "Content-Type": "application/json",
        "ngrok-skip-browser-warning": "true"
    }

    try:
        res = requests.post(LIVE_BACKEND_URL, json=payload, headers=headers, timeout=8)
        print(f"✅ Response Status Code: {res.status_code}")
        data = res.json()
        print(f"✅ Server Response Message: {data.get('message')}")
        if "data" in data and "cart" in data["data"]:
            cart = data["data"]["cart"]
            print(f"🛒 Cart Items Count : {cart.get('itemsCount')}")
            print(f"💰 Cart Subtotal    : ${cart.get('subtotal')}")
            print(f"💳 Cart Grand Total : ${cart.get('grandTotal')}")
            print("📦 Active Cart Items:")
            for item in cart.get('items', []):
                print(f"   - {item.get('nameEn')} (x{item.get('quantity')}) -> ${item.get('totalPrice')}")
    except Exception as e:
        print(f"❌ Error connecting to live backend: {e}")

def main():
    print("="*60)
    print("🔥 Smart Basket Live Backend Connection Test")
    print(f"🔗 Target Server: {LIVE_BACKEND_URL}")
    print("="*60)

    # Test Product 1: v7_can (ID: 3)
    test_product_detection("v7_can", product_id=3, confidence=0.99)

    # Test Product 2: big_chips (ID: 1)
    test_product_detection("big_chips", product_id=1, confidence=0.97)

    print("\n🎉 LIVE BACKEND VERIFICATION COMPLETE!")

if __name__ == "__main__":
    main()
