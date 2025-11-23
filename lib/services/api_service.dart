// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
  /// Send images and notes to backend to create a Shotstack render.
  /// Returns the Shotstack render response object (which includes a render id).
  ///
  /// Parameters:
  /// - [images]: List of image files to include in the video
  /// - [notes]: List of text captions (one per image). Can be empty strings if no caption needed.
  /// - [musicUrl]: Optional URL to background music file (mp3, wav, etc.)
  /// - [musicFile]: Optional local music file to upload (alternative to musicUrl)
  /// - [durationPerImage]: How many seconds each image should display (default: 2)
  static Future<Map<String, dynamic>> generateVideo({
    required List<File> images,
    required List<String> notes,
    String? musicUrl,
    String? aspectRatio,
    File? musicFile,
    int durationPerImage = 2,
  }) async {
    if (images.isEmpty) {
      throw Exception('At least one image is required');
    }

    // Ensure notes array matches images length (pad with empty strings if needed)
    final paddedNotes = List<String>.from(notes);
    while (paddedNotes.length < images.length) {
      paddedNotes.add('');
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/generate-video');
    final request = http.MultipartRequest('POST', uri);

    // Attach image files
    for (var i = 0; i < images.length; i++) {
      final img = images[i];
      final fileName = img.path.split('/').last;
      request.files.add(
        await http.MultipartFile.fromPath(
          'images',
          img.path,
          filename: fileName,
        ),
      );
    }

    // Attach music file if provided
    if (musicFile != null) {
      final musicFileName = musicFile.path.split('/').last;
      request.files.add(
        await http.MultipartFile.fromPath(
          'music',
          musicFile.path,
          filename: musicFileName,
        ),
      );
    }

    // 🆕 CRITICAL: Send text logs as JSON array
    request.fields['textLogs'] = jsonEncode(paddedNotes);
    request.fields['duration'] = durationPerImage.toString();

    // Handle music URL
    if (musicFile == null && musicUrl != null && musicUrl.isNotEmpty) {
      request.fields['musicUrl'] = musicUrl;
    }

    print('📝 Sending ${paddedNotes.length} text logs to backend');

    // Send request
    final streamed = await request.send();
    final respStr = await streamed.stream.bytesToString();

    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      final response = jsonDecode(respStr) as Map<String, dynamic>;

      // Extract and log render ID if available
      final renderId = response['data']?['response']?['id'];
      if (renderId != null) {
        print('✅ Video render started: $renderId');
      }

      return response;
    } else {
      throw Exception('Video generation failed: ${streamed.statusCode} $respStr');
    }
  }

  /// Poll backend for Shotstack render status. Returns backend JSON response.
  ///
  /// The response will include:
  /// - status: 'queued', 'rendering', 'done', 'failed'
  /// - url: Video URL (when status is 'done')
  /// - progress: Render progress percentage (0-100)
  static Future<Map<String, dynamic>> checkRenderStatus(String renderId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/render-status/$renderId');

    final resp = await http.get(uri);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;

      // Log status for debugging
      final status = data['data']?['response']?['status'];
      final progress = data['data']?['response']?['progress'];

      return data;
    } else {
      throw Exception('Status check failed: ${resp.statusCode} ${resp.body}');
    }
  }

  /// Check if the backend is healthy and properly configured
  static Future<Map<String, dynamic>> checkHealth() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/health');

    try {
      final resp = await http.get(uri).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Health check timeout'),
      );

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      } else {
        throw Exception('Health check returned: ${resp.statusCode}');
      }
    } catch (e) {
      throw Exception('Backend unreachable: $e');
    }
  }
}