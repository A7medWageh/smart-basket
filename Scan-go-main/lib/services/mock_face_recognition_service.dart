import 'dart:typed_data';
import 'face_recognition_service.dart';

class MockFaceRecognitionService implements FaceRecognitionService {
  final bool shouldFail;
  final String failureMessage;

  MockFaceRecognitionService({
    this.shouldFail = false,
    this.failureMessage = 'Mock Face Recognition failed.',
  });

  @override
  Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<FaceEnrollResult> enrollFace({
    required String userId,
    required String imagePath,
    Uint8List? imageBytes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (shouldFail) {
      return FaceEnrollResult.failure(failureMessage, statusCode: 500);
    }
    return FaceEnrollResult.success(message: 'Face enrolled successfully (Mock)');
  }

  @override
  Future<FaceVerificationResult> verifyFace({
    required String imagePath,
    Uint8List? imageBytes,
    String? cartCode,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (shouldFail) {
      return FaceVerificationResult.failure(failureMessage, statusCode: 401);
    }
    return FaceVerificationResult.success(
      userId: 'mock_user_101',
      token: 'mock_jwt_token_123',
      message: 'Face verified successfully (Mock)',
    );
  }

  @override
  void cancel() {}
}
