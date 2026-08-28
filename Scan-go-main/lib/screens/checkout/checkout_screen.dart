import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/payment_method.dart';
import '../../state/cart_provider.dart';
import '../../state/payment_provider.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/scango_logo.dart';
import '../../widgets/step_progress_bar.dart';
import '../payment/payment_failed_screen.dart';
import '../payment/payment_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  void _handlePaymentSubmit() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final paymentProvider = Provider.of<PaymentProvider>(
      context,
      listen: false,
    );

    final result = await paymentProvider.processPayment(cartProvider.total);

    if (!mounted) return;

    if (result.isSuccess) {
      cartProvider.clearCart();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PaymentSuccessScreen()),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaymentFailedScreen()),
      );
    }
  }

  Widget _buildPaymentOptionTile(PaymentMethod method, PaymentMethod selected) {
    final isSelected = method.type == selected.type;

    IconData iconData = Icons.credit_card;
    Color iconColor = Colors.grey;

    if (method.type == PaymentMethodType.vodafoneCash) {
      iconData = Icons.phone_android;
      iconColor = Colors.red;
    } else if (method.type == PaymentMethodType.instaPay) {
      iconData = Icons.flash_on;
      iconColor = Colors.purple;
    } else if (method.type == PaymentMethodType.visaCard) {
      iconData = Icons.credit_card;
      iconColor = Colors.blue;
    }

    return GestureDetector(
      onTap: () {
        Provider.of<PaymentProvider>(
          context,
          listen: false,
        ).selectPaymentMethod(method);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.borderLight,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(iconData, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Text(
              method.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final paymentProvider = Provider.of<PaymentProvider>(context);
    final selectedMethod = paymentProvider.selectedMethod;
    final isProcessing = paymentProvider.status == PaymentProcessingStatus.processing;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const ScanGoLogo(height: 38, isDarkBackground: false),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Step Progress Indicator
              const StepProgressBar(currentStep: 2),
              const SizedBox(height: 24),

              // Total Calculation Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(cartProvider.total),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Payment Method Section Title
              const Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              ...PaymentMethod.defaultMethods.map(
                (method) => _buildPaymentOptionTile(method, selectedMethod),
              ),

              const Spacer(),

              // Digital receipt note
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ⓘ ',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  Expanded(
                    child: Text(
                      'Note: Your digital receipt and Exit Pass QR code will be generated immediately after payment.',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Next Button
              PrimaryButton(
                label: isProcessing ? 'Processing Payment...' : 'Next',
                isLoading: isProcessing,
                backgroundColor: AppColors.primaryGreenDark,
                onPressed: isProcessing ? null : _handlePaymentSubmit,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
