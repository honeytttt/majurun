import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class S3Service {
  final String _bucketName = 'majurun-media-prod';
  final String _region = 'ap-southeast-1';

  /// Standard upload method for any Uint8List bytes
  Future<String?> uploadFile(
      Uint8List bytes, String fileName, String contentType) async {
    try {
      final url = Uri.parse('https://$_bucketName.s3.$_region.amazonaws.com/$fileName');
      
      debugPrint("Attempting upload to: $url");

      final response = await http.put(
        url,
        body: bytes,
        headers: {
          'Content-Type': contentType,
        },
      );

      if (response.statusCode == 200) {
        final finalUrl = 'https://$_bucketName.s3.$_region.amazonaws.com/$fileName';
        debugPrint("Upload Success: $finalUrl");
        return finalUrl;
      } else {
        debugPrint("S3 Error ${response.statusCode}: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("S3 Service Runtime Error: $e");
      return null;
    }
  }

  /// NEW: Specifically for Web to bypass the blank 107-byte snapshot issue.
  /// This downloads the map from Google's servers and uploads it to S3.
  Future<String?> downloadAndUploadMap(String staticMapUrl, String fileName) async {
    try {
      debugPrint("🌐 Fetching static map from Google...");
      final response = await http.get(Uri.parse(staticMapUrl));
      
      if (response.statusCode == 200) {
        debugPrint("✅ Map bytes received: ${response.bodyBytes.length} bytes");
        return await uploadFile(response.bodyBytes, fileName, 'image/png');
      } else {
        debugPrint("❌ Failed to download static map: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ Error in downloadAndUploadMap: $e");
      return null;
    }
  }

  Future<void> deleteOldImage(String fileUrl) async {
    if (fileUrl.isEmpty || !fileUrl.contains(_bucketName)) return;
    
    try {
      String fileName = fileUrl.split('/').last;
      if (fileName.contains('?')) {
        fileName = fileName.split('?').first;
      }

      final url = Uri.parse('https://$_bucketName.s3.$_region.amazonaws.com/$fileName');
      
      debugPrint("🧹 S3: Attempting to delete old file: $fileName");
      
      final response = await http.delete(url); 
      
      if (response.statusCode == 204 || response.statusCode == 200) {
        debugPrint("✅ S3: Successfully deleted old image: $fileName");
      } else {
        debugPrint("⚠️ S3: Delete status code: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ S3: Failed to delete old image: $e");
    }
  }
}