import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for handling image uploads to Firebase Cloud Storage
/// Organizes images by user and category for optimal data management
class ImageStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Upload a food image to Cloud Storage (per challenge)
  /// Returns the download URL if successful, null otherwise
  ///
  /// Images are stored in: users/{userId}/challenges/{challengeId}/food/{timestamp}_{filename}
  static Future<String?> uploadFoodImage(
    File imageFile, {
    required String challengeId,
  }) async {
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
  static Future<String?> uploadWorkoutImage(
    File imageFile, {
    required String challengeId,
  }) async {
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
  static Future<String?> uploadMilestoneImage(
    File imageFile, {
    required String challengeId,
  }) async {
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
    print('Uploading profile image...');
    final result = await _uploadImage(
      imageFile: imageFile,
      category: 'profile',
      challengeId: null, // Profile images are not challenge-specific
    );
    if (result != null) {
      print('Profile image uploaded successfully: $result');
    } else {
      print('Profile image upload failed');
    }
    return result;
  }

  /// Generic image upload method
  /// Handles compression, naming, and storage organization
  static Future<String?> _uploadImage({
    required File imageFile,
    required String category,
    String? challengeId, // null for profile images
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return null;
      }

      // Check if file exists
      final fileExists = await imageFile.exists();
      if (!fileExists) {
        return null;
      }

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${imageFile.path.split('/').last}';

      // Create storage path based on whether it's challenge-specific or not
      final storagePath = challengeId != null
          ? 'users/${user.uid}/challenges/$challengeId/$category/$fileName'
          : 'users/${user.uid}/$category/$fileName';

      print('Storage path: $storagePath');

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
      final uploadTask = storageRef.putFile(imageFile, metadata);

      // Wait for completion
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      // Log error for debugging
      print('Error uploading image: $e');
      return null;
    }
  }

  /// Delete an image from Cloud Storage using its URL
  /// Returns true if successful, false otherwise
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error deleting image: User not authenticated');
        return false;
      }

      print('Attempting to delete image: $imageUrl');

      // Extract path from URL
      final ref = _storage.refFromURL(imageUrl);
      print('Storage reference path: ${ref.fullPath}');

      // Delete the file
      await ref.delete();

      print('✅ Image deleted successfully: ${ref.fullPath}');
      return true;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }

  /// Get storage usage for current user (in bytes)
  /// Returns total size of all user images
  static Future<int> getUserStorageUsage() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
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

      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Delete all images for a specific category within a challenge
  /// Useful for cleanup operations
  static Future<bool> deleteAllImagesInCategory(
    String category, {
    String? challengeId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error deleting images: User not authenticated');
        return false;
      }

      final categoryPath = challengeId != null
          ? 'users/${user.uid}/challenges/$challengeId/$category'
          : 'users/${user.uid}/$category';

      print('Deleting all images in: $categoryPath');

      final listResult = await _storage.ref().child(categoryPath).listAll();

      int deletedCount = 0;
      for (final item in listResult.items) {
        await item.delete();
        deletedCount++;
      }

      print('Deleted $deletedCount images from $categoryPath');
      return true;
    } catch (e) {
      print('Error deleting images in category: $e');
      return false;
    }
  }

  /// Delete ALL images for a specific challenge (all categories)
  /// This is called when a challenge is deleted
  static Future<bool> deleteAllChallengeImages(String challengeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error deleting challenge images: User not authenticated');
        return false;
      }

      final challengePath = 'users/${user.uid}/challenges/$challengeId';
      print('Deleting all images for challenge: $challengePath');

      final listResult = await _storage.ref().child(challengePath).listAll();

      int totalDeleted = 0;

      // Delete all items in all subdirectories (milestones, food, workouts, etc.)
      for (final prefix in listResult.prefixes) {
        final categoryResult = await prefix.listAll();
        for (final item in categoryResult.items) {
          await item.delete();
          totalDeleted++;
        }
      }

      // Delete any items directly in the challenge folder
      for (final item in listResult.items) {
        await item.delete();
        totalDeleted++;
      }

      print('✅ Deleted $totalDeleted images for challenge $challengeId');
      return true;
    } catch (e) {
      print('Error deleting all challenge images: $e');
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
      return false;
    }
  }
}
