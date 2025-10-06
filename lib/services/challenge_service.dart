import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/challenge.dart';

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
        debugPrint('Error: No authenticated user found');
        return false;
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challenge.id)
          .set(challenge.toJson());

      debugPrint('Challenge created successfully: ${challenge.title}');
      return true;
    } catch (e) {
      debugPrint('Error creating challenge: $e');
      return false;
    }
  }

  /// Get all challenges for the current user
  static Future<List<Challenge>> getUserChallenges() async {
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
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Challenge.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting user challenges: $e');
      return [];
    }
  }

  /// Get a specific challenge by ID
  static Future<Challenge?> getChallenge(String challengeId) async {
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
          .get();

      if (doc.exists && doc.data() != null) {
        return Challenge.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting challenge: $e');
      return null;
    }
  }

  /// Update a challenge
  static Future<bool> updateChallenge(Challenge challenge) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return false;
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challenge.id)
          .update(challenge.toJson());

      debugPrint('Challenge updated successfully: ${challenge.title}');
      return true;
    } catch (e) {
      debugPrint('Error updating challenge: $e');
      return false;
    }
  }

  /// Delete a challenge and all its days
  static Future<bool> deleteChallenge(String challengeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        return false;
      }

      // Delete all days first
      final daysSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_daysCollection)
          .get();

      WriteBatch batch = _firestore.batch();
      for (var doc in daysSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the challenge document
      batch.delete(_firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId));

      await batch.commit();
      debugPrint('Challenge deleted successfully: $challengeId');
      return true;
    } catch (e) {
      debugPrint('Error deleting challenge: $e');
      return false;
    }
  }

  /// Add or update a challenge day
  static Future<bool> saveChallengeDay(String challengeId, ChallengeDay day) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
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

      debugPrint('Challenge day saved: $challengeId/day${day.dayNumber}');
      return true;
    } catch (e) {
      debugPrint('Error saving challenge day: $e');
      return false;
    }
  }

  /// Get all days for a specific challenge
  static Future<List<ChallengeDay>> getChallengeDays(String challengeId) async {
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
          .collection(_daysCollection)
          .orderBy('dayNumber')
          .get();

      return querySnapshot.docs
          .map((doc) => ChallengeDay.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting challenge days: $e');
      return [];
    }
  }

  /// Get a specific challenge day
  static Future<ChallengeDay?> getChallengeDay(String challengeId, String dayId) async {
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
          .collection(_daysCollection)
          .doc(dayId)
          .get();

      if (doc.exists && doc.data() != null) {
        return ChallengeDay.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting challenge day: $e');
      return null;
    }
  }

  /// Mark a challenge day as completed
  static Future<bool> completeChallengeDay(String challengeId, String dayId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
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

      debugPrint('Challenge day completed: $challengeId/$dayId');
      return true;
    } catch (e) {
      debugPrint('Error completing challenge day: $e');
      return false;
    }
  }

  /// Get active challenges for the current user
  static Future<List<Challenge>> getActiveChallenges() async {
    try {
      final allChallenges = await getUserChallenges();
      final now = DateTime.now();

      return allChallenges.where((challenge) {
        return now.isAfter(challenge.startDate) &&
               now.isBefore(challenge.endDate.add(const Duration(days: 1)));
      }).toList();
    } catch (e) {
      debugPrint('Error getting active challenges: $e');
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