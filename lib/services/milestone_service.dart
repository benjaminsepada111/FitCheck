import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/milestone.dart';

class MilestoneService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _usersCollection = 'users';
  static const String _milestonesCollection = 'milestones';

  /// Save a milestone (with optional image upload)
  static Future<bool> saveMilestone(Milestone milestone, {File? imageFile}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error: No authenticated user found');
        return false;
      }

      Milestone milestoneToSave = milestone;

      // Upload image if provided
      if (imageFile != null) {
        final imageUrl = await _uploadImage(user.uid, milestone.id, imageFile);
        if (imageUrl != null) {
          milestoneToSave = milestone.copyWith(imageUrl: imageUrl);
        }
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_milestonesCollection)
          .doc(milestone.id)
          .set(milestoneToSave.toJson());

      print('Milestone saved for date: ${milestone.date}');
      return true;
    } catch (e) {
      print('Error saving milestone: $e');
      return false;
    }
  }

  /// Upload image to Firebase Storage
  static Future<String?> _uploadImage(String userId, String milestoneId, File imageFile) async {
    try {
      final ref = _storage
          .ref()
          .child('users')
          .child(userId)
          .child('milestones')
          .child('$milestoneId.jpg');

      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      print('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  /// Get milestone for a specific date
  static Future<Milestone?> getMilestoneForDate(DateTime date) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error: No authenticated user found');
        return null;
      }

      // Create date range for the entire day
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_milestonesCollection)
          .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('date', isLessThan: endOfDay.toIso8601String())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return Milestone.fromJson(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error getting milestone for date: $e');
      return null;
    }
  }

  /// Get milestones for a date range
  static Future<List<Milestone>> getMilestonesForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error: No authenticated user found');
        return [];
      }

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_milestonesCollection)
          .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Milestone.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting milestones for date range: $e');
      return [];
    }
  }

  /// Get all milestones for the current user (paginated)
  static Future<List<Milestone>> getAllMilestones({
    int limit = 50,
    DocumentSnapshot? lastDoc,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error: No authenticated user found');
        return [];
      }

      Query query = _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_milestonesCollection)
          .orderBy('date', descending: true)
          .limit(limit);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => Milestone.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting all milestones: $e');
      return [];
    }
  }

  /// Get a specific milestone by ID
  static Future<Milestone?> getMilestone(String milestoneId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error: No authenticated user found');
        return null;
      }

      final doc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_milestonesCollection)
          .doc(milestoneId)
          .get();

      if (doc.exists && doc.data() != null) {
        return Milestone.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting milestone: $e');
      return null;
    }
  }

  /// Update a milestone
  static Future<bool> updateMilestone(Milestone milestone, {File? newImageFile}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error: No authenticated user found');
        return false;
      }

      Milestone milestoneToUpdate = milestone.copyWith(updatedAt: DateTime.now());

      // Upload new image if provided
      if (newImageFile != null) {
        // Delete old image if exists
        if (milestone.imageUrl != null) {
          await _deleteImage(milestone.imageUrl!);
        }

        final imageUrl = await _uploadImage(user.uid, milestone.id, newImageFile);
        if (imageUrl != null) {
          milestoneToUpdate = milestoneToUpdate.copyWith(imageUrl: imageUrl);
        }
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_milestonesCollection)
          .doc(milestone.id)
          .update(milestoneToUpdate.toJson());

      print('Milestone updated: ${milestone.id}');
      return true;
    } catch (e) {
      print('Error updating milestone: $e');
      return false;
    }
  }

  /// Delete a milestone and its image
  static Future<bool> deleteMilestone(String milestoneId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error: No authenticated user found');
        return false;
      }

      // Get milestone to find image URL
      final milestone = await getMilestone(milestoneId);

      // Delete image if exists
      if (milestone?.imageUrl != null) {
        await _deleteImage(milestone!.imageUrl!);
      }

      // Delete milestone document
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_milestonesCollection)
          .doc(milestoneId)
          .delete();

      print('Milestone deleted: $milestoneId');
      return true;
    } catch (e) {
      print('Error deleting milestone: $e');
      return false;
    }
  }

  /// Delete image from Firebase Storage
  static Future<void> _deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      print('Image deleted from storage');
    } catch (e) {
      print('Error deleting image: $e');
    }
  }

  /// Get milestones with images only
  static Future<List<Milestone>> getMilestonesWithImages({int limit = 20}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error: No authenticated user found');
        return [];
      }

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_milestonesCollection)
          .where('imageUrl', isNotEqualTo: null)
          .orderBy('imageUrl') // Required for isNotEqualTo
          .orderBy('date', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => Milestone.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting milestones with images: $e');
      return [];
    }
  }

  /// Listen to milestones in real-time
  static Stream<List<Milestone>> getMilestonesStream({int limit = 50}) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_usersCollection)
        .doc(user.uid)
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
  static Future<Map<String, int>> getMonthlySummary(int year) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error: No authenticated user found');
        return {};
      }

      final startOfYear = DateTime(year, 1, 1);
      final endOfYear = DateTime(year + 1, 1, 1);

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
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
      print('Error getting monthly summary: $e');
      return {};
    }
  }
}