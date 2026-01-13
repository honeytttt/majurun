import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CloudinaryService {
  final String cloudName = "ddo14sbqv"; 
  final String uploadPreset = "majurun"; 

  Future<String?> uploadImageBytes(Uint8List bytes) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      
      // FIX: Use utf8.decode for reliable JSON parsing
      final responseString = utf8.decode(responseData);
      final jsonMap = jsonDecode(responseString);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final String secureUrl = jsonMap['secure_url'];
        print("✅ Cloudinary Upload Success: $secureUrl");
        return secureUrl;
      } else {
        print("❌ Cloudinary Error: ${jsonMap['error']?['message'] ?? 'Unknown Error'}");
        return null;
      }
    } catch (e) {
      print("❌ Cloudinary Exception: $e");
      return null;
    }
  }
}