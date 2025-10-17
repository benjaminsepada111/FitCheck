import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/image_storage_service.dart';

/// Quick test page to debug image upload
/// Navigate to this page and test image upload directly
class TestImageUploadPage extends StatefulWidget {
  const TestImageUploadPage({super.key});

  @override
  State<TestImageUploadPage> createState() => _TestImageUploadPageState();
}

class _TestImageUploadPageState extends State<TestImageUploadPage> {
  File? _selectedImage;
  String? _uploadedUrl;
  bool _isUploading = false;
  String _testChallengeId = 'test_challenge_123';
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndUploadImage() async {
    try {
      // Check auth
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMessage('Error: Not logged in!');
        return;
      }

      debugPrint('🔐 Logged in as: ${user.email}');

      // Pick image
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile == null) {
        debugPrint('❌ No image picked');
        return;
      }

      final imageFile = File(pickedFile.path);
      debugPrint('📸 Image picked: ${imageFile.path}');
      debugPrint('📏 File size: ${await imageFile.length()} bytes');

      setState(() {
        _selectedImage = imageFile;
        _isUploading = true;
        _uploadedUrl = null;
      });

      // Upload
      debugPrint('📤 Starting upload with challengeId: $_testChallengeId');
      final url = await ImageStorageService.uploadFoodImage(
        imageFile,
        challengeId: _testChallengeId,
      );

      setState(() {
        _uploadedUrl = url;
        _isUploading = false;
      });

      if (url != null) {
        debugPrint('✅ Upload successful! URL: $url');
        _showMessage('Upload successful!');
      } else {
        debugPrint('❌ Upload failed - returned null');
        _showMessage('Upload failed!');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() => _isUploading = false);
      _showMessage('Error: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Image Upload'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('User: ${user?.email ?? "Not logged in"}'),
            const SizedBox(height: 16),

            TextField(
              decoration: const InputDecoration(
                labelText: 'Test Challenge ID',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: _testChallengeId),
              onChanged: (value) => _testChallengeId = value,
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickAndUploadImage,
              icon: const Icon(Icons.upload_file),
              label: Text(_isUploading ? 'Uploading...' : 'Pick & Upload Image'),
            ),
            const SizedBox(height: 24),

            if (_selectedImage != null) ...[
              const Text('Selected Image:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.file(_selectedImage!, fit: BoxFit.contain),
              ),
              const SizedBox(height: 16),
            ],

            if (_uploadedUrl != null) ...[
              const Text('Uploaded URL:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SelectableText(_uploadedUrl!),
              const SizedBox(height: 16),
              const Text('Image from Cloud:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.network(
                  _uploadedUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(child: Text('Error loading: $error'));
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
