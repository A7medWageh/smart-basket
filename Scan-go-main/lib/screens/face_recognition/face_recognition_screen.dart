import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../state/auth_provider.dart';
import '../../state/cart_provider.dart';
import '../../widgets/primary_button.dart';
import '../auth/login_screen.dart';
import '../cart/cart_screen.dart';
import '../cart/pair_cart_screen.dart';

class FaceRecognitionScreen extends StatefulWidget {
  const FaceRecognitionScreen({super.key});

  @override
  State<FaceRecognitionScreen> createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  String? _cameraErrorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _cameraErrorMessage = 'No camera found on device.';
        });
        return;
      }

      // Pick front camera if available
      final frontCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _cameraErrorMessage = null;
        });
      }
    } on CameraException catch (e) {
      if (mounted) {
        setState(() {
          _cameraErrorMessage = 'Camera error: ${e.description ?? e.code}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraErrorMessage = 'Camera initialization failed: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _triggerFaceScan() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    String? capturedPath;
    Uint8List? capturedBytes;

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final XFile photo = await _cameraController!.takePicture();
        capturedPath = photo.path;
        capturedBytes = await photo.readAsBytes();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to capture frame: $e'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    } else {
      // Fallback for emulator / web / test mode
      capturedPath = 'mock_verify_photo.jpg';
      capturedBytes = Uint8List(100);
    }

    final success = await authProvider.verifyFace(
      imagePath: capturedPath,
      imageBytes: capturedBytes,
    );

    if (!mounted) return;

    if (success) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      final hasActiveCart = authProvider.activeCart != null;
      if (hasActiveCart) {
        await Provider.of<CartProvider>(context, listen: false).loadActiveCart();
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => hasActiveCart ? const CartScreen() : const PairCartScreen(),
        ),
      );
    } else if ((authProvider.errorMessage ?? '').contains('sign in')) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      // Show error snackbar if face recognition failed or network error
      final errorMessage = authProvider.errorMessage ?? 'Verification failed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      authProvider.reset();
    }
  }

  Widget _buildCameraPreview(bool isVerified) {
    if (isVerified) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: AppColors.primaryGreen,
          ),
          SizedBox(height: 12),
          Text(
            'Face Recognized!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    if (_isCameraInitialized && _cameraController != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(120),
        child: SizedBox(
          width: 220,
          height: 310,
          child: CameraPreview(_cameraController!),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.face,
          size: 80,
          color: Colors.white.withValues(alpha: 0.3),
        ),
        if (_cameraErrorMessage != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _cameraErrorMessage!,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isScanning = authProvider.status == AuthStatus.verifyingFace;
    final isVerified = authProvider.isVerified;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Face Recognition',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Look at the camera for instant, secure login',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),

              // Oval Camera Frame (Exact Visual Design Preserved)
              Center(
                child: Container(
                  width: 220,
                  height: 310,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(120),
                    border: Border.all(
                      color: isVerified
                          ? AppColors.primaryGreen
                          : (isScanning ? AppColors.primaryGreen : const Color(0xFF22C55E)),
                      width: 5,
                    ),
                    gradient: isVerified
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF0F3D1E),
                              Color(0xFF06180B),
                            ],
                          )
                        : const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF166534),
                              Color(0xFF052E16),
                            ],
                          ),
                  ),
                  child: Center(
                    child: isScanning
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Verifying face with backend...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        : _buildCameraPreview(isVerified),
                  ),
                ),
              ),

              const Spacer(),

              // Scan / Verified Button (Exact Visual Design Preserved)
              PrimaryButton(
                label: isVerified
                    ? 'Verified'
                    : (isScanning ? 'Verifying...' : 'Scan My Face'),
                icon: isVerified
                    ? Icons.check
                    : (isScanning ? null : Icons.camera_alt_outlined),
                isLoading: isScanning,
                backgroundColor:
                    isVerified ? AppColors.primaryGreen : AppColors.primaryGreenDark,
                onPressed: (isScanning || isVerified) ? null : _triggerFaceScan,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
