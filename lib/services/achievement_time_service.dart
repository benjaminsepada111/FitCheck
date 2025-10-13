// services/achievement_time_service.dart
import 'package:capstone_project/services/user_time_tracker.dart';
import 'package:capstone_project/services/statistics_service.dart';
import 'package:flutter/foundation.dart';

/// Service to check time-based achievements using UserTimeTracker
///
/// This service combines time tracking metrics with user statistics
/// to determine which achievements should be unlocked.
class AchievementTimeService {
  /// Check all time-based achievements at once
  ///
  /// Returns a map with achievement IDs as keys and unlock status as values
  static Future<Map<String, AchievementStatus>> checkAllAchievements() async {
    try {
      // Get time metrics and statistics in parallel
      final results = await Future.wait([
        UserTimeTracker.getAllTimeMetrics(),
        StatisticsService.getAllStatistics(),
        StatisticsService.getActiveDays(), // Get active days separately for achievements
      ]);

      final timeMetrics = results[0] as Map<String, dynamic>;
      final stats = results[1] as Map<String, int>;
      final activeDays = results[2] as int;

      final achievements = <String, AchievementStatus>{};

      // Check if time tracking is initialized
      if (!(timeMetrics['isInitialized'] as bool)) {
        debugPrint('Time tracking not initialized. All achievements locked.');
        return _getLockedAchievements();
      }

      final days = timeMetrics['daysPassed'] as int;
      final workouts = stats['workoutsLogged'] ?? 0;
      final meals = stats['mealsLogged'] ?? 0;

      // First Step - Complete your first challenge (day 1)
      achievements['first_step'] = AchievementStatus(
        unlocked: days >= 1,
        progress: days >= 1 ? 1.0 : 0.0,
        description: 'Complete your first day',
      );

      // Week Warrior - Complete 7 days of tracking
      achievements['week_warrior'] = AchievementStatus(
        unlocked: activeDays >= 7,
        progress: (activeDays / 7).clamp(0.0, 1.0),
        description: 'Log activity for 7 different days ($activeDays/7)',
      );

      // Two Week Champion - Complete 14 days
      achievements['two_week_champion'] = AchievementStatus(
        unlocked: days >= 14,
        progress: (days / 14).clamp(0.0, 1.0),
        description: 'Reach day 14 of your journey ($days/14)',
      );

      // Fitness Enthusiast - Log 10 workouts
      achievements['fitness_enthusiast'] = AchievementStatus(
        unlocked: workouts >= 10,
        progress: (workouts / 10).clamp(0.0, 1.0),
        description: 'Log 10 workouts ($workouts/10)',
      );

      // Meal Master - Log 50 meals
      achievements['meal_master'] = AchievementStatus(
        unlocked: meals >= 50,
        progress: (meals / 50).clamp(0.0, 1.0),
        description: 'Log 50 meals ($meals/50)',
      );

      // Consistency King - Maintain a 30-day login streak
      achievements['consistency_king'] = AchievementStatus(
        unlocked: activeDays >= 30,
        progress: (activeDays / 30).clamp(0.0, 1.0),
        description: 'Log activity for 30 different days ($activeDays/30)',
      );

      // Monthly Milestone - Complete 1 month
      achievements['monthly_milestone'] = AchievementStatus(
        unlocked: days >= 30,
        progress: (days / 30).clamp(0.0, 1.0),
        description: 'Reach 30 days on your journey ($days/30)',
      );

      // Quarter Master - Complete 3 months (90 days)
      achievements['quarter_master'] = AchievementStatus(
        unlocked: days >= 90,
        progress: (days / 90).clamp(0.0, 1.0),
        description: 'Reach 90 days on your journey ($days/90)',
      );

      // Century Club - Complete 100 days
      achievements['century_club'] = AchievementStatus(
        unlocked: days >= 100,
        progress: (days / 100).clamp(0.0, 1.0),
        description: 'Reach day 100 of your journey ($days/100)',
      );

      // Half Year Hero - Complete 6 months (180 days)
      achievements['half_year_hero'] = AchievementStatus(
        unlocked: days >= 180,
        progress: (days / 180).clamp(0.0, 1.0),
        description: 'Reach 180 days on your journey ($days/180)',
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
      'first_step': AchievementStatus(unlocked: false, progress: 0.0, description: 'Complete your first day'),
      'week_warrior': AchievementStatus(unlocked: false, progress: 0.0, description: 'Log activity for 7 different days'),
      'two_week_champion': AchievementStatus(unlocked: false, progress: 0.0, description: 'Reach day 14 of your journey'),
      'fitness_enthusiast': AchievementStatus(unlocked: false, progress: 0.0, description: 'Log 10 workouts'),
      'meal_master': AchievementStatus(unlocked: false, progress: 0.0, description: 'Log 50 meals'),
      'consistency_king': AchievementStatus(unlocked: false, progress: 0.0, description: 'Log activity for 30 different days'),
      'monthly_milestone': AchievementStatus(unlocked: false, progress: 0.0, description: 'Reach 30 days on your journey'),
      'quarter_master': AchievementStatus(unlocked: false, progress: 0.0, description: 'Reach 90 days on your journey'),
      'century_club': AchievementStatus(unlocked: false, progress: 0.0, description: 'Reach day 100 of your journey'),
      'half_year_hero': AchievementStatus(unlocked: false, progress: 0.0, description: 'Reach 180 days on your journey'),
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
