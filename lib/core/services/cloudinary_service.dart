import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:majurun/core/config/app_config.dart';
import 'package:majurun/core/services/logging_service.dart';

class CloudinaryService {
  final _log = LoggingService.instance.withTag('Cloudinary');
  final Dio _dio = Dio();

  String get _cloudName => AppConfig.cloudinaryCloudName;
  String get _apiKey => AppConfig.cloudinaryApiKey;
  String get _uploadPreset => AppConfig.cloudinaryUploadPreset;

  /// Check if Cloudinary is properly configured
  bool get isConfigured =>
      _cloudName.isNotEmpty && _apiKey.isNotEmpty && _uploadPreset.isNotEmpty;

  /// Takes bytes and filename to ensure compatibility across Web and Mobile
  Future<String?> uploadMedia(Uint8List fileBytes, String fileName, bool isVideo) async {
    if (!isConfigured) {
      _log.e('Cloudinary not configured. Missing: ${AppConfig.missingConfigs.join(", ")}');
      return null;
    }

    final String url = "https://api.cloudinary.com/v1_1/$_cloudName/${isVideo ? 'video' : 'image'}/upload";

    try {
      final FormData formData = FormData.fromMap({
        "file": MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
        "upload_preset": _uploadPreset,
        "folder": "majurun",
        "api_key": _apiKey,
      });

      final Response response = await _dio.post(
        url,
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0) {
            _log.v("Upload progress: ${(sent / total * 100).toStringAsFixed(0)}%");
          }
        },
      );

      if (response.statusCode == 200) {
        _log.i('Upload successful: $fileName');
        return response.data['secure_url'];
      }
      _log.w('Upload failed with status: ${response.statusCode}');
      return null;
    } catch (e) {
      _log.e('Upload error', error: e);
      return null;
    }
  }
}
