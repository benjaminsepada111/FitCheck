import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for handling image uploads to Firebase Cloud Storage
/// Organizes images by user and category for optimal data management
class ImageStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Upload a food image to Cloud Storage (per challenge)
  /// Returns the download URL if successful, null otherwise
  ///
  /// Images are stored in: users/{userId}/challenges/{challengeId}/food/{timestamp}_{filename}
  static Future<String?> uploadFoodImage(File imageFile, {required String challengeId}) async {
    return _uploadImage(
      imageFile: imageFile,
      category: 'food',
      challengeId: challengeId,
    );
  }

  /// Upload a workout image to Cloud Storage (per challenge)
  /// Returns the download URL if successful, null otherwise
  ///
  /// Images are stored in: users/{userId}/challenges/{challengeId}/workouts/{timestamp}_{filename}
  static Future<String?> uploadWorkoutImage(File imageFile, {required String challengeId}) async {
    return _uploadImage(
      imageFile: imageFile,
      category: 'workouts',
      challengeId: challengeId,
    );
  }

  /// Upload a milestone image to Cloud Storage (per challenge)
  /// Returns the download URL if successful, null otherwise
  ///
  /// Images are stored in: users/{userId}/challenges/{challengeId}/milestones/{timestamp}_{filename}
  static Future<String?> uploadMilestoneImage(File imageFile, {required String challengeId}) async {
    return _uploadImage(
      imageFile: imageFile,
      category: 'milestones',
      challengeId: challengeId,
    );
  }

  /// Upload a profile image to Cloud Storage (NOT per challenge)
  /// Returns the download URL if successful, null otherwise
  ///
  /// Images are stored in: users/{userId}/profile/{timestamp}_{filename}
  static Future<String?> uploadProfileImage(File imageFile) async {
    return _uploadImage(
      imageFile: imageFile,
      category: 'profile',
      challengeId: null, // Profile images are not challenge-specific
    );
  }

  /// Generic image upload method
  /// Handles compression, naming, and storage organization
  static Future<String?> _uploadImage({
    required File imageFile,
    required String category,
    String? challengeId, // null for profile images
  }) async {
    try {
      debugPrint('🔧 _uploadImage called');
      debugPrint('   Image path: ${imageFile.path}');
      debugPrint('   Category: $category');
      debugPrint('   Challenge ID: $challengeId');

      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ Error: No authenticated user found');
        return null;
      }

      debugPrint('✅ User authenticated: ${user.uid}');

      // Check if file exists
      final fileExists = await imageFile.exists();
      if (!fileExists) {
        debugPrint('❌ Error: Image file does not exist at path: ${imageFile.path}');
        return null;
      }

      final fileSize = await imageFile.length();
      debugPrint('✅ File exists, size: $fileSize bytes');

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${imageFile.path.split('/').last}';

      // Create storage path based on whether it's challenge-specific or not
      final storagePath = challengeId != null
          ? 'users/${user.uid}/challenges/$challengeId/$category/$fileName'
          : 'users/${user.uid}/$category/$fileName';

      debugPrint('📤 Uploading image to: $storagePath');

      // Create reference
      final storageRef = _storage.ref().child(storagePath);

      // Set metadata for better organization
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'userId': user.uid,
          'category': category,
          if (challengeId != null) 'challengeId': challengeId,
        },
      );

      // Upload file
      debugPrint('⏳ Starting upload task...');
      final uploadTask = storageRef.putFile(imageFile, metadata);

      // Wait for completion
      debugPrint('⏳ Waiting for upload to complete...');
      final snapshot = await uploadTask;
      debugPrint('✅ Upload completed! State: ${snapshot.state}');

      // Get download URL
      debugPrint('⏳ Getting download URL...');
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ Image uploaded successfully!');
      debugPrint('   Download URL: $downloadUrl');
      return downloadUrl;

    } catch (e, stackTrace) {
      debugPrint('❌ Error uploading image: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Delete an image from Cloud Storage using its URL
  /// Returns true if successful, false otherwise
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return false;
      }

      // Extract path from URL
      final ref = _storage.refFromURL(imageUrl);

      debugPrint('🗑️ Deleting image: ${ref.fullPath}');

      // Delete the file
      await ref.delete();

      debugPrint('✅ Image deleted successfully');
      return true;

    } catch (e) {
      debugPrint('❌ Error deleting image: $e');
      return false;
    }
  }

  /// Get storage usage for current user (in bytes)
  /// Returns total size of all user images
  static Future<int> getUserStorageUsage() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return 0;
      }

      int totalSize = 0;

      // Get all categories
      final categories = ['food', 'workouts', 'milestones'];

      for (final category in categories) {
        final categoryPath = 'users/${user.uid}/$category';
        final listResult = await _storage.ref().child(categoryPath).listAll();

        for (final item in listResult.items) {
          final metadata = await item.getMetadata();
          totalSize += metadata.size ?? 0;
        }
      }

      debugPrint('📊 Total storage usage: ${_formatBytes(totalSize)}');
      return totalSize;

    } catch (e) {
      debugPrint('❌ Error calculating storage usage: $e');
      return 0;
    }
  }

  /// Delete all images for a specific challenge
  /// This is called when a challenge is deleted
  static Future<bool> deleteAllChallengeImages(String challengeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return false;
      }

      final challengePath = 'users/${user.uid}/challenges/$challengeId';
      final listResult = await _storage.ref().child(challengePath).listAll();

      int totalDeleted = 0;

      // Delete all items in subdirectories (food, workouts, milestones)
      for (final prefix in listResult.prefixes) {
        final items = await prefix.listAll();
        for (final item in items.items) {
          await item.delete();
          totalDeleted++;
        }
      }

      debugPrint('✅ Deleted $totalDeleted images from challenge $challengeId');
      return true;

    } catch (e) {
      debugPrint('❌ Error deleting challenge images: $e');
      return false;
    }
  }

  /// Delete all images for a specific category within a challenge
  /// Useful for cleanup operations
  static Future<bool> deleteAllImagesInCategory(String category, {String? challengeId}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return false;
      }

      final categoryPath = challengeId != null
          ? 'users/${user.uid}/challenges/$challengeId/$category'
          : 'users/${user.uid}/$category';

      final listResult = await _storage.ref().child(categoryPath).listAll();

      debugPrint('🗑️ Deleting ${listResult.items.length} images from $category');

      for (final item in listResult.items) {
        await item.delete();
      }

      debugPrint('✅ All images deleted from $category');
      return true;

    } catch (e) {
      debugPrint('❌ Error deleting category images: $e');
      return false;
    }
  }

  /// Format bytes to human-readable size
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Check if an image URL is valid and accessible
  static Future<bool> isImageAccessible(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.getMetadata();
      return true;
    } catch (e) {
      debugPrint('⚠️ Image not accessible: $imageUrl');
      return false;
    }
  }
}
