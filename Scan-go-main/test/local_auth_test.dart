import 'package:flutter_test/flutter_test.dart';
import 'package:scango/services/face_recognition_service.dart';
import 'package:scango/services/local_auth_face_recognition_service.dart';

void main() {
  group('LocalAuthFaceRecognitionService Tests', () {
    test('Implements FaceRecognitionService interface', () {
      final service = LocalAuthFaceRecognitionService();
      expect(service, isA<FaceRecognitionService>());
    });
  });
}
