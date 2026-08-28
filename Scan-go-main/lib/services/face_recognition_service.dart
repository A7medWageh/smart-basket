import 'dart:typed_data';

class FaceEnrollResult {
  final bool isSuccess;
  final String? message;
  final String? errorMessage;
  final int? statusCode;

  const FaceEnrollResult({
    required this.isSuccess,
    this.message,
    this.errorMessage,
    this.statusCode,
  });

  factory FaceEnrollResult.success({String? message}) => FaceEnrollResult(
        isSuccess: true,
        message: message ?? 'Face enrolled successfully',
      );

  factory FaceEnrollResult.failure(String message, {int? statusCode}) =>
      FaceEnrollResult(
        isSuccess: false,
        errorMessage: message,
        statusCode: statusCode,
      );
}

class FaceVerificationResult {
  final bool isSuccess;
  final String? userId;
  final String? token;
  final String? message;
  final String? errorMessage;
  final int? statusCode;

  const FaceVerificationResult({
    required this.isSuccess,
    this.userId,
    this.token,
    this.message,
    this.errorMessage,
    this.statusCode,
  });

  factory FaceVerificationResult.success({
    required String userId,
    required String token,
    String? message,
  }) =>
      FaceVerificationResult(
        isSuccess: true,
        userId: userId,
        token: token,
        message: message ?? 'Face verified successfully',
      );

  factory FaceVerificationResult.failure(String message, {int? statusCode}) =>
      FaceVerificationResult(
        isSuccess: false,
        errorMessage: message,
        statusCode: statusCode,
      );
}

abstract class FaceRecognitionService {
  Future<void> initialize();

  Future<FaceEnrollResult> enrollFace({
    required String userId,
    required String imagePath,
    Uint8List? imageBytes,
  });

  Future<FaceVerificationResult> verifyFace({
    required String imagePath,
    Uint8List? imageBytes,
    String? cartCode,
  });

  void cancel();
}
