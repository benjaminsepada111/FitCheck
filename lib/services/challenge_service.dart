import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/challenge.dart';
import 'image_storage_service.dart';

class ChallengeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _usersCollection = 'users';
  static const String _challengesCollection = 'challenges';
  static const String _daysCollection = 'days';

  /// Create a new challenge
  static Future<bool> createChallenge(Challenge challenge) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challenge.id)
          .set(challenge.toJson());

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get all challenges for the current user
  static Future<List<Challenge>> getUserChallenges() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return [];
      }

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Challenge.fromJson(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get a specific challenge by ID
  static Future<Challenge?> getChallenge(String challengeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return null;
      }

      final doc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .get();

      if (doc.exists && doc.data() != null) {
        return Challenge.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update a challenge
  static Future<bool> updateChallenge(Challenge challenge) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challenge.id)
          .update(challenge.toJson());

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Cancel a challenge (marks it as cancelled without deleting)
  static Future<bool> cancelChallenge(String challengeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      // Update both lifecycleStatus and cancelledAt timestamp
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .update({
            'lifecycleStatus': 'cancelled',
            'cancelledAt': DateTime.now().toIso8601String(),
          });

      return true;
    } catch (e) {
      print('Error cancelling challenge: $e');
      return false;
    }
  }

  /// Delete a challenge and all its days permanently
  /// This should only be used from challenge history
  /// Also deletes all associated images from Firebase Storage
  static Future<bool> deleteChallenge(String challengeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error deleting challenge: User not authenticated');
        return false;
      }

      print('Starting deletion of challenge: $challengeId');

      // Step 1: Delete all images from Firebase Storage
      print('Step 1: Deleting all images for challenge...');
      await ImageStorageService.deleteAllChallengeImages(challengeId);

      // Step 2: Delete all milestone documents
      print('Step 2: Deleting milestone documents...');
      final milestonesSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection('milestones')
          .get();

      WriteBatch batch = _firestore.batch();
      for (var doc in milestonesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Step 3: Delete all food log documents
      print('Step 3: Deleting food log documents...');
      final foodLogsSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection('food_logs')
          .get();

      for (var doc in foodLogsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Step 4: Delete all workout documents
      print('Step 4: Deleting workout documents...');
      final workoutsSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection('workouts')
          .get();

      for (var doc in workoutsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Step 5: Delete all day documents
      print('Step 5: Deleting challenge days...');
      final daysSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_daysCollection)
          .get();

      for (var doc in daysSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Step 6: Delete the challenge document itself
      print('Step 6: Deleting challenge document...');
      batch.delete(
        _firestore
            .collection(_usersCollection)
            .doc(user.uid)
            .collection(_challengesCollection)
            .doc(challengeId),
      );

      // Commit all deletions
      await batch.commit();

      print('✅ Challenge $challengeId deleted successfully with all data and images');
      return true;
    } catch (e) {
      print('Error deleting challenge: $e');
      return false;
    }
  }

  /// Add or update a challenge day
  static Future<bool> saveChallengeDay(
    String challengeId,
    ChallengeDay day,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_daysCollection)
          .doc(day.dayId)
          .set(day.toJson());

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get all days for a specific challenge
  static Future<List<ChallengeDay>> getChallengeDays(String challengeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return [];
      }

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_daysCollection)
          .orderBy('dayNumber')
          .get();

      return querySnapshot.docs
          .map((doc) => ChallengeDay.fromJson(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get a specific challenge day
  static Future<ChallengeDay?> getChallengeDay(
    String challengeId,
    String dayId,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return null;
      }

      final doc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_daysCollection)
          .doc(dayId)
          .get();

      if (doc.exists && doc.data() != null) {
        return ChallengeDay.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Mark a challenge day as completed
  static Future<bool> completeChallengeDay(
    String challengeId,
    String dayId,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_daysCollection)
          .doc(dayId)
          .update({
            'completed': true,
            'completedAt': DateTime.now().toIso8601String(),
          });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get active challenges for the current user (excludes cancelled and completed challenges)
  static Future<List<Challenge>> getActiveChallenges() async {
    try {
      final allChallenges = await getUserChallenges();
      final now = DateTime.now();

      // Filter challenges that are:
      // 1. Not explicitly cancelled
      // 2. Not explicitly marked as completed
      // 3. Within the active date range
      return allChallenges.where((challenge) {
        // Exclude cancelled challenges
        if (challenge.lifecycleStatus == 'cancelled') return false;

        // Exclude explicitly completed challenges
        if (challenge.lifecycleStatus == 'completed') return false;

        // Check if within active date range
        final isInDateRange =
            now.isAfter(challenge.startDate) &&
            now.isBefore(challenge.endDate.add(const Duration(days: 1)));

        return isInDateRange;
      }).toList();
    } catch (e) {
      print('Error getting active challenges: $e');
      return [];
    }
  }

  /// Listen to challenges in real-time
  static Stream<List<Challenge>> getChallengesStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_usersCollection)
        .doc(user.uid)
        .collection(_challengesCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Challenge.fromJson(doc.data()))
              .toList();
        });
  }

  /// Generate a unique challenge ID
  static String generateChallengeId() {
    return _firestore.collection('temp').doc().id;
  }
}
