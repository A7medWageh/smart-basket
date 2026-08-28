import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../state/auth_provider.dart';
import '../../state/cart_provider.dart';
import '../../state/payment_provider.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/scango_logo.dart';
import '../../widgets/step_progress_bar.dart';
import '../welcome/welcome_screen.dart';

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});

  void _returnToHome(BuildContext context) {
    Provider.of<CartProvider>(context, listen: false).clearCart();
    Provider.of<AuthProvider>(context, listen: false).reset();
    Provider.of<PaymentProvider>(context, listen: false).reset();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Widget _buildExitQrCode(String? exitQrData, String orderNumber) {
    if (exitQrData != null && exitQrData.startsWith('data:image')) {
      try {
        final commaIdx = exitQrData.indexOf(',');
        final base64Str = commaIdx != -1 ? exitQrData.substring(commaIdx + 1) : exitQrData;
        final bytes = base64Decode(base64Str);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, width: 140, height: 140, fit: BoxFit.contain),
        );
      } catch (_) {}
    }

    final qrContent = (exitQrData != null && exitQrData.isNotEmpty) ? exitQrData : orderNumber;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: QrImageView(
        data: qrContent,
        version: QrVersions.auto,
        size: 130.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paymentProvider = Provider.of<PaymentProvider>(context);
    final orderNumber = paymentProvider.orderNumber ?? 'ORD-SCAN-GO';
    final exitQrCode = paymentProvider.exitQrCode;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const ScanGoLogo(height: 38, isDarkBackground: false),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              // All 3 Steps completed indicator
              const StepProgressBar(currentStep: 3),
              const SizedBox(height: 20),

              // Light Cream/Pink Rounded Card Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successCardBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Green Circle Check Icon
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outlined,
                        size: 52,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Payment Successful',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Order #$orderNumber',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreenDark,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Exit QR Code section
                    _buildExitQrCode(
                      exitQrCode,
                      orderNumber,
                    ),
                    const SizedBox(height: 10),

                    const Text(
                      'Scan this Exit Pass QR at the gate to exit',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Successful Green Badge Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successBadgeBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 6,
                            color: AppColors.successBadgeText,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Paid & Verified',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.successBadgeText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Back to Home Button at bottom
              PrimaryButton(
                label: 'Back to Home',
                backgroundColor: AppColors.primaryGreenDark,
                onPressed: () => _returnToHome(context),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
