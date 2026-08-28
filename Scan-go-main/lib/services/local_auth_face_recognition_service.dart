import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'face_recognition_service.dart';

class LocalAuthFaceRecognitionService implements FaceRecognitionService {
  final LocalAuthentication _auth;

  LocalAuthFaceRecognitionService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  @override
  Future<void> initialize() async {}

  @override
  Future<FaceEnrollResult> enrollFace({
    required String userId,
    required String imagePath,
    Uint8List? imageBytes,
  }) async {
    final authResult = await _authenticateNative();
    if (authResult.isSuccess) {
      return FaceEnrollResult.success(message: 'Biometric face enrolled');
    } else {
      return FaceEnrollResult.failure(authResult.errorMessage ?? 'Biometric enrollment failed');
    }
  }

  @override
  Future<FaceVerificationResult> verifyFace({
    required String imagePath,
    Uint8List? imageBytes,
    String? cartCode,
  }) async {
    final authResult = await _authenticateNative();
    if (authResult.isSuccess) {
      return FaceVerificationResult.success(
        userId: 'local_biometric_user',
        token: 'local_biometric_token',
        message: 'Biometric verified successfully',
      );
    } else {
      return FaceVerificationResult.failure(
        authResult.errorMessage ?? 'Biometric verification failed',
      );
    }
  }

  Future<FaceEnrollResult> _authenticateNative() async {
    if (kIsWeb) {
      return FaceEnrollResult.failure('Biometrics not supported on Web');
    }

    try {
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      final bool canCheckBiometrics = await _auth.canCheckBiometrics;

      if (!isDeviceSupported && !canCheckBiometrics) {
        return FaceEnrollResult.failure('Device does not support biometrics');
      }

      final bool authenticated = await _auth.authenticate(
        localizedReason: 'Please authenticate to access your ScanGo account.',
      );

      if (authenticated) {
        return FaceEnrollResult.success();
      } else {
        return FaceEnrollResult.failure('Authentication cancelled');
      }
    } on PlatformException catch (e) {
      return FaceEnrollResult.failure(e.message ?? 'Platform auth error (${e.code})');
    } catch (e) {
      return FaceEnrollResult.failure('Auth error: $e');
    }
  }

  @override
  void cancel() {
    try {
      _auth.stopAuthentication();
    } catch (_) {}
  }
}
