import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class CloudinaryService {
  final String _apiKey = "271677957946761";
  final String _cloudName = "ddo14sbqv"; 
  final String _uploadPreset = "majurun";
  final String _assetFolder = "majurun";

  final Dio _dio = Dio();

  /// Takes bytes and filename to ensure compatibility across Web and Mobile
  Future<String?> uploadMedia(Uint8List fileBytes, String fileName, bool isVideo) async {
    final String url = "https://api.cloudinary.com/v1_1/$_cloudName/${isVideo ? 'video' : 'image'}/upload";

    try {
      final FormData formData = FormData.fromMap({
        "file": MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
        "upload_preset": _uploadPreset,
        "folder": _assetFolder,
        "api_key": _apiKey,
      });

      final Response response = await _dio.post(
        url, 
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0) {
            debugPrint("Upload progress: ${(sent / total * 100).toStringAsFixed(0)}%");
          }
        },
      );

      if (response.statusCode == 200) {
        return response.data['secure_url'];
      }
      return null;
    } catch (e) {
      debugPrint("Cloudinary Upload Error: $e");
      return null;
    }
  }
}