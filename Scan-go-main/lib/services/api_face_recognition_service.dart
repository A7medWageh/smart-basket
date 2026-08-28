import 'dart:typed_data';
import '../core/constants/app_constants.dart';
import 'api_client.dart';
import 'face_recognition_service.dart';
import 'token_storage_service.dart';

class ApiFaceRecognitionService implements FaceRecognitionService {
  final ApiClient _apiClient;

  ApiFaceRecognitionService({
    ApiClient? apiClient,
    TokenStorageService? tokenStorage,
  }) : _apiClient = apiClient ?? ApiClient(tokenStorage: tokenStorage ?? TokenStorageService());

  @override
  Future<void> initialize() async {}

  @override
  Future<FaceEnrollResult> enrollFace({
    required String userId,
    required String imagePath,
    Uint8List? imageBytes,
  }) async {
    final response = await _apiClient.post(
      AppConstants.faceEnrollEndpoint,
      body: {
        'userId': userId,
        'enrolled': true,
      },
    );

    if (response.isSuccess) {
      String? message;
      if (response.data is Map) {
        message = (response.data as Map)['message']?.toString();
      }
      return FaceEnrollResult.success(message: message);
    }
    return FaceEnrollResult.failure(
      response.errorMessage ?? 'Face enrollment failed',
      statusCode: response.statusCode,
    );
  }

  @override
  Future<FaceVerificationResult> verifyFace({
    required String imagePath,
    Uint8List? imageBytes,
    String? cartCode,
  }) async {
    final response = await _apiClient.post(
      AppConstants.faceVerifyEndpoint,
      body: {
        if (cartCode != null) 'cartCode': cartCode,
      },
    );

    if (!response.isSuccess) {
      return FaceVerificationResult.failure(
        response.errorMessage ?? 'Face verification failed',
        statusCode: response.statusCode,
      );
    }

    Map<String, dynamic> payload = {};
    if (response.data is Map) {
      final root = Map<String, dynamic>.from(response.data as Map);
      if (root['data'] is Map) {
        payload = Map<String, dynamic>.from(root['data'] as Map);
      } else {
        payload = root;
      }
    }

    final user = payload['user'];
    final userId = payload['userId']?.toString() ??
        (user is Map ? user['id']?.toString() : null) ??
        '';
    final token = payload['token']?.toString() ?? '';

    return FaceVerificationResult.success(
      userId: userId,
      token: token,
      message: payload['message']?.toString() ?? 'Face verified successfully',
    );
  }

  @override
  void cancel() {}
}
