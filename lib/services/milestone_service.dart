import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/milestone.dart';

class MilestoneService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _usersCollection = 'users';
  static const String _challengesCollection = 'challenges';
  static const String _milestonesCollection = 'milestones';

  /// Save a milestone (with optional image saved locally)
  static Future<bool> saveMilestone(Milestone milestone, {File? imageFile, required String challengeId}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return false;
      }

      Milestone milestoneToSave = milestone;

      // Save image locally if provided
      if (imageFile != null) {
        final imagePath = await _saveImageLocally(user.uid, challengeId, milestone.id, imageFile);
        if (imagePath != null) {
          milestoneToSave = milestone.copyWith(imagePath: imagePath);
        }
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_milestonesCollection)
          .doc(milestone.id)
          .set(milestoneToSave.toJson());

      debugPrint('Milestone saved for date: ${milestone.date}');
      return true;
    } catch (e) {
      debugPrint('Error saving milestone: $e');
      return false;
    }
  }

  /// Save image to local storage
  static Future<String?> _saveImageLocally(String userId, String challengeId, String milestoneId, File imageFile) async {
    try {
      // Get the app's document directory
      final directory = await getApplicationDocumentsDirectory();

      // Create a directory structure for milestone images
      final milestoneImagesDir = Directory(
        path.join(directory.path, 'milestone_journey', userId, challengeId)
      );

      // Create the directory if it doesn't exist
      if (!await milestoneImagesDir.exists()) {
        await milestoneImagesDir.create(recursive: true);
      }

      // Get the file extension
      final extension = path.extension(imageFile.path);

      // Create the destination file path
      final destinationPath = path.join(
        milestoneImagesDir.path,
        '$milestoneId$extension'
      );

      // Copy the image file to the destination
      final savedFile = await imageFile.copy(destinationPath);

      debugPrint('Image saved locally: ${savedFile.path}');
      return savedFile.path;
    } catch (e) {
      debugPrint('Error saving image locally: $e');
      return null;
    }
  }

  /// Get milestone for a specific date
  static Future<Milestone?> getMilestoneForDate(DateTime date, {required String challengeId}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return null;
      }

      // Use date-based ID for direct lookup (more efficient)
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final milestoneId = createDateBasedId(normalizedDate);

      final doc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_milestonesCollection)
          .doc(milestoneId)
          .get();

      if (doc.exists && doc.data() != null) {
        return Milestone.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting milestone for date: $e');
      return null;
    }
  }

  /// Get milestones for a date range
  static Future<List<Milestone>> getMilestonesForDateRange(
    DateTime startDate,
    DateTime endDate, {
    required String challengeId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return [];
      }

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_milestonesCollection)
          .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Milestone.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting milestones for date range: $e');
      return [];
    }
  }

  /// Get all milestones for the current user (paginated)
  static Future<List<Milestone>> getAllMilestones({
    int limit = 50,
    DocumentSnapshot? lastDoc,
    required String challengeId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return [];
      }

      Query query = _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_milestonesCollection)
          .orderBy('date', descending: true)
          .limit(limit);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final querySnapshot = await query.get();

      debugPrint('🔍 getAllMilestones - Found ${querySnapshot.docs.length} documents for challengeId: $challengeId');
      debugPrint('🔍 Query path: users/${user.uid}/challenges/$challengeId/milestones');

      final milestones = querySnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            debugPrint('  📄 Milestone: ${doc.id}, imageUrl: ${data['imageUrl']}, imagePath: ${data['imagePath']}');
            return Milestone.fromJson(data);
          })
          .toList();

      debugPrint('🔍 Returning ${milestones.length} milestones');
      return milestones;
    } catch (e) {
      debugPrint('❌ Error getting all milestones: $e');
      return [];
    }
  }

  /// Get a specific milestone by ID
  static Future<Milestone?> getMilestone(String milestoneId, {required String challengeId}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return null;
      }

      final doc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_milestonesCollection)
          .doc(milestoneId)
          .get();

      if (doc.exists && doc.data() != null) {
        return Milestone.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting milestone: $e');
      return null;
    }
  }

  /// Update a milestone
  static Future<bool> updateMilestone(Milestone milestone, {File? newImageFile, required String challengeId}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return false;
      }

      Milestone milestoneToUpdate = milestone.copyWith(updatedAt: DateTime.now());

      // Save new image locally if provided
      if (newImageFile != null) {
        // Delete old image if exists
        if (milestone.imagePath != null) {
          await _deleteLocalImage(milestone.imagePath!);
        }

        final imagePath = await _saveImageLocally(user.uid, challengeId, milestone.id, newImageFile);
        if (imagePath != null) {
          milestoneToUpdate = milestoneToUpdate.copyWith(imagePath: imagePath);
        }
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_milestonesCollection)
          .doc(milestone.id)
          .update(milestoneToUpdate.toJson());

      debugPrint('Milestone updated: ${milestone.id}');
      return true;
    } catch (e) {
      debugPrint('Error updating milestone: $e');
      return false;
    }
  }

  /// Delete a milestone and its image
  static Future<bool> deleteMilestone(String milestoneId, {required String challengeId}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return false;
      }

      // Get milestone to find image path
      final milestone = await getMilestone(milestoneId, challengeId: challengeId);

      // Delete local image if exists
      if (milestone?.imagePath != null) {
        await _deleteLocalImage(milestone!.imagePath!);
      }

      // Delete milestone document
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_milestonesCollection)
          .doc(milestoneId)
          .delete();

      debugPrint('Milestone deleted: $milestoneId');
      return true;
    } catch (e) {
      debugPrint('Error deleting milestone: $e');
      return false;
    }
  }

  /// Delete local image file
  static Future<void> _deleteLocalImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Local image deleted: $imagePath');
      }
    } catch (e) {
      debugPrint('Error deleting local image: $e');
    }
  }

  /// Get milestones with images only
  static Future<List<Milestone>> getMilestonesWithImages({int limit = 20, required String challengeId}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return [];
      }

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_milestonesCollection)
          .where('imagePath', isNotEqualTo: null)
          .orderBy('imagePath') // Required for isNotEqualTo
          .orderBy('date', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => Milestone.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting milestones with images: $e');
      return [];
    }
  }

  /// Listen to milestones in real-time
  static Stream<List<Milestone>> getMilestonesStream({int limit = 50, required String challengeId}) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_usersCollection)
        .doc(user.uid)
        .collection(_challengesCollection)
        .doc(challengeId)
        .collection(_milestonesCollection)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Milestone.fromJson(doc.data()))
          .toList();
    });
  }

  /// Generate a unique milestone ID
  static String generateMilestoneId() {
    return _firestore.collection('temp').doc().id;
  }

  /// Create a milestone ID based on date (for easier querying)
  static String createDateBasedId(DateTime date) {
    return 'milestone_${date.year}_${date.month.toString().padLeft(2, '0')}_${date.day.toString().padLeft(2, '0')}';
  }

  /// Get monthly milestone summary (count of milestones per month)
  static Future<Map<String, int>> getMonthlySummary(int year, {required String challengeId}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return {};
      }

      final startOfYear = DateTime(year, 1, 1);
      final endOfYear = DateTime(year + 1, 1, 1);

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_milestonesCollection)
          .where('date', isGreaterThanOrEqualTo: startOfYear.toIso8601String())
          .where('date', isLessThan: endOfYear.toIso8601String())
          .get();

      final monthlyCounts = <String, int>{};

      for (final doc in querySnapshot.docs) {
        final milestone = Milestone.fromJson(doc.data());
        final monthKey = '${milestone.date.year}-${milestone.date.month.toString().padLeft(2, '0')}';
        monthlyCounts[monthKey] = (monthlyCounts[monthKey] ?? 0) + 1;
      }

      return monthlyCounts;
    } catch (e) {
      debugPrint('Error getting monthly summary: $e');
      return {};
    }
  }
}