// lib/services/text_overlay_service.dart
import 'package:intl/intl.dart';
import '../models/milestone.dart';

/// Service to generate text overlays for milestone videos
/// Converts milestone data, food logs, workouts into formatted text
class TextOverlayService {
  /// Generate text overlay from milestone data
  /// Returns formatted text describing the day's activities
  static String generateMilestoneText(Milestone milestone, {
    String? foodSummary,
    String? workoutSummary,
    int? calories,
  }) {
    final date = DateFormat('MMM dd, yyyy').format(milestone.date);
    final parts = <String>[];

    // Add date
    parts.add(date);

    // Add milestone notes if available
    if (milestone.notes != null && milestone.notes!.isNotEmpty) {
      parts.add(milestone.notes!);
    }

    // Add food summary if available
    if (foodSummary != null && foodSummary.isNotEmpty) {
      parts.add('🍽️ $foodSummary');
    }

    // Add workout summary if available
    if (workoutSummary != null && workoutSummary.isNotEmpty) {
      parts.add('💪 $workoutSummary');
    }

    // Add calorie info if available
    if (calories != null && calories > 0) {
      parts.add('🔥 $calories cal');
    }

    return parts.join(' ');
  }

  /// Generate food summary text for a day
  /// Example: "Breakfast: Eggs | Lunch: Chicken | Dinner: Pasta"
  static String generateFoodSummary(Map<String, List<String>> meals) {
    if (meals.isEmpty) return '';

    final parts = <String>[];

    if (meals['breakfast']?.isNotEmpty ?? false) {
      parts.add('Breakfast: ${meals['breakfast']!.join(", ")}');
    }
    if (meals['lunch']?.isNotEmpty ?? false) {
      parts.add('Lunch: ${meals['lunch']!.join(", ")}');
    }
    if (meals['dinner']?.isNotEmpty ?? false) {
      parts.add('Dinner: ${meals['dinner']!.join(", ")}');
    }
    if (meals['snack']?.isNotEmpty ?? false) {
      parts.add('Snack: ${meals['snack']!.join(", ")}');
    }

    return parts.join(' • ');
  }

  /// Generate workout summary text
  /// Example: "Ran 5km • 30 min cardio • Leg day"
  static String generateWorkoutSummary(List<Map<String, dynamic>> workouts) {
    if (workouts.isEmpty) return '';

    final parts = workouts.map((workout) {
      final name = workout['name'] ?? 'Workout';
      final duration = workout['duration'];
      final sets = workout['sets'];
      final reps = workout['reps'];

      final details = <String>[name];

      if (duration != null) {
        details.add('${duration} min');
      }

      if (sets != null && reps != null) {
        details.add('${sets}×${reps}');
      } else if (sets != null) {
        details.add('${sets} sets');
      }

      return details.join(' ');
    }).toList();

    return parts.join(' • ');
  }

  /// Format text for video overlay with character limits
  /// Ensures text fits on screen by breaking into multiple lines
  static String formatForOverlay(String text, {int maxCharsPerLine = 40}) {
    if (text.length <= maxCharsPerLine) return text;

    final words = text.split(' ');
    final lines = <String>[];
    String currentLine = '';

    for (final word in words) {
      if ((currentLine + ' ' + word).length <= maxCharsPerLine) {
        currentLine = currentLine.isEmpty ? word : '$currentLine $word';
      } else {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
        }
        currentLine = word;
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    return lines.join('\n');
  }

  /// Generate comprehensive summary text for video (story-like version)
  /// Includes full notes, workout details, and achievements
  /// Example: "Day 5: Completed 30 min cardio and strength training. Feeling stronger each day! 💪"
  static String generateShortSummary(Milestone milestone, {
    int? dayNumber,
    String? achievement,
    String? workoutDetails,
    String? foodDetails,
    int? caloriesBurned,
  }) {
    final parts = <String>[];

    // Add day number if provided
    if (dayNumber != null) {
      parts.add('Day $dayNumber');
    }

    // Add full notes (no truncation for story-like display)
    if (milestone.notes != null && milestone.notes!.isNotEmpty) {
      parts.add(milestone.notes!);
    }

    // Add workout details if provided
    if (workoutDetails != null && workoutDetails.isNotEmpty) {
      parts.add('💪 $workoutDetails');
    }

    // Add food details if provided
    if (foodDetails != null && foodDetails.isNotEmpty) {
      parts.add('🍽️ $foodDetails');
    }

    // Add calories burned if provided
    if (caloriesBurned != null && caloriesBurned > 0) {
      parts.add('🔥 Burned $caloriesBurned calories');
    }

    // Add achievement if provided
    if (achievement != null && achievement.isNotEmpty) {
      parts.add('🎉 $achievement');
    }

    // Join with spaces for story-like format (server will handle wrapping)
    return parts.join(' ');
  }

  /// Generate comprehensive story-like text overlay
  /// This is the main method for video text generation with full details
  static String generateComprehensiveOverlay(Milestone milestone, {
    int? dayNumber,
    Map<String, dynamic>? workoutData,
    Map<String, dynamic>? foodData,
    String? achievement,
  }) {
    final parts = <String>[];

    // Add day number with date
    if (dayNumber != null) {
      final dateStr = DateFormat('MMM dd').format(milestone.date);
      parts.add('Day $dayNumber • $dateStr');
    }

    // Add milestone notes (full text)
    if (milestone.notes != null && milestone.notes!.isNotEmpty) {
      parts.add(milestone.notes!);
    }

    // Add workout information
    if (workoutData != null) {
      final workoutParts = <String>[];

      if (workoutData['name'] != null) {
        workoutParts.add(workoutData['name']);
      }

      if (workoutData['duration'] != null) {
        workoutParts.add('${workoutData['duration']} min');
      }

      if (workoutData['sets'] != null) {
        workoutParts.add('${workoutData['sets']} sets');
      }

      if (workoutData['reps'] != null) {
        workoutParts.add('${workoutData['reps']} reps');
      }

      if (workoutParts.isNotEmpty) {
        parts.add('💪 ${workoutParts.join(' • ')}');
      }
    }

    // Add food information
    if (foodData != null) {
      if (foodData['calories'] != null) {
        parts.add('🍽️ ${foodData['calories']} cal consumed');
      }

      if (foodData['protein'] != null) {
        parts.add('Protein: ${foodData['protein']}g');
      }
    }

    // Add achievement
    if (achievement != null && achievement.isNotEmpty) {
      parts.add('🎉 $achievement');
    }

    return parts.join(' ');
  }

  /// Generate motivational text based on progress
  static String generateMotivationalText(int dayNumber, {
    double? weightLoss,
    int? totalCaloriesBurned,
    int? workoutCount,
  }) {
    final parts = <String>['Day $dayNumber 💪'];

    if (weightLoss != null && weightLoss > 0) {
      parts.add('${weightLoss.toStringAsFixed(1)}kg lost! 🎉');
    }

    if (totalCaloriesBurned != null && totalCaloriesBurned > 0) {
      parts.add('${totalCaloriesBurned} calories burned 🔥');
    }

    if (workoutCount != null && workoutCount > 0) {
      parts.add('$workoutCount workouts completed ✅');
    }

    return parts.join(' ');
  }

  /// Create template text for manual editing
  /// Provides a starting point for users to customize
  static String createTemplateText(DateTime date) {
    final formattedDate = DateFormat('EEEE, MMM dd').format(date);
    return '$formattedDate\nAdd your story here...';
  }

  /// Validate text for overlay (check length, special characters)
  static bool isValidOverlayText(String text) {
    if (text.isEmpty) return true; // Empty text is valid (no overlay)
    if (text.length > 500) return false; // Increased limit for story-like content

    // Allow more characters including emojis
    return true; // Let server handle text cleaning
  }

  /// Clean text for FFmpeg compatibility
  /// Removes or escapes problematic characters
  static String cleanTextForFFmpeg(String text) {
    // Keep most characters, only remove truly problematic ones
    // The server will handle proper escaping
    return text.trim();
  }

  /// Generate text overlays for multiple milestones
  /// Returns list of text strings, one for each milestone
  static List<String> generateBatchOverlays(
      List<Milestone> milestones, {
        Map<DateTime, Map<String, dynamic>>? dailyData,
      }) {
    final overlays = <String>[];

    for (int i = 0; i < milestones.length; i++) {
      final milestone = milestones[i];
      final date = milestone.date;

      // Get daily data if available
      final data = dailyData?[date];
      final workoutData = data?['workout'] as Map<String, dynamic>?;
      final foodData = data?['food'] as Map<String, dynamic>?;
      final achievement = data?['achievement'] as String?;

      // Generate comprehensive overlay with all details
      final text = generateComprehensiveOverlay(
        milestone,
        dayNumber: i + 1,
        workoutData: workoutData,
        foodData: foodData,
        achievement: achievement,
      );

      overlays.add(cleanTextForFFmpeg(text));
    }

    return overlays;
  }
}