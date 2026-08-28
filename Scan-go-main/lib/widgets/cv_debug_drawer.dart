import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/product_repository.dart';
import '../services/cart_api_service.dart';
import '../services/mock_computer_vision_service.dart';
import '../state/cart_provider.dart';

class CvDebugPanel extends StatelessWidget {
  final MockComputerVisionService cvService;

  const CvDebugPanel({
    super.key,
    required this.cvService,
  });

  void _triggerAiDetection(
    BuildContext context, {
    dynamic productId,
    String? barcode,
    String? label,
    String action = 'added',
  }) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final cartCode = cartProvider.cartCode ?? 'CART_01';

    try {
      final cartApiService = Provider.of<CartApiService>(context, listen: false);
      cartApiService.simulateAiDetection(
        cartCode: cartCode,
        productId: productId is int ? productId : int.tryParse(productId.toString()) ?? 1,
        action: action,
      );
    } catch (_) {}

    // Also emit locally for offline testing
    if (action == 'added') {
      if (productId == ProductRepository.doritos.id || label?.contains('Doritos') == true) {
        cvService.simulateAddProduct(ProductRepository.doritos);
      } else if (productId == ProductRepository.tuna.id || label?.contains('Tuna') == true) {
        cvService.simulateAddProduct(ProductRepository.tuna);
      } else if (productId == ProductRepository.honey.id || label?.contains('Honey') == true) {
        cvService.simulateAddProduct(ProductRepository.honey);
      }
    } else {
      if (productId == ProductRepository.doritos.id || label?.contains('Doritos') == true) {
        cvService.simulateRemoveProduct(ProductRepository.doritos.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 4,
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade400, width: 1.5),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: const Icon(Icons.sensors, color: Colors.amber),
        title: const Text(
          'Computer Vision Simulator (Debug Mode Only)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.amber,
          ),
        ),
        subtitle: const Text(
          'Simulate physical cart computer vision & AI events',
          style: TextStyle(fontSize: 10, color: Colors.black54),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _triggerAiDetection(
                      context,
                      productId: ProductRepository.doritos.id,
                      barcode: ProductRepository.doritos.barcode,
                      label: ProductRepository.doritos.name,
                      action: 'added',
                    );
                  },
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Doritos (\$10)', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _triggerAiDetection(
                      context,
                      productId: ProductRepository.tuna.id,
                      barcode: ProductRepository.tuna.barcode,
                      label: ProductRepository.tuna.name,
                      action: 'added',
                    );
                  },
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Tuna (\$65)', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _triggerAiDetection(
                      context,
                      productId: ProductRepository.honey.id,
                      barcode: ProductRepository.honey.barcode,
                      label: ProductRepository.honey.name,
                      action: 'added',
                    );
                  },
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Honey (\$145)', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _triggerAiDetection(
                      context,
                      productId: ProductRepository.doritos.id,
                      barcode: ProductRepository.doritos.barcode,
                      label: ProductRepository.doritos.name,
                      action: 'removed',
                    );
                  },
                  icon: const Icon(Icons.remove, size: 14),
                  label: const Text('Remove Doritos', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    cvService.simulateClearCart();
                  },
                  icon: const Icon(Icons.cleaning_services, size: 14),
                  label: const Text('Clear Cart', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade800,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
