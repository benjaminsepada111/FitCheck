import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/food_log_service.dart';
import '../services/workout_service.dart';
import '../services/challenge_service.dart';
import '../services/login_tracker_service.dart';

class StatisticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get total calories consumed across all challenges
  static Future<int> getTotalCalories() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final challenges = await ChallengeService.getUserChallenges();
      if (challenges.isEmpty) return 0;

      int totalCalories = 0;

      for (final challenge in challenges) {
        // Get all food logs for this challenge
        final startDate = challenge.startDate;
        final endDate = challenge.endDate.isAfter(DateTime.now())
            ? DateTime.now()
            : challenge.endDate;

        // Calculate calories for each day in the challenge
        DateTime currentDate = startDate;
        while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
          final dailyCalories = await FoodLogService.getDailyCalories(
            currentDate,
            challengeId: challenge.id,
          );
          totalCalories += dailyCalories.round();
          currentDate = currentDate.add(const Duration(days: 1));
        }
      }

      debugPrint('Total calories calculated: $totalCalories');
      return totalCalories;
    } catch (e) {
      debugPrint('Error calculating total calories: $e');
      return 0;
    }
  }

  /// Get total number of login days (days user opened app, even without activity)
  static Future<int> getLoginDays() async {
    try {
      // Use LoginTrackerService which tracks daily app opens
      return await LoginTrackerService.getTotalLoginDays();
    } catch (e) {
      debugPrint('Error getting login days: $e');
      return 0;
    }
  }

  /// Get total number of active days (days with food or workout logs)
  static Future<int> getActiveDays() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final challenges = await ChallengeService.getUserChallenges();
      if (challenges.isEmpty) return 0;

      Set<String> uniqueDays = {};

      for (final challenge in challenges) {
        // Get all food logs for this challenge
        final foodLogsSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('challenges')
            .doc(challenge.id)
            .collection('foodlogs')
            .get();

        for (final doc in foodLogsSnapshot.docs) {
          final data = doc.data();
          if (data['date'] != null) {
            final date = DateTime.parse(data['date']);
            final dateKey = '${date.year}-${date.month}-${date.day}';
            uniqueDays.add(dateKey);
          }
        }

        // Get all workout dates for this challenge
        final workoutsSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('challenges')
            .doc(challenge.id)
            .collection('workouts')
            .get();

        for (final doc in workoutsSnapshot.docs) {
          final data = doc.data();
          if (data['date'] != null) {
            final date = DateTime.parse(data['date']);
            final dateKey = '${date.year}-${date.month}-${date.day}';
            uniqueDays.add(dateKey);
          }
        }
      }

      debugPrint('Active days calculated: ${uniqueDays.length}');
      return uniqueDays.length;
    } catch (e) {
      debugPrint('Error calculating active days: $e');
      return 0;
    }
  }

  /// Get total number of workouts logged
  static Future<int> getWorkoutsLogged() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final challenges = await ChallengeService.getUserChallenges();
      if (challenges.isEmpty) return 0;

      int totalWorkouts = 0;

      for (final challenge in challenges) {
        final workouts = await WorkoutService.getChallengeWorkouts(challenge.id);
        totalWorkouts += workouts.length;
      }

      debugPrint('Total workouts logged: $totalWorkouts');
      return totalWorkouts;
    } catch (e) {
      debugPrint('Error calculating workouts logged: $e');
      return 0;
    }
  }

  /// Get total number of food entries logged (not meal types)
  static Future<int> getMealsLogged() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final challenges = await ChallengeService.getUserChallenges();
      if (challenges.isEmpty) return 0;

      int totalFoodEntries = 0;

      for (final challenge in challenges) {
        // Get all food logs for this challenge
        final foodLogsSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('challenges')
            .doc(challenge.id)
            .collection('foodlogs')
            .get();

        // Count all food entries across all meal logs
        for (final doc in foodLogsSnapshot.docs) {
          final data = doc.data();
          if (data['entries'] != null && data['entries'] is List) {
            totalFoodEntries += (data['entries'] as List).length;
          }
        }
      }

      debugPrint('Total food entries logged: $totalFoodEntries');
      return totalFoodEntries;
    } catch (e) {
      debugPrint('Error calculating food entries logged: $e');
      return 0;
    }
  }

  /// Get all statistics at once
  static Future<Map<String, int>> getAllStatistics() async {
    try {
      final results = await Future.wait([
        getTotalCalories(),
        getLoginDays(),
        getWorkoutsLogged(),
        getMealsLogged(),
      ]);

      return {
        'totalCalories': results[0],
        'loginDays': results[1],
        'workoutsLogged': results[2],
        'mealsLogged': results[3],
      };
    } catch (e) {
      debugPrint('Error getting all statistics: $e');
      return {
        'totalCalories': 0,
        'loginDays': 0,
        'workoutsLogged': 0,
        'mealsLogged': 0,
      };
    }
  }
}
