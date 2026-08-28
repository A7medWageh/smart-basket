import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../state/cart_provider.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/scango_logo.dart';
import 'cart_screen.dart';

class PairCartScreen extends StatefulWidget {
  const PairCartScreen({super.key});

  @override
  State<PairCartScreen> createState() => _PairCartScreenState();
}

class _PairCartScreenState extends State<PairCartScreen> {
  final _cartCodeController = TextEditingController(text: AppConstants.defaultCartCode);

  @override
  void dispose() {
    _cartCodeController.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final code = _cartCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    final success = await cartProvider.pairCart(code, faceVerified: true);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CartScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cartProvider.errorMessage ?? 'Could not pair this cart.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const ScanGoLogo(height: 38, isDarkBackground: false),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pair Your Cart',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan the QR on the smart cart or enter the cart code (example: CART_01).',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _cartCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Cart code',
                  prefixIcon: const Icon(Icons.qr_code_2, color: AppColors.primaryGreen),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Pair Cart',
                isLoading: cartProvider.isLoading,
                backgroundColor: AppColors.primaryGreenDark,
                onPressed: cartProvider.isLoading ? null : _pair,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
