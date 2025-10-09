// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart'; // ✅ Import your config file

class ApiService {
  /// Send images and notes to backend to create a Shotstack render.
  /// Returns the Shotstack render response object (which includes a render id).
  static Future<Map<String, dynamic>> generateVideo({
    required List<File> images,
    required List<String> notes,
    String? musicUrl,
    int durationPerImage = 2,
  }) async {
    // ✅ Use your configured baseUrl
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/generate-video');
    final request = http.MultipartRequest('POST', uri);

    // Attach images
    for (var img in images) {
      final fileName = img.path.split('/').last;
      request.files.add(await http.MultipartFile.fromPath('images', img.path, filename: fileName));
    }

    // Fields: notes (JSON), duration, optional musicUrl
    request.fields['notes'] = jsonEncode(notes);
    request.fields['duration'] = durationPerImage.toString();
    if (musicUrl != null) request.fields['musicUrl'] = musicUrl;

    final streamed = await request.send();
    final respStr = await streamed.stream.bytesToString();
    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return jsonDecode(respStr) as Map<String, dynamic>;
    } else {
      throw Exception('Video generation failed: ${streamed.statusCode} $respStr');
    }
  }

  /// Poll backend for Shotstack render status. Returns backend JSON response.
  static Future<Map<String, dynamic>> checkRenderStatus(String renderId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/render-status/$renderId');
    final resp = await http.get(uri);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      throw Exception('Status check failed: ${resp.statusCode} ${resp.body}');
    }
  }
}
