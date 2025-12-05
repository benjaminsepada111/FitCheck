import 'package:flutter/foundation.dart';
import '../models/challenge.dart';
import 'stats_service.dart';
import 'workout_service_v2.dart';
import 'milestone_service.dart';
import 'food_log_service.dart';
import 'user_data_service.dart';

/// Simple weekly summary with tracked stats, tips, and encouragement
class SimpleWeeklySummaryService {
  /// Get weekly summary data for a specific week
  static Future<WeeklySummaryData> getWeeklySummary({
    required Challenge challenge,
    required int weekNumber, // 1-based week number
  }) async {
    try {
      // Calculate week start date
      final weekStart = challenge.startDate.add(Duration(days: (weekNumber - 1) * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final now = DateTime.now();
      
      // Only count days that have actually occurred
      final actualWeekEnd = weekEnd.isAfter(now) ? now : weekEnd;
      
      // Get stats for the week
      final statsList = await StatsService.getStatsForDateRange(
        challenge.id,
        weekStart,
        actualWeekEnd,
      );
      
      // Calculate totals
      int totalCaloriesConsumed = 0;
      int totalCaloriesBurned = 0;
      int daysWithMeals = 0;
      int totalMeals = 0; // Total number of meals (FoodLog objects) logged
      int daysWithWorkouts = 0;
      int totalWorkouts = 0;
      int totalMilestones = 0;
      
      // Track which days had activity
      Set<String> activeDays = {};
      Set<String> daysWithFoodData = {};
      Set<String> daysWithWorkoutData = {};
      
      // First, get data from stats
      for (final stats in statsList) {
        totalCaloriesConsumed += stats.foodCalories;
        totalCaloriesBurned += stats.totalBurned;
        
        final dateKey = _formatDateKey(stats.date);
        
        if (stats.foodCalories > 0) {
          daysWithMeals++;
          daysWithFoodData.add(dateKey);
          activeDays.add(dateKey);
        }
        
        if (stats.totalBurned > 0) {
          daysWithWorkouts++;
          daysWithWorkoutData.add(dateKey);
        }
      }
      
      // Get user weight once for calorie calculations
      final userData = await UserDataService.loadUserData();
      final userWeight = userData?.weight?.toDouble() ?? 70.0;
      
      // Check food logs and workouts directly for all days in the week
      for (int i = 0; i <= actualWeekEnd.difference(weekStart).inDays; i++) {
        final date = weekStart.add(Duration(days: i));
        if (date.isAfter(now)) break;
        
        final dateKey = _formatDateKey(date);
        
        // Get food logs for this day to count meals
        final foodLogs = await FoodLogService.getFoodLogsForDate(
          date,
          challengeId: challenge.id,
        );
        
        // Count total meals (each FoodLog is one meal)
        totalMeals += foodLogs.length;
        
        // Check if we already counted calories from stats
        if (!daysWithFoodData.contains(dateKey)) {
          if (foodLogs.isNotEmpty) {
            double dayCalories = 0;
            for (final log in foodLogs) {
              dayCalories += log.totalCalories;
            }
            
            if (dayCalories > 0) {
              totalCaloriesConsumed += dayCalories.round();
              daysWithMeals++;
              daysWithFoodData.add(dateKey);
              activeDays.add(dateKey);
            }
          }
        }
        
        // Get workouts count and calories burned (only if not already counted in stats)
        if (!daysWithWorkoutData.contains(dateKey)) {
          final workouts = await WorkoutServiceV2.getWorkoutsForDate(
            challengeId: challenge.id,
            date: date,
          );
          totalWorkouts += workouts.length;
          
          if (workouts.isNotEmpty) {
            activeDays.add(dateKey);
            
            // Calculate calories burned from workouts
            for (var workout in workouts) {
              totalCaloriesBurned += workout.calculateCaloriesBurned(userWeight).round();
            }
          }
        } else {
          // Still count workouts even if calories already counted
          final workouts = await WorkoutServiceV2.getWorkoutsForDate(
            challengeId: challenge.id,
            date: date,
          );
          totalWorkouts += workouts.length;
        }
      }
      
      // Get milestones count
      final allMilestones = await MilestoneService.getAllMilestones(
        challengeId: challenge.id,
      );
      
      for (final milestone in allMilestones) {
        if (milestone.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            milestone.date.isBefore(weekEnd.add(const Duration(days: 1)))) {
          totalMilestones++;
          activeDays.add(_formatDateKey(milestone.date));
        }
      }
      
      // Calculate days missed
      final expectedDays = actualWeekEnd.difference(weekStart).inDays + 1;
      final daysMissed = expectedDays - activeDays.length;
      
      // Generate summary
      return WeeklySummaryData(
        weekNumber: weekNumber,
        totalCaloriesConsumed: totalCaloriesConsumed,
        totalCaloriesBurned: totalCaloriesBurned,
        daysWithMeals: daysWithMeals,
        totalMeals: totalMeals,
        daysWithWorkouts: daysWithWorkouts,
        totalWorkouts: totalWorkouts,
        totalMilestones: totalMilestones,
        daysMissed: daysMissed,
        expectedDays: expectedDays,
        weekStart: weekStart,
        weekEnd: actualWeekEnd,
        dailyCalorieGoal: challenge.dailyCalorieGoal,
      );
    } catch (e) {
      if (kDebugMode) print('Error getting weekly summary: $e');
      rethrow;
    }
  }
  
  static String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }
}

/// Weekly summary data model
class WeeklySummaryData {
  final int weekNumber;
  final int totalCaloriesConsumed;
  final int totalCaloriesBurned;
  final int daysWithMeals;
  final int totalMeals; // Total number of meals (FoodLog objects) logged
  final int daysWithWorkouts;
  final int totalWorkouts;
  final int totalMilestones;
  final int daysMissed;
  final int expectedDays;
  final DateTime weekStart;
  final DateTime weekEnd;
  final int dailyCalorieGoal;
  
  WeeklySummaryData({
    required this.weekNumber,
    required this.totalCaloriesConsumed,
    required this.totalCaloriesBurned,
    required this.daysWithMeals,
    required this.totalMeals,
    required this.daysWithWorkouts,
    required this.totalWorkouts,
    required this.totalMilestones,
    required this.daysMissed,
    required this.expectedDays,
    required this.weekStart,
    required this.weekEnd,
    required this.dailyCalorieGoal,
  });
  
  /// Get average daily calories consumed
  double get averageDailyCalories {
    if (daysWithMeals == 0) return 0;
    return totalCaloriesConsumed / daysWithMeals;
  }
  
  /// Get average daily calories burned
  double get averageDailyCaloriesBurned {
    if (expectedDays == 0) return 0;
    return totalCaloriesBurned / expectedDays;
  }
  
  /// Get net calories (consumed - burned)
  int get netCalories {
    return totalCaloriesConsumed - totalCaloriesBurned;
  }
  
  /// Get completion percentage
  double get completionPercentage {
    if (expectedDays == 0) return 0;
    return (expectedDays - daysMissed) / expectedDays;
  }
}

/// Simple tips and facts service
class SimpleTipsService {
  /// Get a simple tip based on weekly data
  static String getSimpleTip(WeeklySummaryData data) {
    // Tip about calories burned
    if (data.totalCaloriesBurned > 0) {
      if (data.totalCaloriesBurned < 500) {
        return "Did you know? A 30-minute brisk walk burns about 150 calories. Try adding a daily walk to boost your calorie burn!";
      } else if (data.totalCaloriesBurned < 1000) {
        return "Great job on your workouts! A 30-minute jog burns around 300 calories. Keep up the momentum!";
      } else {
        return "Amazing! You've burned over 1000 calories this week through exercise. That's equivalent to about 3 hours of cycling!";
      }
    }
    
    // Tip about missed days
    if (data.daysMissed > 0) {
      return "You missed ${data.daysMissed} day${data.daysMissed == 1 ? '' : 's'} this week. Remember, consistency is key! Try logging at least one meal or workout each day to build the habit.";
    }
    
    // Tip about meal logging
    if (data.daysWithMeals < data.expectedDays) {
      return "Try logging your meals right after eating - it only takes a minute and helps you stay on track with your goals!";
    }
    
    // General encouragement
    return "Every small step counts! Building healthy habits takes time, but you're making progress. Keep going!";
  }
  
  /// Get a motivational quote
  static String getMotivationalQuote() {
    final quotes = [
      "Success isn't always about greatness. It's about consistency. Consistent hard work leads to success.",
      "The only bad workout is the one that didn't happen.",
      "Small daily improvements over time lead to stunning results.",
      "You don't have to be great to start, but you have to start to be great.",
      "Progress, not perfection.",
      "The journey of a thousand miles begins with a single step.",
      "You are stronger than you think.",
      "Every expert was once a beginner.",
    ];
    
    return quotes[DateTime.now().millisecondsSinceEpoch % quotes.length];
  }
  
  /// Get congratulatory message based on week number
  static String getCongratulationsMessage(int weekNumber) {
    if (weekNumber == 1) {
      return "Congratulations on completing your first week! 🎉 This is a huge step toward completing your goal. Keep it up!";
    } else if (weekNumber == 2) {
      return "Congratulations on completing week 2! 🎉 You're building momentum. This is a step toward completing your goal - keep going!";
    } else if (weekNumber == 4) {
      return "Congratulations on completing a full month! 🎉 You're making amazing progress. Keep pushing forward!";
    } else {
      return "Congratulations on completing week $weekNumber! 🎉 You're doing great. Every week brings you closer to your goal - keep it up!";
    }
  }
  
  /// Get encouragement message based on performance
  static String getEncouragementMessage(WeeklySummaryData data) {
    if (data.completionPercentage >= 0.9) {
      return "You're doing amazing! You've been consistent almost every day. This dedication will help you reach your goals!";
    } else if (data.completionPercentage >= 0.7) {
      return "Great progress! You're staying active most days. Keep building this habit - you've got this!";
    } else if (data.completionPercentage >= 0.5) {
      return "You're making progress! Try to log something every day, even if it's just one meal. Small steps lead to big results!";
    } else {
      return "Every journey starts with a single step. Try logging at least one thing each day - meals, workouts, or milestones. You can do this!";
    }
  }
}

