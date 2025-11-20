// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
  /// Send images and notes to backend to create a video with text overlays.
  ///
  /// Parameters:
  /// - [images]: List of image files to include in the video
  /// - [notes]: List of text captions (one per image). Can be empty strings if no caption needed.
  /// - [textOverlays]: List of text to overlay on each image (NEW)
  /// - [textAnimation]: Animation type for text (fadein, fadeout, typewriter, slidein, etc.)
  /// - [textPosition]: Position of text (top, center, bottom)
  /// - [textColor]: Color of text (white, black, red, etc.)
  /// - [fontSize]: Font size for text overlay
  /// - [musicUrl]: Optional URL to background music file
  /// - [musicFile]: Optional local music file to upload
  /// - [durationPerImage]: How many seconds each image should display (default: 2)
  static Future<Map<String, dynamic>> generateVideo({
    required List<File> images,
    required List<String> notes,
    List<String>? textOverlays, // NEW: Text to overlay on each image
    String textAnimation = 'fadein', // NEW: Animation type
    String textPosition = 'bottom', // NEW: Text position
    String textColor = 'white', // NEW: Text color
    int fontSize = 48, // NEW: Font size
    String? musicUrl,
    File? musicFile,
    int durationPerImage = 2,
  }) async {
    if (images.isEmpty) {
      throw Exception('At least one image is required');
    }

    // Ensure notes array matches images length
    final paddedNotes = List<String>.from(notes);
    while (paddedNotes.length < images.length) {
      paddedNotes.add('');
    }

    // Ensure textOverlays matches images length
    final paddedTextOverlays = textOverlays != null
        ? List<String>.from(textOverlays)
        : List<String>.filled(images.length, '');
    while (paddedTextOverlays.length < images.length) {
      paddedTextOverlays.add('');
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

    // Add form fields
    request.fields['notes'] = jsonEncode(paddedNotes);
    request.fields['textOverlays'] = jsonEncode(paddedTextOverlays); // NEW
    request.fields['textAnimation'] = textAnimation; // NEW
    request.fields['textPosition'] = textPosition; // NEW
    request.fields['textColor'] = textColor; // NEW
    request.fields['fontSize'] = fontSize.toString(); // NEW
    request.fields['duration'] = durationPerImage.toString();

    // Handle music URL
    if (musicUrl != null && musicUrl.isNotEmpty) {
      request.fields['musicUrl'] = musicUrl;
    }

    print('📤 Sending video generation request with ${images.length} images');
    print('📝 Text overlays: ${paddedTextOverlays.length} entries');
    print('✨ Animation: $textAnimation');

    // Send request
    final streamed = await request.send();
    final respStr = await streamed.stream.bytesToString();

    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      final response = jsonDecode(respStr) as Map<String, dynamic>;

      final renderId = response['data']?['response']?['id'];
      if (renderId != null) {
        print('✅ Render queued: $renderId');
      }

      return response;
    } else {
      throw Exception('Video generation failed: ${streamed.statusCode} $respStr');
    }
  }

  /// Edit an existing video with new text overlays and animations
  ///
  /// Parameters:
  /// - [originalRenderId]: The render ID of the original video
  /// - [textOverlays]: Updated text overlays
  /// - [textAnimation]: New animation type
  /// - [textPosition]: New text position
  /// - [textColor]: New text color
  /// - [fontSize]: New font size
  /// - [durationPerImage]: Updated duration per image
  static Future<Map<String, dynamic>> editVideo({
    required String originalRenderId,
    required List<String> textOverlays,
    String textAnimation = 'fadein',
    String textPosition = 'bottom',
    String textColor = 'white',
    int fontSize = 48,
    int durationPerImage = 2,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/edit-video');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'originalRenderId': originalRenderId,
        'textOverlays': jsonEncode(textOverlays),
        'textAnimation': textAnimation,
        'textPosition': textPosition,
        'textColor': textColor,
        'fontSize': fontSize,
        'duration': durationPerImage,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      print('✏️ Video edit queued: ${data['data']?['response']?['id']}');

      return data;
    } else {
      throw Exception('Video edit failed: ${response.statusCode} ${response.body}');
    }
  }

  /// Poll backend for render status
  static Future<Map<String, dynamic>> checkRenderStatus(String renderId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/render-status/$renderId');

    final resp = await http.get(uri);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;

      final status = data['data']?['response']?['status'];
      final progress = data['data']?['response']?['progress'];

      if (status != null) {
        print('📊 Render $renderId: $status (${progress ?? 0}%)');
      }

      return data;
    } else {
      throw Exception('Status check failed: ${resp.statusCode} ${resp.body}');
    }
  }

  /// Check if the backend is healthy
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