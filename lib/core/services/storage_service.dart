import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:majurun/core/services/s3_service.dart';

class StorageService {
  final S3Service _s3Service = S3Service();

  Future<String?> uploadMedia(Uint8List fileBytes, String fileName, bool isVideo) async {
    try {
      // Create a unique filename to bypass S3 and Browser caching
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Clean the filename: remove spaces and prepend timestamp
      final String uniqueFileName = "media_${timestamp}_${fileName.replaceAll(' ', '_')}";

      // Determine content type
      final contentType = isVideo ? 'video/mp4' : 'image/jpeg';
      
      debugPrint("StorageService: Uploading $uniqueFileName");
      
      // Send to S3 Service
      return await _s3Service.uploadFile(fileBytes, uniqueFileName, contentType);
    } catch (e) {
      debugPrint("StorageService Upload Error: $e");
      return null;
    }
  }

  Future<String?> uploadFile(File file, bool isVideo) async {
    final bytes = await file.readAsBytes();
    final fileName = file.path.split('/').last;
    return uploadMedia(bytes, fileName, isVideo);
  }
  Future<void> deleteOldImage(String fileUrl) async {
  await _s3Service.deleteOldImage(fileUrl);
  }
}