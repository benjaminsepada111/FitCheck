// services/weekly_checkin_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/weekly_checkin.dart';
import '../models/challenge.dart';
import 'user_data_service.dart';
import 'challenge_service.dart';
import 'calorie_calculator.dart';

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

  /// Process check-in with adaptive calorie adjustment
  static Future<bool> processCheckInAndUpdateGoals({
    required Challenge challenge,
    required int newWeight,
    String? notes,
    String? progressFeeling,
    String? activityLevelChange,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Get current user data and calorie goal
      final userData = await UserDataService.loadUserData();
      if (userData == null) return false;

      final currentCalorieGoal = challenge.dailyCalorieGoal;

      // Get previous check-in to compare weight
      final latestCheckIn = await getLatestCheckIn(challenge.id);
      final previousWeight = latestCheckIn?.currentWeight ?? userData.weight ?? newWeight;

      // Determine updated activity level based on user input
      String? updatedActivityLevel = challenge.activityLevel;
      if (activityLevelChange != null && challenge.activityLevel != null) {
        if (activityLevelChange == 'increased') {
          // Move up one activity level
          updatedActivityLevel = _increaseActivityLevel(challenge.activityLevel!);
        } else if (activityLevelChange == 'decreased') {
          // Move down one activity level
          updatedActivityLevel = _decreaseActivityLevel(challenge.activityLevel!);
        }
        // If 'no_change', keep the same activity level
      }

      // Calculate adaptive adjustment using challenge-specific activity level and goal
      final adaptiveResult = CalorieCalculator.calculateAdaptiveAdjustment(
        userData: userData,
        currentWeight: newWeight,
        previousWeight: previousWeight,
        currentCalorieGoal: currentCalorieGoal,
        activityLevel: updatedActivityLevel, // Use updated activity level
        goal: challenge.goal, // Use challenge-specific goal
      );

      final newCalorieGoal = adaptiveResult['newCalorieGoal'] as int;
      final adjustment = adaptiveResult['adjustment'] as int;
      final interpretation = adaptiveResult['interpretation'] as String;
      final reason = adaptiveResult['reason'] as String;
      final weightChange = adaptiveResult['weightChange'] as double;

      // Update user weight in profile
      await UserDataService.updateUserData(weight: newWeight);

      // Create detailed check-in record
      final checkIn = WeeklyCheckIn(
        id: _firestore
            .collection(_usersCollection)
            .doc(user.uid)
            .collection(_challengesCollection)
            .doc(challenge.id)
            .collection(_checkInsCollection)
            .doc()
            .id,
        challengeId: challenge.id,
        checkInDate: DateTime.now(),
        weekNumber: getCurrentWeekNumber(challenge),
        currentWeight: newWeight,
        previousWeight: previousWeight,
        weightChange: weightChange,
        notes: notes,
        progressFeeling: progressFeeling,
        activityLevelChange: activityLevelChange,
        previousCalorieGoal: currentCalorieGoal,
        newCalorieGoal: newCalorieGoal,
        calorieAdjustment: adjustment,
        progressInterpretation: interpretation,
        adaptiveReason: reason,
        createdAt: DateTime.now(),
      );

      // Save check-in to history
      await saveCheckIn(checkIn);

      // Update challenge with new calorie goal and activity level if changed
      if (newCalorieGoal != currentCalorieGoal || updatedActivityLevel != challenge.activityLevel) {
        final updatedChallenge = challenge.copyWith(
          dailyCalorieGoal: newCalorieGoal,
          activityLevel: updatedActivityLevel,
        );
        await ChallengeService.updateChallenge(updatedChallenge);
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error in processCheckInAndUpdateGoals: $e');
      }
      return false;
    }
  }

  /// Helper method to increase activity level by one step
  static String _increaseActivityLevel(String currentLevel) {
    switch (currentLevel.toLowerCase()) {
      case 'lightly_active':
      case 'lightly active':
        return 'active';
      case 'active':
        return 'very_active';
      case 'very_active':
      case 'very active':
        return 'extra_active';
      case 'extra_active':
      case 'extra active':
        return 'extra_active'; // Already at max
      default:
        return currentLevel; // Unknown level, keep as is
    }
  }

  /// Helper method to decrease activity level by one step
  static String _decreaseActivityLevel(String currentLevel) {
    switch (currentLevel.toLowerCase()) {
      case 'extra_active':
      case 'extra active':
        return 'very_active';
      case 'very_active':
      case 'very active':
        return 'active';
      case 'active':
        return 'lightly_active';
      case 'lightly_active':
      case 'lightly active':
        return 'lightly_active'; // Already at min
      default:
        return currentLevel; // Unknown level, keep as is
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
