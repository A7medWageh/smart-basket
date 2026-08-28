import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../state/auth_provider.dart';
import '../../widgets/primary_button.dart';
import '../cart/pair_cart_screen.dart';

class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isEnrolled = false;
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
          _cameraErrorMessage = 'No cameras found on device.';
        });
        return;
      }

      // Pick front camera if available, otherwise first camera
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

  void _captureAndEnrollFace() async {
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
      // Fallback for test / web / simulator environments without active camera hardware
      capturedPath = 'mock_enroll_photo.jpg';
      capturedBytes = Uint8List(100);
    }

    final success = await authProvider.enrollFace(
      imagePath: capturedPath,
      imageBytes: capturedBytes,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _isEnrolled = true;
      });

      // Brief delay to display Verified UI state, then navigate to Cart
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PairCartScreen()),
          (route) => false,
        );
      }
    } else {
      final error = authProvider.errorMessage ?? 'Face enrollment failed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildCameraPreview() {
    if (_isEnrolled) {
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
            'Face Registered!',
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
    final isEnrolling = authProvider.status == AuthStatus.enrollingFace;

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
                'Register Your Face',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Look at the camera and position your face inside the frame',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),

              // Oval Camera Frame
              Center(
                child: Container(
                  width: 220,
                  height: 310,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(120),
                    border: Border.all(
                      color: _isEnrolled
                          ? AppColors.primaryGreen
                          : (isEnrolling ? AppColors.primaryGreen : const Color(0xFF22C55E)),
                      width: 5,
                    ),
                    gradient: _isEnrolled
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF0F3D1E), Color(0xFF06180B)],
                          )
                        : const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF166534), Color(0xFF052E16)],
                          ),
                  ),
                  child: Center(
                    child: isEnrolling
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Registering face with backend...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        : _buildCameraPreview(),
                  ),
                ),
              ),

              const Spacer(),

              // Register Button
              PrimaryButton(
                label: _isEnrolled
                    ? 'Registered'
                    : (isEnrolling ? 'Registering...' : 'Capture & Register Face'),
                icon: _isEnrolled
                    ? Icons.check
                    : (isEnrolling ? null : Icons.camera_alt_outlined),
                isLoading: isEnrolling,
                backgroundColor:
                    _isEnrolled ? AppColors.primaryGreen : AppColors.primaryGreenDark,
                onPressed: (isEnrolling || _isEnrolled) ? null : _captureAndEnrollFace,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
