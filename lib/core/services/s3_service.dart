import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class S3Service {
  final String _bucketName = 'majurun-media-prod';
  final String _region = 'ap-southeast-1';

  Future<String?> uploadFile(
      Uint8List bytes, String fileName, String contentType) async {
    try {
      // The URL must be exact
      final url = Uri.parse('https://$_bucketName.s3.$_region.amazonaws.com/$fileName');
      
      debugPrint("Attempting upload to: $url");

      final response = await http.put(
        url,
        body: bytes,
        headers: {
          'Content-Type': contentType,
          // We remove x-amz-acl for now to ensure the request 
          // isn't rejected for lack of a signature. 
          // The Bucket Policy handles the permissions.
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
}