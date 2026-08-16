import 'dart:io';

import 'package:image_picker/image_picker.dart';

/// Where new pictures come from. An interface so the library controller can be
/// driven by a fake in tests instead of a real picker UI.
abstract class PhotoSource {
  /// Multi-select from the system photo picker. Empty if the user cancelled.
  Future<List<File>> pickFromGallery();

  /// One shot from the camera. Null if the user backed out.
  Future<File?> captureFromCamera();
}

class ImagePickerPhotoSource implements PhotoSource {
  ImagePickerPhotoSource([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Downscaling here is not a nicety: it bounds stored size and it makes the
  /// plugin apply EXIF orientation to the pixels natively, off the UI thread,
  /// which also drops the GPS tags a photo may carry.
  static const _maxEdge = 2048.0;
  static const _quality = 85;

  @override
  Future<List<File>> pickFromGallery() async {
    final picked = await _picker.pickMultiImage(
      maxWidth: _maxEdge,
      maxHeight: _maxEdge,
      imageQuality: _quality,
    );
    return picked.map((file) => File(file.path)).toList();
  }

  @override
  Future<File?> captureFromCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _maxEdge,
      maxHeight: _maxEdge,
      imageQuality: _quality,
    );
    return picked == null ? null : File(picked.path);
  }
}
