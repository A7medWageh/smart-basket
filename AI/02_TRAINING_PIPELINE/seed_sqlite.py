#!/usr/bin/env python3
import os
import sqlite3

db_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "Scan-go-main", "backend", "prisma", "dev.db"))
os.makedirs(os.path.dirname(db_path), exist_ok=True)

print(f"Creating SQLite database at: {db_path}")

conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Create Tables
cur.executescript("""
CREATE TABLE IF NOT EXISTS User (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    password TEXT NOT NULL,
    faceEnrolled BOOLEAN NOT NULL DEFAULT 0,
    faceEnrolledAt DATETIME,
    createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS Product (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nameAr TEXT NOT NULL,
    nameEn TEXT NOT NULL,
    barcode TEXT UNIQUE NOT NULL,
    category TEXT NOT NULL,
    imageUrl TEXT NOT NULL,
    unitPrice REAL NOT NULL,
    weightGrams INTEGER,
    stockQuantity INTEGER NOT NULL DEFAULT 100,
    isAvailable BOOLEAN NOT NULL DEFAULT 1,
    createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ShoppingSession (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    userId INTEGER NOT NULL,
    cartCode TEXT UNIQUE NOT NULL,
    cartStatus TEXT NOT NULL DEFAULT 'IN_USE',
    sessionStatus TEXT NOT NULL DEFAULT 'ACTIVE',
    faceVerified BOOLEAN NOT NULL DEFAULT 0,
    faceVerifiedAt DATETIME,
    startedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    endedAt DATETIME,
    FOREIGN KEY(userId) REFERENCES User(id)
);

CREATE TABLE IF NOT EXISTS CartItem (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sessionId INTEGER NOT NULL,
    productId INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    unitPrice REAL NOT NULL,
    totalPrice REAL NOT NULL,
    detectedBy TEXT NOT NULL DEFAULT 'AI',
    addedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(sessionId) REFERENCES ShoppingSession(id),
    FOREIGN KEY(productId) REFERENCES Product(id)
);
""")

# Seed Initial User
cur.execute("INSERT OR IGNORE INTO User (id, name, email, password) VALUES (1, 'Ahmed Wageh', 'ahmed@scango.com', 'password123')")

# Seed Products
products = [
    (1, 'دوريتوس فلفل حلو (Sweet Chili)', 'Doritos Sweet Chili 95g', '6221001004', 'سناكس / Snacks', 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=500', 20.0, 95),
    (2, 'إندومي فراخ كاري (Chicken Curry)', 'Indomie Chicken Curry 70g', '6221001010', 'وجبات سريعة / Instant Noodles', 'https://images.unsplash.com/photo-1612929633738-8fe44f7ec841?w=500', 10.0, 70),
    (3, 'كانز V7 أناناس ودراغون فروت 330 مل', 'V7 Energy Can 330ml', '6221001003', 'مشروبات غازية / Soft Drinks', 'https://images.unsplash.com/photo-1629203851122-3726ecdf080e?w=500', 15.0, 330),
    (4, 'شاي العروسة أسود 100 جم', 'Tea El-Arosa 100g', '6221001011', 'شاي ومشروبات / Tea', 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=500', 40.0, 100),
    (5, 'عصير جهينة برتقال 1 لتر', 'Juhayna Orange Juice 1L', '6221001001', 'مشروبات / Beverages', 'https://images.unsplash.com/photo-1621506289937-48e498495776?w=500', 35.0, 1000),
    (6, 'مولتو كرواسون شوكولاتة', 'Molto Chocolate Croissant', '6221001002', 'مخبوزات / Bakery', 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=500', 15.0, 85),
    (7, 'حليب المراعي كامل الدسم 1 لتر', 'Almarai Full Cream Milk 1L', '6221001005', 'ألبان / Dairy', 'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=500', 45.0, 1000)
]

for p in products:
    cur.execute("""
    INSERT OR REPLACE INTO Product (id, nameAr, nameEn, barcode, category, imageUrl, unitPrice, weightGrams)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, p)

# Seed Active Shopping Session for CART_01
cur.execute("INSERT OR IGNORE INTO ShoppingSession (id, userId, cartCode, cartStatus, sessionStatus) VALUES (1, 1, 'CART_01', 'IN_USE', 'ACTIVE')")

conn.commit()
conn.close()

print("SQLite dev.db created and seeded successfully!")
