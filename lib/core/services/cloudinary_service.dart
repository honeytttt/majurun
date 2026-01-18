import 'dart:io';
import 'package:dio/dio.dart';

class CloudinaryService {
  final String _apiKey = "271677957946761";
  final String _cloudName = "ddo14sbqv"; // Extracted from your PID context/Cloudinary URL
  final String _uploadPreset = "majurun";
  final String _assetFolder = "majurun";

  final Dio _dio = Dio();

  Future<String?> uploadMedia(File file, bool isVideo) async {
    String url = "https://api.cloudinary.com/v1_1/$_cloudName/${isVideo ? 'video' : 'image'}/upload";

    try {
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(file.path),
        "upload_preset": _uploadPreset,
        "folder": _assetFolder,
        "api_key": _apiKey,
      });

      Response response = await _dio.post(url, data: formData);

      if (response.statusCode == 200) {
        return response.data['secure_url'];
      }
      return null;
    } catch (e) {
      print("Cloudinary Upload Error: $e");
      return null;
    }
  }
}