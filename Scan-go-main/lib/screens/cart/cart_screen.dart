import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../services/mock_computer_vision_service.dart';
import '../../state/cart_provider.dart';
import '../../widgets/cart_item_tile.dart';
import '../../widgets/cv_debug_drawer.dart';
import '../../widgets/primary_button.dart';
import '../checkout/checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Widget _buildEmptyCartView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: const BoxDecoration(
            color: Color(0xFFC7EBD1), // Matching circular light green container in screenshot
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.shopping_basket_outlined,
              size: 68,
              color: AppColors.primaryGreenDark,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Your Cart is Empty',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sorry, you have no product in\nyour cart',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildPopulatedCartView(BuildContext context, CartProvider cartProvider) {
    return Column(
      children: [
        // List of Cart items
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: cartProvider.items.length,
            itemBuilder: (ctx, index) {
              final cartItem = cartProvider.items[index];
              return CartItemTile(
                item: cartItem,
                onRemoveCompletely: () {
                  cartProvider.removeProductCompletely(cartItem.product.id);
                },
              );
            },
          ),
        ),

        // Sticky Bottom Calculation Summary Container (matching screenshot iPhone 16 - 26)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sub total',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      CurrencyFormatter.format(cartProvider.subtotal),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'tax(3%)',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      CurrencyFormatter.format(cartProvider.tax),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: AppColors.borderLight),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      CurrencyFormatter.format(cartProvider.total),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Checkout Now',
                  backgroundColor: AppColors.primaryGreenDark,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CheckoutScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final cvService = Provider.of<MockComputerVisionService>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Text(
            'My Cart',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        actions: [
          // Cart badge action icon
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_cart_outlined,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                ),
                if (cartProvider.totalItemCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFA8C16), // Orange badge from screenshot
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${cartProvider.totalItemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Debug Mode CV Simulator Bar (only visible when kDebugMode is true)
            if (kDebugMode) CvDebugPanel(cvService: cvService),

            // Main Cart Content
            Expanded(
              child: cartProvider.isEmpty
                  ? Center(child: _buildEmptyCartView())
                  : _buildPopulatedCartView(context, cartProvider),
            ),
          ],
        ),
      ),
    );
  }
}
