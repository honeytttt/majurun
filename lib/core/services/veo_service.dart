import 'dart:convert';
import 'package:http/http.dart' as http;

class VeoService {
  final String apiKey;
  final String baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  VeoService({required this.apiKey});

  /// Starts the video generation process
  Future<String?> generateRunReplay({
    required String prompt,
    String aspectRatio = '9:16',
  }) async {
    final url = Uri.parse('$baseUrl/models/veo-3.1-fast-generate-preview:generateVideos?key=$apiKey');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'prompt': prompt,
        'video_config': {
          'aspect_ratio': aspectRatio,
          'resolution': '720p',
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Returns the 'operation name' to poll for results
      return data['name']; 
    }
    return null;
  }

  /// Polls the status of the video generation
  Future<String?> pollVideoStatus(String operationName) async {
    final url = Uri.parse('$baseUrl/$operationName?key=$apiKey');

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['done'] == true) {
        // Return the final video URL from the response
        return data['response']['generatedVideos'][0]['videoUri'];
      }
    }
    return null; // Still processing or error
  }
}