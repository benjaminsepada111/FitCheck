import 'package:flutter/foundation.dart';
import 'notification_storage_service.dart';
/// Helper class for creating notifications throughout the app
/// Provides convenient methods for common notification types
class NotificationHelper {
  /// Create a meal logged notification
  static Future<void> createMealLoggedNotification(
      String mealType, {
        int? calories,
      }) async {
    try {
      final description = calories != null
          ? 'You logged $mealType with $calories calories. Keep up the great work!'
          : 'You have logged your $mealType. Keep up the great work!';

      await NotificationStorageService.saveNotification(
        type: NotificationStorageService.typeMealLogged,
        title: 'Meal Logged Successfully',
        description: description,
        iconName: 'restaurant',
        iconColor: 0xFFFF9800, // Orange
        metadata: {
          'mealType': mealType,
          if (calories != null) 'calories': calories,
        },
      );
      debugPrint('✅ Meal logged notification created: $mealType');
    } catch (e) {
      debugPrint('❌ Error creating meal logged notification: $e');
    }
  }

  /// Create a milestone photo notification
  static Future<void> createMilestonePhotoNotification() async {
    try {
      await NotificationStorageService.saveNotification(
        type: NotificationStorageService.typeMilestonePhoto,
        title: 'Milestone Photo Added',
        description: 'Great progress! Your milestone photo has been saved.',
        iconName: 'camera_alt',
        iconColor: 0xFFE91E63, // Pink
      );
      debugPrint('✅ Milestone photo notification created');
    } catch (e) {
      debugPrint('❌ Error creating milestone photo notification: $e');
    }
  }

  /// Create a daily goal achieved notification
  static Future<void> createDailyGoalNotification({
    required String goalType,
    String? message,
  }) async {
    try {
      final description = message ??
          'Congratulations! You\'ve reached your daily $goalType goal.';

      await NotificationStorageService.saveNotification(
        type: NotificationStorageService.typeDailyGoal,
        title: 'Daily Goal Achieved 🎯',
        description: description,
        iconName: 'fitness_center',
        iconColor: 0xFF2196F3, // Blue
        metadata: {'goalType': goalType},
      );
      debugPrint('✅ Daily goal notification created: $goalType');
    } catch (e) {
      debugPrint('❌ Error creating daily goal notification: $e');
    }
  }

  /// Create a streak notification
  static Future<void> createStreakNotification({
    required int streakDays,
    required String streakType,
  }) async {
    try {
      final description =
          'You\'re on a $streakDays-day $streakType streak! Don\'t break it.';

      await NotificationStorageService.saveNotification(
        type: NotificationStorageService.typeStreak,
        title: 'Streak Reminder 🔥',
        description: description,
        iconName: 'local_fire_department',
        iconColor: 0xFFFF5722, // Red/Orange
        metadata: {
          'streakDays': streakDays,
          'streakType': streakType,
        },
      );
      debugPrint('✅ Streak notification created: $streakDays days');
    } catch (e) {
      debugPrint('❌ Error creating streak notification: $e');
    }
  }

  /// Create a workout logged notification
  static Future<void> createWorkoutLoggedNotification({
    String? workoutName,
    int? duration,
    int? caloriesBurned,
  }) async {
    try {
      String description = 'Great job! You completed a workout session.';

      if (workoutName != null && duration != null) {
        description = 'You completed $workoutName for $duration minutes. Great work!';
      } else if (workoutName != null) {
        description = 'You completed $workoutName. Great work!';
      }

      await NotificationStorageService.saveNotification(
        type: NotificationStorageService.typeWorkoutLogged,
        title: 'Workout Completed 💪',
        description: description,
        iconName: 'fitness_center',
        iconColor: 0xFF4CAF50, // Green
        metadata: {
          if (workoutName != null) 'workoutName': workoutName,
          if (duration != null) 'duration': duration,
          if (caloriesBurned != null) 'caloriesBurned': caloriesBurned,
        },
      );
      debugPrint('✅ Workout logged notification created');
    } catch (e) {
      debugPrint('❌ Error creating workout logged notification: $e');
    }
  }

  /// Create an achievement unlocked notification
  static Future<void> createAchievementUnlockedNotification({
    required String achievementTitle,
    required String achievementDescription,
  }) async {
    try {
      await NotificationStorageService.saveNotification(
        type: NotificationStorageService.typeAchievementUnlocked,
        title: '🏆 Achievement Unlocked!',
        description:
        'You\'ve unlocked "$achievementTitle" - $achievementDescription',
        iconName: 'emoji_events',
        iconColor: 0xFFFFD700, // Gold
        metadata: {
          'achievementTitle': achievementTitle,
          'achievementDescription': achievementDescription,
        },
      );
      debugPrint('✅ Achievement notification created: $achievementTitle');
    } catch (e) {
      debugPrint('❌ Error creating achievement notification: $e');
    }
  }

  /// Create a challenge completed notification
  static Future<void> createChallengeCompletedNotification({
    required String challengeName,
  }) async {
    try {
      await NotificationStorageService.saveNotification(
        type: NotificationStorageService.typeChallengeCompleted,
        title: 'Challenge Completed! 🎉',
        description: 'Congratulations! You\'ve completed "$challengeName".',
        iconName: 'flag',
        iconColor: 0xFF9C27B0, // Purple
        metadata: {'challengeName': challengeName},
      );
      debugPrint('✅ Challenge completed notification created: $challengeName');
    } catch (e) {
      debugPrint('❌ Error creating challenge notification: $e');
    }
  }

  /// Create a general notification
  static Future<void> createGeneralNotification({
    required String title,
    required String description,
    String? iconName,
    int? iconColor,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await NotificationStorageService.saveNotification(
        type: NotificationStorageService.typeGeneral,
        title: title,
        description: description,
        iconName: iconName,
        iconColor: iconColor,
        metadata: metadata,
      );
      debugPrint('✅ General notification created: $title');
    } catch (e) {
      debugPrint('❌ Error creating general notification: $e');
    }
  }

  /// Create a water intake reminder notification
  static Future<void> createWaterReminderNotification({
    int? cupsRemaining,
  }) async {
    try {
      final description = cupsRemaining != null
          ? 'You have $cupsRemaining more cups to reach your daily water goal. Stay hydrated!'
          : 'Don\'t forget to drink water and stay hydrated!';

      await NotificationStorageService.saveNotification(
        type: NotificationStorageService.typeGeneral,
        title: 'Stay Hydrated 💧',
        description: description,
        iconName: 'water_drop',
        iconColor: 0xFF2196F3, // Blue
        metadata: {
          if (cupsRemaining != null) 'cupsRemaining': cupsRemaining,
        },
      );
      debugPrint('✅ Water reminder notification created');
    } catch (e) {
      debugPrint('❌ Error creating water reminder notification: $e');
    }
  }

  /// Create a weight update notification
  static Future<void> createWeightUpdateNotification({
    required double newWeight,
    required String unit,
    double? change,
  }) async {
    try {
      String description = 'You updated your weight to $newWeight $unit.';

      if (change != null) {
        if (change > 0) {
          description += ' You gained ${change.abs()} $unit.';
        } else if (change < 0) {
          description += ' You lost ${change.abs()} $unit. Keep it up!';
        }
      }

      await NotificationStorageService.saveNotification(
        type: NotificationStorageService.typeGeneral,
        title: 'Weight Updated ⚖️',
        description: description,
        iconName: 'monitor_weight',
        iconColor: 0xFF9C27B0, // Purple
        metadata: {
          'newWeight': newWeight,
          'unit': unit,
          if (change != null) 'change': change,
        },
      );
      debugPrint('✅ Weight update notification created');
    } catch (e) {
      debugPrint('❌ Error creating weight update notification: $e');
    }
  }

  /// Create a welcome notification for new users
  static Future<void> createWelcomeNotification({
    required String userName,
  }) async {
    try {
      await NotificationStorageService.saveNotification(
        type: NotificationStorageService.typeGeneral,
        title: 'Welcome to FitCheck! 👋',
        description:
        'Hi $userName! We\'re excited to have you. Start tracking your fitness journey today!',
        iconName: 'celebration',
        iconColor: 0xFF4CAF50, // Green
        metadata: {'userName': userName},
      );
      debugPrint('✅ Welcome notification created for: $userName');
    } catch (e) {
      debugPrint('❌ Error creating welcome notification: $e');
    }
  }
}