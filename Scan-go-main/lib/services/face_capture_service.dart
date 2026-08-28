import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

abstract class FaceCaptureService {
  Future<XFile?> captureFacePhoto();
}

class CameraFaceCaptureService implements FaceCaptureService {
  final ImagePicker _picker;

  CameraFaceCaptureService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  @override
  Future<XFile?> captureFacePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      return photo;
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied') {
        throw Exception('Camera permission was denied. Please grant camera access in settings.');
      }
      throw Exception('Failed to access camera: ${e.message ?? e.code}');
    } catch (e) {
      throw Exception('Camera capture error: $e');
    }
  }
}
