// services/achievement_time_service.dart
import 'package:capstone_project/services/user_time_tracker.dart';
import 'package:capstone_project/services/statistics_service.dart';
import 'package:capstone_project/services/challenge_service.dart';
import 'package:flutter/foundation.dart';

/// Service to check challenge-based achievements
///
/// This service checks achievements based on:
/// - Creating and completing challenges
/// - Logging meals and workouts
/// - Consistency and engagement
class AchievementTimeService {
  /// Check all challenge-based achievements at once
  ///
  /// Returns a map with achievement IDs as keys and unlock status as values
  static Future<Map<String, AchievementStatus>> checkAllAchievements() async {
    try {
      // Get data in parallel
      final results = await Future.wait([
        ChallengeService.getUserChallenges(),
        StatisticsService.getAllStatistics(),
        StatisticsService.getActiveDays(),
        StatisticsService.getLoginDays(),
      ]);

      final challenges = results[0] as List;
      final stats = results[1] as Map<String, int>;
      final activeDays = results[2] as int;
      final loginDays = results[3] as int;

      final achievements = <String, AchievementStatus>{};

      final totalChallenges = challenges.length;
      final workouts = stats['workoutsLogged'] ?? 0;
      final meals = stats['mealsLogged'] ?? 0;

      // CHALLENGE CREATION ACHIEVEMENTS

      // Challenger - Create your first challenge
      achievements['challenger'] = AchievementStatus(
        unlocked: totalChallenges >= 1,
        progress: totalChallenges >= 1 ? 1.0 : 0.0,
        description: 'Create your first challenge',
      );

      // Goal Setter - Create 3 challenges
      achievements['goal_setter'] = AchievementStatus(
        unlocked: totalChallenges >= 3,
        progress: (totalChallenges / 3).clamp(0.0, 1.0),
        description: 'Create 3 challenges ($totalChallenges/3)',
      );

      // Ambitious - Create 5 challenges
      achievements['ambitious'] = AchievementStatus(
        unlocked: totalChallenges >= 5,
        progress: (totalChallenges / 5).clamp(0.0, 1.0),
        description: 'Create 5 challenges ($totalChallenges/5)',
      );

      // ACTIVITY & LOGGING ACHIEVEMENTS

      // First Meal - Log your first meal
      achievements['first_meal'] = AchievementStatus(
        unlocked: meals >= 1,
        progress: meals >= 1 ? 1.0 : 0.0,
        description: 'Log your first meal',
      );

      // Meal Tracker - Log 20 meals
      achievements['meal_tracker'] = AchievementStatus(
        unlocked: meals >= 20,
        progress: (meals / 20).clamp(0.0, 1.0),
        description: 'Log 20 meals ($meals/20)',
      );

      // Nutrition Pro - Log 100 meals
      achievements['nutrition_pro'] = AchievementStatus(
        unlocked: meals >= 100,
        progress: (meals / 100).clamp(0.0, 1.0),
        description: 'Log 100 meals ($meals/100)',
      );

      // First Workout - Log your first workout
      achievements['first_workout'] = AchievementStatus(
        unlocked: workouts >= 1,
        progress: workouts >= 1 ? 1.0 : 0.0,
        description: 'Log your first workout',
      );

      // Fitness Starter - Log 10 workouts
      achievements['fitness_starter'] = AchievementStatus(
        unlocked: workouts >= 10,
        progress: (workouts / 10).clamp(0.0, 1.0),
        description: 'Log 10 workouts ($workouts/10)',
      );

      // Gym Regular - Log 50 workouts
      achievements['gym_regular'] = AchievementStatus(
        unlocked: workouts >= 50,
        progress: (workouts / 50).clamp(0.0, 1.0),
        description: 'Log 50 workouts ($workouts/50)',
      );

      // CONSISTENCY ACHIEVEMENTS

      // Week Warrior - Be active for 7 days
      achievements['week_warrior'] = AchievementStatus(
        unlocked: activeDays >= 7,
        progress: (activeDays / 7).clamp(0.0, 1.0),
        description: 'Be active for 7 different days ($activeDays/7)',
      );

      // Dedicated - Be active for 21 days
      achievements['dedicated'] = AchievementStatus(
        unlocked: activeDays >= 21,
        progress: (activeDays / 21).clamp(0.0, 1.0),
        description: 'Be active for 21 different days ($activeDays/21)',
      );

      // Committed - Be active for 50 days
      achievements['committed'] = AchievementStatus(
        unlocked: activeDays >= 50,
        progress: (activeDays / 50).clamp(0.0, 1.0),
        description: 'Be active for 50 different days ($activeDays/50)',
      );

      debugPrint('Checked ${achievements.length} achievements');
      return achievements;
    } catch (e) {
      debugPrint('Error checking achievements: $e');
      return _getLockedAchievements();
    }
  }

  /// Check a specific achievement by ID
  static Future<AchievementStatus?> checkAchievement(String achievementId) async {
    final allAchievements = await checkAllAchievements();
    return allAchievements[achievementId];
  }

  /// Get list of recently unlocked achievements (unlocked within last 24 hours)
  ///
  /// This can be used to show congratulations notifications
  static Future<List<String>> getRecentlyUnlocked() async {
    final achievements = await checkAllAchievements();

    // Filter achievements that were just unlocked
    // In a real implementation, you'd store unlock timestamps in Firebase
    return achievements.entries
        .where((entry) => entry.value.unlocked)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get progress percentage for all achievements combined
  static Future<double> getOverallProgress() async {
    final achievements = await checkAllAchievements();

    if (achievements.isEmpty) return 0.0;

    final totalProgress = achievements.values
        .map((status) => status.progress)
        .reduce((a, b) => a + b);

    return totalProgress / achievements.length;
  }

  /// Get count of unlocked achievements
  static Future<int> getUnlockedCount() async {
    final achievements = await checkAllAchievements();
    return achievements.values.where((status) => status.unlocked).length;
  }

  /// Get total achievement count
  static Future<int> getTotalCount() async {
    final achievements = await checkAllAchievements();
    return achievements.length;
  }

  /// Helper to return all locked achievements
  static Map<String, AchievementStatus> _getLockedAchievements() {
    return {
      // Challenge Creation
      'challenger': AchievementStatus(unlocked: false, progress: 0.0, description: 'Create your first challenge'),
      'goal_setter': AchievementStatus(unlocked: false, progress: 0.0, description: 'Create 3 challenges'),
      'ambitious': AchievementStatus(unlocked: false, progress: 0.0, description: 'Create 5 challenges'),

      // Meal Logging
      'first_meal': AchievementStatus(unlocked: false, progress: 0.0, description: 'Log your first meal'),
      'meal_tracker': AchievementStatus(unlocked: false, progress: 0.0, description: 'Log 20 meals'),
      'nutrition_pro': AchievementStatus(unlocked: false, progress: 0.0, description: 'Log 100 meals'),

      // Workout Logging
      'first_workout': AchievementStatus(unlocked: false, progress: 0.0, description: 'Log your first workout'),
      'fitness_starter': AchievementStatus(unlocked: false, progress: 0.0, description: 'Log 10 workouts'),
      'gym_regular': AchievementStatus(unlocked: false, progress: 0.0, description: 'Log 50 workouts'),

      // Consistency
      'week_warrior': AchievementStatus(unlocked: false, progress: 0.0, description: 'Be active for 7 different days'),
      'dedicated': AchievementStatus(unlocked: false, progress: 0.0, description: 'Be active for 21 different days'),
      'committed': AchievementStatus(unlocked: false, progress: 0.0, description: 'Be active for 50 different days'),
    };
  }
}

/// Achievement status model
class AchievementStatus {
  final bool unlocked;
  final double progress; // 0.0 to 1.0
  final String description;

  AchievementStatus({
    required this.unlocked,
    required this.progress,
    required this.description,
  });

  @override
  String toString() {
    return 'AchievementStatus(unlocked: $unlocked, progress: ${(progress * 100).toStringAsFixed(1)}%)';
  }
}
