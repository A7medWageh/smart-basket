import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../core/constants/app_constants.dart';

class FaceUploadResponse {
  final bool isSuccess;
  final int statusCode;
  final String message;

  const FaceUploadResponse({
    required this.isSuccess,
    required this.statusCode,
    required this.message,
  });
}

abstract class FaceUploadService {
  Future<FaceUploadResponse> uploadFaceImage({
    required XFile imageFile,
    required String transactionId,
  });
}

class ApiFaceUploadService implements FaceUploadService {
  final http.Client _client;

  ApiFaceUploadService({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<FaceUploadResponse> uploadFaceImage({
    required XFile imageFile,
    required String transactionId,
  }) async {
    final endpointUri = Uri.parse(AppConstants.faceVerifyEndpoint);

    try {
      final request = http.MultipartRequest('POST', endpointUri);

      // Add multipart form data fields
      request.fields['transactionId'] = transactionId;
      request.fields['timestamp'] = DateTime.now().toIso8601String();

      // Add multipart image file
      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        final multipartFile = http.MultipartFile.fromBytes(
          'faceImage',
          bytes,
          filename: 'face_$transactionId.jpg',
        );
        request.files.add(multipartFile);
      } else {
        final multipartFile = await http.MultipartFile.fromPath(
          'faceImage',
          imageFile.path,
          filename: 'face_$transactionId.jpg',
        );
        request.files.add(multipartFile);
      }

      final streamedResponse = await _client.send(request).timeout(
            const Duration(seconds: 15),
          );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return FaceUploadResponse(
          isSuccess: true,
          statusCode: response.statusCode,
          message: 'Face image uploaded successfully.',
        );
      } else {
        return FaceUploadResponse(
          isSuccess: false,
          statusCode: response.statusCode,
          message: 'Backend server returned error: ${response.statusCode} ${response.reasonPhrase ?? ''}',
        );
      }
    } on TimeoutException {
      return const FaceUploadResponse(
        isSuccess: false,
        statusCode: 408,
        message: 'Upload timed out. Please check server connection.',
      );
    } catch (e) {
      return FaceUploadResponse(
        isSuccess: false,
        statusCode: 500,
        message: 'Network / upload error: $e',
      );
    }
  }
}
