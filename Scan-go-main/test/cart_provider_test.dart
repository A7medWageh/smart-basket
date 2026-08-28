import 'package:flutter_test/flutter_test.dart';
import 'package:scango/repositories/product_repository.dart';
import 'package:scango/services/mock_computer_vision_service.dart';
import 'package:scango/state/cart_provider.dart';

void main() {
  group('CartProvider Tests - Subtotal, Tax 3%, and Total Calculations', () {
    late MockComputerVisionService cvService;
    late CartProvider cartProvider;

    setUp(() {
      cvService = MockComputerVisionService();
      cartProvider = CartProvider(cvService: cvService);
    });

    tearDown(() {
      cartProvider.dispose();
      cvService.dispose();
    });

    test('Test 1: Single item (Doritos \$10.00)', () async {
      cvService.simulateAddProduct(ProductRepository.doritos);
      await Future.delayed(Duration.zero);

      expect(cartProvider.subtotal, closeTo(10.00, 0.001));
      expect(cartProvider.tax, closeTo(0.30, 0.001));
      expect(cartProvider.total, closeTo(10.30, 0.001));
    });

    test('Test 2: Three items (Doritos + Tuna + Bee Honey)', () async {
      cvService.simulateAddProduct(ProductRepository.doritos);
      cvService.simulateAddProduct(ProductRepository.tuna);
      cvService.simulateAddProduct(ProductRepository.honey);
      await Future.delayed(Duration.zero);

      expect(cartProvider.subtotal, closeTo(220.00, 0.001));
      expect(cartProvider.tax, closeTo(6.60, 0.001));
      expect(cartProvider.total, closeTo(226.60, 0.001));
    });

    test('Test 3: Remove Doritos after adding all three items', () async {
      cvService.simulateAddProduct(ProductRepository.doritos);
      cvService.simulateAddProduct(ProductRepository.tuna);
      cvService.simulateAddProduct(ProductRepository.honey);
      await Future.delayed(Duration.zero);

      // Remove Doritos
      cvService.simulateRemoveProduct(ProductRepository.doritos.id);
      await Future.delayed(Duration.zero);

      expect(cartProvider.subtotal, closeTo(210.00, 0.001));
      expect(cartProvider.tax, closeTo(6.30, 0.001));
      expect(cartProvider.total, closeTo(216.30, 0.001));
    });
  });
}
