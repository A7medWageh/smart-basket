import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding database...');

  // 1. Create Default Test User
  const passwordHash = await bcrypt.hash('password123', 10);
  const user = await prisma.user.upsert({
    where: { email: 'ahmed@scango.com' },
    update: {},
    create: {
      name: 'أحمد محمد',
      email: 'ahmed@scango.com',
      phone: '01012345678',
      password: passwordHash,
    },
  });
  console.log(`👤 Seeded User: ${user.name} (${user.email})`);

  // 2. Create Sample Physical Carts
  const carts = ['CART_01', 'CART_02', 'CART_03'];
  for (const cartCode of carts) {
    await prisma.cart.upsert({
      where: { cartCode },
      update: {},
      create: {
        cartCode,
        status: 'AVAILABLE',
      },
    });
  }
  console.log(`🛒 Seeded Carts: ${carts.join(', ')}`);

  // 3. Products matching the AI Model (Smart-Basket ONNX Model + Extra Groceries)
  const products = [
    {
      nameAr: 'دوريتوس فلفل حلو (Sweet Chili)',
      nameEn: 'Doritos Sweet Chili 95g',
      barcode: '6221001004',
      price: 15.0,
      imageUrl: 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=500&auto=format&fit=crop&q=60',
      category: 'سناكس / Snacks',
      weightGrams: 95,
      stock: 100,
    },
    {
      nameAr: 'إندومي فراخ كاري (Chicken Curry)',
      nameEn: 'Indomie Chicken Curry 70g',
      barcode: '6221001010',
      price: 12.0,
      imageUrl: 'https://images.unsplash.com/photo-1612927601601-6638404737ce?w=500&auto=format&fit=crop&q=60',
      category: 'وجبات سريعة / Instant Noodles',
      weightGrams: 75,
      stock: 150,
    },
    {
      nameAr: 'بيبسي دايت كانز 330 مل',
      nameEn: 'Pepsi Diet Can 330ml',
      barcode: '6221001003',
      price: 15.0,
      imageUrl: 'https://images.unsplash.com/photo-1629203851122-3726ecdf080e?w=500&auto=format&fit=crop&q=60',
      category: 'مشروبات غازية / Soft Drinks',
      weightGrams: 350,
      stock: 80,
    },
    {
      nameAr: 'شاي العروسة أسود 100 جم',
      nameEn: 'Tea El-Arosa 100g',
      barcode: '6221001011',
      price: 25.0,
      imageUrl: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=500&auto=format&fit=crop&q=60',
      category: 'شاي ومشروبات / Tea',
      weightGrams: 110,
      stock: 90,
    },
    {
      nameAr: 'عصير جهينة برتقال 1 لتر',
      nameEn: 'Juhayna Orange Juice 1L',
      barcode: '6221001001',
      price: 35.0,
      imageUrl: 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=500&auto=format&fit=crop&q=60',
      category: 'مشروبات / Beverages',
      weightGrams: 1050,
      stock: 50,
    },
    {
      nameAr: 'مولتو كرواسون شوكولاتة',
      nameEn: 'Molto Chocolate Croissant',
      barcode: '6221001002',
      price: 15.0,
      imageUrl: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=500&auto=format&fit=crop&q=60',
      category: 'مخبوزات / Bakery',
      weightGrams: 90,
      stock: 120,
    },
    {
      nameAr: 'حليب المراعي كامل الدسم 1 لتر',
      nameEn: 'Almarai Full Cream Milk 1L',
      barcode: '6221001005',
      price: 45.0,
      imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&auto=format&fit=crop&q=60',
      category: 'ألبان / Dairy',
      weightGrams: 1030,
      stock: 40,
    },
  ];

  for (const product of products) {
    await prisma.product.upsert({
      where: { barcode: product.barcode },
      update: product,
      create: product,
    });
  }
  console.log(`📦 Seeded ${products.length} Products successfully.`);
}

main()
  .catch((e) => {
    console.error('❌ Error during seeding:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
