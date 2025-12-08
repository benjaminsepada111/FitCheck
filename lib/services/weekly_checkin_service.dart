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
import 'login_tracker_service.dart';

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

  /// Process check-in with simplified trend-based calorie adjustment
  /// Uses automatic trend detection and ±150 kcal adjustments
  static Future<bool> processCheckInAndUpdateGoals({
    required Challenge challenge,
    required double newWeight, // Accept double for precision
    String? notes,
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
      final previousWeight = latestCheckIn?.currentWeight ?? userData.weight ?? newWeight;

      // Determine weight trend automatically
      final weightTrend = CalorieCalculator.determineWeightTrend(
        currentWeight: newWeight,
        previousWeight: previousWeight,
      );

      // Calculate weekly calories consumed and burned (for tracking purposes)
      int weeklyCaloriesConsumed = 0;
      int weeklyCaloriesBurned = 0;
      Set<String> activeDays = {}; // Track days with any activity (food or workouts)

      // Get stats for the week
      final statsList = await StatsService.getStatsForDateRange(
        challenge.id,
        weekStart,
        actualWeekEnd,
      );

      for (final stats in statsList) {
        if (stats.foodCalories > 0) {
          activeDays.add(stats.dateId); // Mark day as active
          weeklyCaloriesConsumed += stats.foodCalories;
        }
        if (stats.totalBurned > 0) {
          activeDays.add(stats.dateId); // Mark day as active if workout was logged
        }
        weeklyCaloriesBurned += stats.totalBurned;
      }

      // Also check food logs directly for days that might not have stats yet or have incomplete stats
      // This ensures we capture all calories even if stats haven't been updated yet
      // IMPORTANT: We check food logs ONLY if stats don't exist or show 0 calories to avoid double-counting
      for (int i = 0; i <= actualWeekEnd.difference(weekStart).inDays; i++) {
        final date = weekStart.add(Duration(days: i));
        if (date.isAfter(now)) break;

        final dateKey = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
        
        // Check if we already counted calories from stats for this day
        // Only skip food log check if stats exist AND have calories > 0 (to avoid double-counting)
        final statsForDay = statsList.where((s) => s.dateId == dateKey).toList();
        final hasStatsWithCalories = statsForDay.isNotEmpty && 
                                     statsForDay.any((s) => s.foodCalories > 0);
        
        // Only check food logs if stats don't exist or show 0 calories
        // This prevents double-counting while ensuring we capture all calories
        if (!hasStatsWithCalories) {
          final foodLogs = await FoodLogService.getFoodLogsForDate(date, challengeId: challenge.id);
          if (foodLogs.isNotEmpty) {
            double dayCalories = 0;
            for (final log in foodLogs) {
              dayCalories += log.totalCalories;
            }
            if (dayCalories > 0) {
              activeDays.add(dateKey); // Mark day as active
              weeklyCaloriesConsumed += dayCalories.round();
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
      
      // DEBUG: Log activity tracking
      if (kDebugMode) {
        print('=== WEEKLY CHECK-IN VALIDATION DEBUG ===');
        print('Total days in week: $totalDaysInWeek');
        print('Days with activity: $daysWithActivity');
        print('Inactive days: $inactiveDays');
        print('Weekly calories consumed: $weeklyCaloriesConsumed');
        print('Weekly calories burned: $weeklyCaloriesBurned');
        print('Active days set: $activeDays');
      }
      
      // Check for activity: if no weight or food log for >=3 days, skip adjustment
      // Changed from >3 to >=3 to be more strict (3 or more days without logs)
      final hasInsufficientActivity = inactiveDays >= 3;

      // Check if user hasn't logged in (opened app) for > 3 days
      // Requirement: "hasn't logged in for > 3 days" means last login was MORE than 3 days ago
      // So we check if they logged in within last 3 days (today, yesterday, 2 days ago)
      // If false, it means last login was 3+ days ago, so skip adjustment
      bool hasLoggedInWithinLast3Days = false;
      try {
        hasLoggedInWithinLast3Days = await LoginTrackerService.hasLoggedInWithinLastNDays(
          referenceDate: now,
          days: 3,
        );
      } catch (e) {
        // If login check fails, assume no recent login (fail-safe: skip adjustment)
        if (kDebugMode) {
          print('⚠️ ERROR checking login status: $e - assuming no recent login');
        }
        hasLoggedInWithinLast3Days = false;
      }
      
      // Skip adjustment if user hasn't logged in within the last 3 days
      final hasNotLoggedInForMoreThan3Days = !hasLoggedInWithinLast3Days;

      // Calculate net calorie completeness threshold
      // Expected weekly intake based on daily calorie goal
      final expectedWeeklyIntake = currentCalorieGoal * 7;
      
      // Calculate completeness percentage (75% threshold)
      // Check if logged calories consumed >= 75% of expected weekly intake
      // If weeklyCaloriesConsumed is 0, completeness is 0% which is < 75%
      final calorieCompleteness = expectedWeeklyIntake > 0 
        ? (weeklyCaloriesConsumed / expectedWeeklyIntake) * 100 
        : 0.0;
      
      // Also check if no calories were consumed at all (0)
      // If user hasn't logged anything, weeklyCaloriesConsumed will be 0
      // This is an additional explicit check: if no calories were consumed at all, don't adjust
      final hasInsufficientNetCalories = calorieCompleteness < 75.0 || weeklyCaloriesConsumed == 0;

      // Simplified validation: basic checks for reliable weight data
      // Also check that weight is positive (not negative or zero)
      final hasReliableWeightData = newWeight > 0 && previousWeight > 0;
      
      int finalCalorieGoal = currentCalorieGoal;
      int finalAdjustment = 0;
      String finalInterpretation = 'unchanged';
      String finalReason = 'No adjustment needed';

      // CRITICAL: Combined validation logic - ALL checks must pass for adjustment to proceed
      // Priority order: invalid weight > no calories logged > insufficient activity > incomplete logging
      // If ANY check fails, skip adjustment completely
      
      bool shouldSkipAdjustment = false; // Initialize to false - will be set to true if any validation fails
      
      if (kDebugMode) {
        print('=== VALIDATION CHECKS ===');
        print('hasReliableWeightData: $hasReliableWeightData (newWeight: $newWeight, previousWeight: $previousWeight)');
        print('weeklyCaloriesConsumed: $weeklyCaloriesConsumed');
        print('hasLoggedInWithinLast3Days: $hasLoggedInWithinLast3Days');
        print('hasNotLoggedInForMoreThan3Days: $hasNotLoggedInForMoreThan3Days');
        print('hasInsufficientActivity: $hasInsufficientActivity (inactiveDays: $inactiveDays)');
        print('hasInsufficientNetCalories: $hasInsufficientNetCalories (completeness: ${calorieCompleteness.toStringAsFixed(1)}%)');
        print('Week period: ${weekStart.toString().split(' ')[0]} to ${actualWeekEnd.toString().split(' ')[0]}');
      }
      
      // Check 1: Invalid weight (most critical - always skip if weight is invalid)
      if (!hasReliableWeightData) {
        shouldSkipAdjustment = true;
        finalReason = 'Calorie goal kept the same due to invalid weight data (current: $newWeight kg, previous: $previousWeight kg)';
        finalInterpretation = 'skipped_invalid_weight';
        if (kDebugMode) {
          print('❌ SKIPPING: Invalid weight data');
        }
      }
      // Check 2: Insufficient calories logged (CRITICAL - must check BEFORE other checks)
      // This MUST catch cases where user logged very few calories (<75% of expected)
      // Moving this earlier to ensure it's always checked
      else if (weeklyCaloriesConsumed == 0 || hasInsufficientNetCalories) {
        shouldSkipAdjustment = true;
        final minRequiredCalories = (expectedWeeklyIntake * 0.75).round();
        if (weeklyCaloriesConsumed == 0) {
          finalReason = 'Calorie goal kept the same due to no calories logged this week (need to log meals to adjust goals)';
          finalInterpretation = 'skipped_no_calories_logged';
        } else {
          finalReason = 'Calorie goal kept the same due to insufficient calorie logging (logged $weeklyCaloriesConsumed calories, need at least $minRequiredCalories calories - only ${calorieCompleteness.toStringAsFixed(1)}% of expected ${expectedWeeklyIntake.round()} calories)';
          finalInterpretation = 'skipped_insufficient_calories';
        }
        if (kDebugMode) {
          print('❌ SKIPPING: Insufficient calories logged');
          print('   Consumed: $weeklyCaloriesConsumed');
          print('   Required: $minRequiredCalories (75% of $expectedWeeklyIntake)');
          print('   Completeness: ${calorieCompleteness.toStringAsFixed(1)}%');
        }
      }
      // Check 3: User hasn't logged in (opened app) for > 3 days
      // This check ensures we don't adjust if user hasn't been active in the app recently
      else if (hasNotLoggedInForMoreThan3Days) {
        shouldSkipAdjustment = true;
        finalReason = 'Calorie goal kept the same due to no login activity (need to log in within the last 3 days to adjust goals)';
        finalInterpretation = 'skipped_no_login';
        if (kDebugMode) {
          print('❌ SKIPPING: User hasn\'t logged in within the last 3 days (hasLoggedInWithinLast3Days: $hasLoggedInWithinLast3Days)');
        }
      }
      // Check 4: Insufficient activity (3+ days without logs)
      else if (hasInsufficientActivity) {
        shouldSkipAdjustment = true;
        finalReason = 'Calorie goal kept the same due to insufficient activity (${inactiveDays} days without logs, need at least 3 days with activity)';
        finalInterpretation = 'skipped_insufficient_activity';
        if (kDebugMode) {
          print('❌ SKIPPING: Insufficient activity (${inactiveDays} inactive days)');
        }
      }
      
      if (kDebugMode) {
        print('=== FINAL VALIDATION RESULT ===');
        print('shouldSkipAdjustment: $shouldSkipAdjustment');
        print('finalReason: $finalReason');
        print('weeklyCaloriesConsumed: $weeklyCaloriesConsumed');
        print('expectedWeeklyIntake: $expectedWeeklyIntake');
        print('calorieCompleteness: ${calorieCompleteness.toStringAsFixed(1)}%');
        print('hasInsufficientNetCalories: $hasInsufficientNetCalories');
        print('minRequiredCalories: ${(expectedWeeklyIntake * 0.75).round()}');
      }
      
      // CRITICAL SAFETY CHECK: Double-verify calories before allowing any adjustment
      // This prevents any edge cases where validation might be bypassed
      // MUST happen BEFORE calculating the adjustment to prevent wasted computation
      if (!shouldSkipAdjustment && weeklyCaloriesConsumed > 0) {
        final minRequiredCalories = (expectedWeeklyIntake * 0.75).round();
        if (weeklyCaloriesConsumed < minRequiredCalories) {
          shouldSkipAdjustment = true;
          finalReason = 'Calorie goal kept the same due to insufficient calorie logging (logged $weeklyCaloriesConsumed calories, need at least $minRequiredCalories calories - ${calorieCompleteness.toStringAsFixed(1)}% complete)';
          finalInterpretation = 'skipped_insufficient_calories_safety';
          if (kDebugMode) {
            print('🚨 SAFETY CHECK TRIGGERED: Insufficient calories! Skipping adjustment.');
            print('   Consumed: $weeklyCaloriesConsumed, Required: $minRequiredCalories, Completeness: ${calorieCompleteness.toStringAsFixed(1)}%');
          }
        }
      }
      
      // ONLY calculate adjustment if ALL validation checks passed
      // This prevents calculating adjustments that will be rejected
      if (!shouldSkipAdjustment && challenge.goal != null) {
        // Apply simplified adjustment based on goal + trend
        final simplifiedResult = CalorieCalculator.calculateSimplifiedAdjustment(
          goal: challenge.goal!,
          trend: weightTrend,
          currentCalorieGoal: currentCalorieGoal,
          currentWeight: newWeight,
          previousWeight: previousWeight,
          userData: userData,
        );

        finalCalorieGoal = simplifiedResult['newCalorieGoal'] as int;
        finalAdjustment = simplifiedResult['adjustment'] as int;
        finalInterpretation = simplifiedResult['interpretation'] as String;
        finalReason = simplifiedResult['reason'] as String;

        // TRIPLE CHECK: Verify calories one more time before updating
        // This is the final gate before any database update
        final minRequiredCalories = (expectedWeeklyIntake * 0.75).round();
        if (weeklyCaloriesConsumed < minRequiredCalories) {
          shouldSkipAdjustment = true;
          finalCalorieGoal = currentCalorieGoal;
          finalAdjustment = 0;
          finalReason = 'Calorie goal kept the same due to insufficient calorie logging (logged $weeklyCaloriesConsumed calories, need at least $minRequiredCalories calories)';
          finalInterpretation = 'skipped_insufficient_calories_final';
          if (kDebugMode) {
            print('🚨 FINAL GATE CHECK: Blocking adjustment due to insufficient calories!');
            print('   Consumed: $weeklyCaloriesConsumed, Required: $minRequiredCalories');
          }
        }

        // SAFETY CHECK: Only update challenge if we're not skipping adjustment
        // This is a double-check to prevent any accidental updates
        // CRITICAL: Never update if shouldSkipAdjustment is true, regardless of calculated values
        if (!shouldSkipAdjustment && finalCalorieGoal != currentCalorieGoal) {
          if (kDebugMode) {
            print('✅ UPDATING CHALLENGE: Old goal=$currentCalorieGoal, New goal=$finalCalorieGoal');
          }
          final updatedChallenge = challenge.copyWith(
            dailyCalorieGoal: finalCalorieGoal,
          );
          await ChallengeService.updateChallenge(updatedChallenge);
        } else {
          if (kDebugMode) {
            print('⚠️ NOT UPDATING CHALLENGE: shouldSkipAdjustment=$shouldSkipAdjustment, goalChanged=${finalCalorieGoal != currentCalorieGoal}');
          }
        }
      } else {
        // If we're skipping adjustment, ensure values stay unchanged
        finalCalorieGoal = currentCalorieGoal;
        finalAdjustment = 0;
      }
      
      // FINAL SAFETY CHECK: If we skipped adjustment, ensure finalCalorieGoal stays unchanged
      // This is the absolute last check before saving the check-in record
      if (shouldSkipAdjustment) {
        finalCalorieGoal = currentCalorieGoal;
        finalAdjustment = 0;
        if (kDebugMode) {
          print('FINAL CHECK: Skipping adjustment - keeping calorie goal at $currentCalorieGoal');
          print('Reason: $finalReason');
        }
      } else {
        if (kDebugMode) {
          print('ADJUSTMENT APPLIED: New calorie goal = $finalCalorieGoal (adjustment: $finalAdjustment)');
        }
      }

      // Update user weight in profile (store with decimal precision)
      await UserDataService.updateUserData(weight: newWeight);

      final weightChange = (newWeight - previousWeight).toDouble();

      // Create check-in record with trend
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
        currentWeight: newWeight,
        previousWeight: previousWeight,
        weightChange: weightChange,
        weightTrend: weightTrend,
        notes: notes,
        progressFeeling: null, // Removed from simplified flow
        activityLevelChange: null, // Removed from simplified flow
        previousCalorieGoal: currentCalorieGoal,
        newCalorieGoal: finalCalorieGoal,
        calorieAdjustment: finalAdjustment,
        progressInterpretation: finalInterpretation,
        adaptiveReason: finalReason,
        goalAdjusted: !shouldSkipAdjustment && finalAdjustment != 0,
        adjustmentNotice: null, // Simplified - no complex notices
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
