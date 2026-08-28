#!/usr/bin/env python3
"""
Smart Basket — Synthetic Dataset Generator for V7 Can & Big Chips
Generates labeled training/validation images with bounding boxes for YOLO training.
"""

import os
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

DATASET_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "dataset_v7_bigchips"))
CLASSES = ["v7_can", "big_chips"]
IMG_SIZE = (640, 640)

def create_background():
    """Generates varied background textures (wood, marble, shelf, desk)."""
    bg_type = random.choice(["wood", "shelf", "marble", "solid", "gradient"])
    img = Image.new("RGB", IMG_SIZE)
    draw = ImageDraw.Draw(img)
    
    if bg_type == "solid":
        c = (random.randint(180, 240), random.randint(180, 240), random.randint(180, 240))
        draw.rectangle([0, 0, IMG_SIZE[0], IMG_SIZE[1]], fill=c)
    elif bg_type == "gradient":
        c1 = np.array([random.randint(150, 230) for _ in range(3)])
        c2 = np.array([random.randint(150, 230) for _ in range(3)])
        arr = np.zeros((IMG_SIZE[1], IMG_SIZE[0], 3), dtype=np.uint8)
        for y in range(IMG_SIZE[1]):
            r = y / IMG_SIZE[1]
            arr[y, :] = (c1 * (1 - r) + c2 * r).astype(np.uint8)
        img = Image.fromarray(arr)
    elif bg_type == "wood":
        base = (random.randint(160, 200), random.randint(110, 150), random.randint(70, 110))
        draw.rectangle([0, 0, IMG_SIZE[0], IMG_SIZE[1]], fill=base)
        for _ in range(30):
            y = random.randint(0, IMG_SIZE[1])
            c = (base[0] - random.randint(10, 30), base[1] - random.randint(10, 30), base[2] - random.randint(10, 20))
            draw.line([(0, y), (IMG_SIZE[0], y + random.randint(-20, 20))], fill=c, width=random.randint(1, 4))
    else:
        draw.rectangle([0, 0, IMG_SIZE[0], IMG_SIZE[1]], fill=(random.randint(210, 240), random.randint(210, 240), random.randint(210, 240)))
        for x in range(0, IMG_SIZE[0], random.randint(60, 120)):
            draw.line([(x, 0), (x, IMG_SIZE[1])], fill=(170, 170, 170), width=2)
        for y in range(0, IMG_SIZE[1], random.randint(60, 120)):
            draw.line([(0, y)], fill=(170, 170, 170), width=2)
            
    if random.random() > 0.5:
        img = img.filter(ImageFilter.GaussianBlur(radius=random.uniform(0.5, 1.5)))
    return img

def render_v7_can():
    """Renders a metallic V7 Can beverage item PNG with alpha channel."""
    can_w = random.randint(120, 180)
    can_h = int(can_w * random.uniform(2.1, 2.4))
    
    can = Image.new("RGBA", (can_w, can_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(can)
    
    main_color = random.choice([
        (25, 25, 30),     # Black V7
        (180, 20, 30),    # Red V7
        (220, 160, 20),   # Gold V7
        (20, 120, 200)    # Blue V7
    ])
    
    draw.rounded_rectangle([5, 10, can_w - 5, can_h - 10], radius=15, fill=main_color)
    draw.ellipse([5, 5, can_w - 5, 25], fill=(200, 205, 210), outline=(150, 155, 160), width=2)
    draw.ellipse([can_w//2 - 10, 10, can_w//2 + 10, 20], fill=(160, 165, 170))
    
    streak_w = max(4, can_w // 6)
    draw.rectangle([can_w//4, 15, can_w//4 + streak_w, can_h - 15], fill=(255, 255, 255, 60))
    
    try:
        font = ImageFont.truetype("arial.ttf", int(can_w * 0.4))
        font_sm = ImageFont.truetype("arial.ttf", int(can_w * 0.15))
    except Exception:
        font = ImageFont.load_default()
        font_sm = font
        
    draw.text((can_w * 0.25, can_h * 0.3), "V7", fill=(255, 215, 0), font=font)
    draw.text((can_w * 0.2, can_h * 0.65), "ENERGY", fill=(255, 255, 255), font=font_sm)
    draw.ellipse([5, can_h - 20, can_w - 5, can_h - 5], fill=(170, 175, 180))
    
    return can

def render_big_chips():
    """Renders a Big Chips bag PNG with alpha channel."""
    bag_w = random.randint(160, 230)
    bag_h = int(bag_w * random.uniform(1.3, 1.6))
    
    bag = Image.new("RGBA", (bag_w, bag_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(bag)
    
    bg_color = random.choice([
        (230, 40, 30),    # Red Chili Big Chips
        (240, 170, 20),   # Cheese Big Chips
        (30, 140, 50),    # Ketchup/Vinegar Big Chips
    ])
    
    draw.rounded_rectangle([10, 10, bag_w - 10, bag_h - 10], radius=25, fill=bg_color)
    
    for y in [10, bag_h - 20]:
        for x in range(10, bag_w - 10, 8):
            draw.line([(x, y), (x + 4, y + 10)], fill=(120, 20, 20), width=2)
            
    draw.rectangle([15, int(bag_h * 0.25), bag_w - 15, int(bag_h * 0.55)], fill=(255, 255, 255, 220))
    
    try:
        font_big = ImageFont.truetype("arialbd.ttf", int(bag_w * 0.22))
        font_sub = ImageFont.truetype("arial.ttf", int(bag_w * 0.12))
    except Exception:
        font_big = ImageFont.load_default()
        font_sub = font_big
        
    draw.text((bag_w * 0.1, bag_h * 0.27), "BIG", fill=(200, 20, 20), font=font_big)
    draw.text((bag_w * 0.1, bag_h * 0.42), "CHIPS", fill=(20, 20, 20), font=font_big)
    
    draw.ellipse([bag_w*0.3, bag_h*0.62, bag_w*0.7, bag_h*0.82], fill=(245, 205, 50), outline=(200, 150, 20), width=3)
    draw.ellipse([bag_w*0.15, bag_h*0.7, bag_w*0.5, bag_h*0.88], fill=(245, 200, 40), outline=(190, 140, 10), width=2)
    
    return bag

def generate_sample(sample_id, split):
    bg = create_background()
    num_items = random.choice([1, 1, 2])
    labels = []
    
    for _ in range(num_items):
        cls_id = random.choice([0, 1])
        if cls_id == 0:
            item_img = render_v7_can()
        else:
            item_img = render_big_chips()
            
        angle = random.uniform(-25, 25)
        item_img = item_img.rotate(angle, expand=True, resample=Image.BICUBIC)
        
        iw, ih = item_img.size
        max_x = IMG_SIZE[0] - iw - 10
        max_y = IMG_SIZE[1] - ih - 10
        if max_x <= 10 or max_y <= 10:
            continue
            
        x = random.randint(10, max_x)
        y = random.randint(10, max_y)
        
        bg.paste(item_img, (x, y), item_img)
        
        x_center = (x + iw / 2.0) / IMG_SIZE[0]
        y_center = (y + ih / 2.0) / IMG_SIZE[1]
        norm_w = iw / IMG_SIZE[0]
        norm_h = ih / IMG_SIZE[1]
        
        labels.append(f"{cls_id} {x_center:.6f} {y_center:.6f} {norm_w:.6f} {norm_h:.6f}")
        
    img_dir = os.path.join(DATASET_DIR, split, "images")
    lbl_dir = os.path.join(DATASET_DIR, split, "labels")
    os.makedirs(img_dir, exist_ok=True)
    os.makedirs(lbl_dir, exist_ok=True)
    
    filename = f"sample_{sample_id:04d}"
    bg.save(os.path.join(img_dir, f"{filename}.jpg"), quality=92)
    with open(os.path.join(lbl_dir, f"{filename}.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(labels))

def main():
    print(f"Generating V7 Can & Big Chips dataset at: {DATASET_DIR}")
    random.seed(42)
    for i in range(120):
        generate_sample(i, "train")
    for i in range(30):
        generate_sample(i, "valid")
    print("Dataset generation complete!")

if __name__ == "__main__":
    main()
