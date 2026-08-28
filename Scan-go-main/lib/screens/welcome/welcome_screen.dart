import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/scango_logo.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../face_recognition/face_recognition_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.darkNavyTop, AppColors.darkNavyBottom],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // ScanGo Logo in center (Enlarged)
                const ScanGoLogo(width: 280, height: 95, isDarkBackground: true),
                const Spacer(flex: 2),

                // Primary Action: Start Shopping (Quick Face Recognition)
                PrimaryButton(
                  label: 'Start Shopping',
                  backgroundColor: AppColors.primaryGreenDark,
                  icon: Icons.face,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FaceRecognitionScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Secondary Action: Create Account
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryGreenLight, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sign In Link
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: RichText(
                      text: const TextSpan(
                        text: 'Existing Customer? ',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                        children: [
                          TextSpan(
                            text: 'Sign In',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreenLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
