import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/auth_provider.dart';
import '../../state/cart_provider.dart';
import '../../state/payment_provider.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/scango_logo.dart';
import '../../widgets/step_progress_bar.dart';
import '../welcome/welcome_screen.dart';

class PaymentFailedScreen extends StatelessWidget {
  const PaymentFailedScreen({super.key});

  void _tryAgain(BuildContext context) {
    Provider.of<PaymentProvider>(context, listen: false).reset();
    Navigator.of(context).pop(); // Returns to CheckoutScreen
  }

  void _backToHome(BuildContext context) {
    Provider.of<CartProvider>(context, listen: false).clearCart();
    Provider.of<AuthProvider>(context, listen: false).reset();
    Provider.of<PaymentProvider>(context, listen: false).reset();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = Provider.of<PaymentProvider>(context).errorMessage;

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              // Top Step Progress
              const StepProgressBar(currentStep: 3),
              const Spacer(),

              // Light Pink Container Card from screenshot
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 36,
                ),
                decoration: BoxDecoration(
                  color: AppColors.failureCardBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Red Circle X Icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.failureIconBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Payment Failed',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      errorMessage ?? 'Something went wrong. Please try again or use a different payment method.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Failed Red Badge Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.failureBadgeBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 6,
                            color: AppColors.failureBadgeText,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Failed',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.failureBadgeText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Try agine button (matching exact screenshot label)
              PrimaryButton(
                label: 'Try agine',
                backgroundColor: AppColors.primaryGreenDark,
                onPressed: () => _tryAgain(context),
              ),
              const SizedBox(height: 12),

              // Back to Home button
              PrimaryButton(
                label: 'Back to Home',
                backgroundColor: AppColors.primaryGreenDark,
                onPressed: () => _backToHome(context),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
