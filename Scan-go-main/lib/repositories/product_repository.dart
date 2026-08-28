import '../models/product.dart';

class ProductRepository {
  static const Product doritos = Product(
    id: '1',
    name: 'Nacho Cheese Doritos',
    nameAr: 'دوريتوس فلفل حلو',
    weight: '70g',
    price: 10.00,
    imagePath: 'assets/doritos.png',
    barcode: '6221001004',
  );

  static const Product tuna = Product(
    id: '2',
    name: 'Sunshine Tuna - Chunks',
    nameAr: 'تونة صن شاين قطع',
    weight: '185g',
    price: 65.00,
    imagePath: 'assets/tuna.png',
    barcode: '6221001010',
  );

  static const Product honey = Product(
    id: '3',
    name: 'Imtenan Spring Flowers - Pure Bee Honey',
    nameAr: 'عسل نحل امتنان زهور برية',
    weight: '450g',
    price: 145.00,
    imagePath: 'assets/honey.png',
    barcode: '6221001011',
  );

  static List<Product> get catalog => [doritos, tuna, honey];

  static Product? findById(dynamic id) {
    try {
      return catalog.firstWhere((p) => p.id.toString() == id.toString());
    } catch (_) {
      return null;
    }
  }
}
