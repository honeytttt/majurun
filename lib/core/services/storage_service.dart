import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:majurun/core/services/s3_service.dart';

class StorageService {
  final S3Service _s3Service = S3Service();

  Future<String?> uploadMedia(Uint8List fileBytes, String fileName, bool isVideo) async {
    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String uniqueFileName = "media_${timestamp}_${fileName.replaceAll(' ', '_')}";

      final contentType = isVideo ? 'video/mp4' : 'image/png';

      debugPrint('StorageService: Uploading $uniqueFileName');

      return await _s3Service.uploadFile(fileBytes, uniqueFileName, contentType);
    } catch (e) {
      debugPrint('StorageService Upload Error: $e');
      return null;
    }
  }

  Future<String?> uploadFile(File file, bool isVideo) async {
    final bytes = await file.readAsBytes();
    final fileName = file.path.split('/').last;
    return uploadMedia(bytes, fileName, isVideo);
  }

  // MISSING METHOD - ADDED BACK
  Future<String?> uploadBytes(Uint8List bytes, String fileName, {bool isVideo = false}) async {
    return uploadMedia(bytes, fileName, isVideo);
  }

  Future<void> deleteOldImage(String? fileUrl) async {
    if (fileUrl == null || fileUrl.isEmpty) return;
    await _s3Service.deleteOldImage(fileUrl);
  }
}