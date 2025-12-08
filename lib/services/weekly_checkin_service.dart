// services/weekly_checkin_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/weekly_checkin.dart';
import '../models/challenge.dart';
import 'user_data_service.dart';
import 'challenge_service.dart';
import 'calorie_calculator.dart';
import 'food_log_service.dart';
import 'workout_service_v2.dart';
import 'stats_service.dart';

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

      // Check-in should appear on the first day of each new week (day 8, 15, 22, etc.)
      // Week 1 = days 0-6, Week 2 = days 7-13, so check-in appears on day 8 (first day of week 2)
      // Not on day 7 (last day of week 1), but on day 8 (first day of week 2)
      if (daysSinceStart < 8) return false;

      final weekNumber = getCurrentWeekNumber(challenge);
      final latestCheckIn = await getLatestCheckIn(challenge.id);

      // No check-in yet - check if we're on day 8 or later (first day of week 2)
      if (latestCheckIn == null) {
        return daysSinceStart >= 8;
      }

      // Check if current week hasn't been checked in yet
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

  /// Process check-in with adaptive calorie adjustment and validation
  static Future<bool> processCheckInAndUpdateGoals({
    required Challenge challenge,
    required double newWeight, // Accept double for precision
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
      final weekNumber = getCurrentWeekNumber(challenge);

      // Calculate week start and end dates
      final weekStart = challenge.startDate.add(Duration(days: (weekNumber - 1) * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final now = DateTime.now();
      final actualWeekEnd = weekEnd.isAfter(now) ? now : weekEnd;

      // Get previous check-in to compare weight (convert to double for calculation)
      final latestCheckIn = await getLatestCheckIn(challenge.id);
      final previousWeight = (latestCheckIn?.currentWeight ?? userData.weight ?? newWeight.round()).toDouble();

      // Calculate weekly calories consumed and burned
      int weeklyCaloriesConsumed = 0;
      int weeklyCaloriesBurned = 0;
      int daysWithFoodIntake = 0;
      int daysWithinTarget = 0;
      Set<String> activeDays = {}; // Track days with any activity (food or workouts)

      // Get stats for the week
      final statsList = await StatsService.getStatsForDateRange(
        challenge.id,
        weekStart,
        actualWeekEnd,
      );

      for (final stats in statsList) {
        if (stats.foodCalories > 0) {
          daysWithFoodIntake++;
          activeDays.add(stats.dateId); // Mark day as active
          weeklyCaloriesConsumed += stats.foodCalories;
          
          // Check if calories are within ±20% of target
          final lowerBound = currentCalorieGoal * 0.8;
          final upperBound = currentCalorieGoal * 1.2;
          if (stats.foodCalories >= lowerBound && stats.foodCalories <= upperBound) {
            daysWithinTarget++;
          }
        }
        if (stats.totalBurned > 0) {
          activeDays.add(stats.dateId); // Mark day as active if workout was logged
        }
        weeklyCaloriesBurned += stats.totalBurned;
      }

      // Also check food logs directly for days that might not have stats yet
      for (int i = 0; i <= actualWeekEnd.difference(weekStart).inDays; i++) {
        final date = weekStart.add(Duration(days: i));
        if (date.isAfter(now)) break;

        final dateKey = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
        
        // Check if we already counted this day in stats
        final alreadyCounted = statsList.any((s) => s.dateId == dateKey && s.foodCalories > 0);
        
        if (!alreadyCounted) {
          final foodLogs = await FoodLogService.getFoodLogsForDate(date, challengeId: challenge.id);
          if (foodLogs.isNotEmpty) {
            double dayCalories = 0;
            for (final log in foodLogs) {
              dayCalories += log.totalCalories;
            }
            if (dayCalories > 0) {
              daysWithFoodIntake++;
              activeDays.add(dateKey); // Mark day as active
              weeklyCaloriesConsumed += dayCalories.round();
              
              // Check if calories are within ±20% of target
              final lowerBound = currentCalorieGoal * 0.8;
              final upperBound = currentCalorieGoal * 1.2;
              if (dayCalories >= lowerBound && dayCalories <= upperBound) {
                daysWithinTarget++;
              }
            }
          }
        }

        // Get workouts for calories burned
        final workouts = await WorkoutServiceV2.getWorkoutsForDate(
          challengeId: challenge.id,
          date: date,
        );
        if (workouts.isNotEmpty) {
          activeDays.add(dateKey); // Mark day as active if workout was logged
        }
        final userWeight = userData.weight?.toDouble() ?? 70.0;
        for (var workout in workouts) {
          weeklyCaloriesBurned += workout.calculateCaloriesBurned(userWeight).round();
        }
      }

      // Calculate total days in week and inactive days
      final totalDaysInWeek = actualWeekEnd.difference(weekStart).inDays + 1;
      final daysWithActivity = activeDays.length;
      final inactiveDays = totalDaysInWeek - daysWithActivity;

      // Validate conditions for adjustment
      final hasEnoughDays = daysWithFoodIntake >= 5;
      final hasReliableWeightData = newWeight > 0 && previousWeight > 0;
      final hasReasonableCalories = daysWithinTarget >= 3; // At least 3 days within ±20%
      // If user wasn't active for more than 2 days, don't adjust regardless of weight change
      final hasConsistentActivity = inactiveDays <= 2; // Allow max 2 inactive days

      // Determine if adjustment should be made
      // Note: If user isn't active for a few days, calorie adjustment shouldn't happen
      // regardless of weight increase or decrease
      bool shouldAdjust = hasEnoughDays && hasReliableWeightData && hasReasonableCalories && hasConsistentActivity;
      String? adjustmentNotice;
      int finalCalorieGoal = currentCalorieGoal;
      int finalAdjustment = 0;
      String finalInterpretation = 'unchanged';
      String finalReason = 'No adjustment needed';

      if (shouldAdjust) {
        // Determine updated activity level based on user input
        String? updatedActivityLevel = challenge.activityLevel;
        if (activityLevelChange != null && challenge.activityLevel != null) {
          if (activityLevelChange == 'increased') {
            updatedActivityLevel = _increaseActivityLevel(challenge.activityLevel!);
          } else if (activityLevelChange == 'decreased') {
            updatedActivityLevel = _decreaseActivityLevel(challenge.activityLevel!);
          }
        }

        // Calculate adaptive adjustment using challenge-specific activity level and goal
        final adaptiveResult = CalorieCalculator.calculateAdaptiveAdjustment(
          userData: userData,
          currentWeight: newWeight.toDouble(),
          previousWeight: previousWeight.toDouble(),
          currentCalorieGoal: currentCalorieGoal,
          activityLevel: updatedActivityLevel,
          goal: challenge.goal,
        );

        finalCalorieGoal = adaptiveResult['newCalorieGoal'] as int;
        finalAdjustment = adaptiveResult['adjustment'] as int;
        finalInterpretation = adaptiveResult['interpretation'] as String;
        finalReason = adaptiveResult['reason'] as String;

        // Update challenge with new calorie goal and activity level if changed
        if (finalCalorieGoal != currentCalorieGoal || updatedActivityLevel != challenge.activityLevel) {
          final updatedChallenge = challenge.copyWith(
            dailyCalorieGoal: finalCalorieGoal,
            activityLevel: updatedActivityLevel,
          );
          await ChallengeService.updateChallenge(updatedChallenge);
        }
      } else {
        // Build adjustment notice explaining why adjustment wasn't made
        final reasons = <String>[];
        if (!hasEnoughDays) {
          reasons.add('insufficient food tracking (only $daysWithFoodIntake days logged, need at least 5)');
        }
        if (!hasReasonableCalories) {
          reasons.add('calories not consistently within target range (only $daysWithinTarget days within ±20% of goal)');
        }
        if (!hasReliableWeightData) {
          reasons.add('unreliable weight data');
        }
        if (!hasConsistentActivity) {
          reasons.add('too many inactive days ($inactiveDays days without food or workout logs, maximum 2 allowed)');
        }
        adjustmentNotice = 'Your calorie goal was not adjusted this week due to incomplete tracking: ${reasons.join(', ')}. Please log at least 5 days of food intake with calories reasonably close to your target (±20%) and stay active throughout the week to enable automatic adjustments.';
      }

      // Update user weight in profile (store with decimal precision)
      await UserDataService.updateUserData(weight: newWeight);

      final weightChange = (newWeight - previousWeight).toDouble();

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
        weekNumber: weekNumber,
        currentWeight: newWeight.round(),
        previousWeight: previousWeight.round(),
        weightChange: weightChange,
        notes: notes,
        progressFeeling: progressFeeling,
        activityLevelChange: activityLevelChange,
        previousCalorieGoal: currentCalorieGoal,
        newCalorieGoal: shouldAdjust ? finalCalorieGoal : currentCalorieGoal,
        calorieAdjustment: shouldAdjust ? finalAdjustment : 0,
        progressInterpretation: finalInterpretation,
        adaptiveReason: finalReason,
        goalAdjusted: shouldAdjust,
        adjustmentNotice: adjustmentNotice,
        weeklyCaloriesConsumed: weeklyCaloriesConsumed,
        weeklyCaloriesBurned: weeklyCaloriesBurned,
        createdAt: DateTime.now(),
      );

      // Save check-in to history
      await saveCheckIn(checkIn);

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
