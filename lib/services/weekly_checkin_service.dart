// services/weekly_checkin_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/weekly_checkin.dart';
import '../models/challenge.dart';
import 'user_data_service.dart';
import 'challenge_service.dart';

class WeeklyCheckInService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _usersCollection = 'users';
  static const String _challengesCollection = 'challenges';
  static const String _checkInsCollection = 'weekly_checkins';

  /// Save a weekly check-in
  static Future<bool> saveCheckIn(WeeklyCheckIn checkIn) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(checkIn.challengeId)
          .collection(_checkInsCollection)
          .doc(checkIn.id)
          .set(checkIn.toJson());

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get all check-ins for a challenge
  static Future<List<WeeklyCheckIn>> getCheckInsForChallenge(String challengeId) async {
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
          .collection(_checkInsCollection)
          .orderBy('weekNumber', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => WeeklyCheckIn.fromJson(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get the latest check-in for a challenge
  static Future<WeeklyCheckIn?> getLatestCheckIn(String challengeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return null;
      }

      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_challengesCollection)
          .doc(challengeId)
          .collection(_checkInsCollection)
          .orderBy('weekNumber', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return WeeklyCheckIn.fromJson(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if user needs to do a weekly check-in
  static Future<bool> needsCheckIn(Challenge challenge) async {
    try {
      final daysSinceStart = challenge.daysSinceStart;

      // Check every 7 days
      if (daysSinceStart < 7) return false;

      final weekNumber = (daysSinceStart / 7).floor();
      final latestCheckIn = await getLatestCheckIn(challenge.id);

      // No check-in yet, or current week hasn't been checked in
      if (latestCheckIn == null) {
        return daysSinceStart >= 7;
      }

      return latestCheckIn.weekNumber < weekNumber;
    } catch (e) {
      return false;
    }
  }

  /// Get the current week number for a challenge
  static int getCurrentWeekNumber(Challenge challenge) {
    final daysSinceStart = challenge.daysSinceStart;
    return (daysSinceStart / 7).floor();
  }

  /// Process check-in and update user data + challenge calorie goal
  static Future<bool> processCheckInAndUpdateGoals({
    required Challenge challenge,
    required int newWeight,
    String? notes,
    String? progressFeeling,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Get current calorie goal
      final currentCalorieGoal = challenge.dailyCalorieGoal;

      // Update user weight in profile
      await UserDataService.updateUserData(weight: newWeight);

      // Recalculate calorie goal based on new weight
      final newCalorieGoal = await UserDataService.getDailyCalorieGoal();

      // Create check-in record
      final checkIn = WeeklyCheckIn(
        id: _firestore.collection('temp').doc().id,
        challengeId: challenge.id,
        checkInDate: DateTime.now(),
        weekNumber: getCurrentWeekNumber(challenge),
        currentWeight: newWeight,
        notes: notes,
        progressFeeling: progressFeeling,
        previousCalorieGoal: currentCalorieGoal,
        newCalorieGoal: newCalorieGoal,
        createdAt: DateTime.now(),
      );

      // Save check-in
      await saveCheckIn(checkIn);

      // Update challenge calorie goal if it changed
      if (newCalorieGoal != currentCalorieGoal) {
        final updatedChallenge = challenge.copyWith(
          dailyCalorieGoal: newCalorieGoal,
        );
        await ChallengeService.updateChallenge(updatedChallenge);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get weight progress data for charts
  static Future<List<Map<String, dynamic>>> getWeightProgress(String challengeId) async {
    final checkIns = await getCheckInsForChallenge(challengeId);
    return checkIns.map((checkIn) => {
      'week': checkIn.weekNumber,
      'weight': checkIn.currentWeight,
      'date': checkIn.checkInDate,
    }).toList();
  }
}
