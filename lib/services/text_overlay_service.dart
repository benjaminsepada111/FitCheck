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

    return parts.join('\n');
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

    return parts.join(' | ');
  }

  /// Generate workout summary text
  /// Example: "Ran 5km • 30 min cardio • Leg day"
  static String generateWorkoutSummary(List<Map<String, dynamic>> workouts) {
    if (workouts.isEmpty) return '';

    final parts = workouts.map((workout) {
      final name = workout['name'] ?? 'Workout';
      final duration = workout['duration'];

      if (duration != null) {
        return '$name ($duration min)';
      }
      return name;
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

  /// Generate simple summary text (short version for video)
  /// Example: "Day 5 - Lost 2kg 🎉"
  static String generateShortSummary(Milestone milestone, {
    int? dayNumber,
    String? achievement,
  }) {
    final parts = <String>[];

    if (dayNumber != null) {
      parts.add('Day $dayNumber');
    }

    if (milestone.notes != null && milestone.notes!.isNotEmpty) {
      // Truncate to first 50 characters
      final note = milestone.notes!.length > 50
          ? '${milestone.notes!.substring(0, 47)}...'
          : milestone.notes!;
      parts.add(note);
    }

    if (achievement != null && achievement.isNotEmpty) {
      parts.add(achievement);
    }

    return parts.join(' - ');
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

    return parts.join('\n');
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
    if (text.length > 200) return false; // Too long

    // Check for problematic characters that might break FFmpeg
    final problematicChars = RegExp(r'[^\w\s\n.,!?@#$%^&*()_+\-=\[\]{};:"\\|<>\/~`€£¥₹]');
    return !text.contains(problematicChars);
  }

  /// Clean text for FFmpeg compatibility
  /// Removes or escapes problematic characters
  static String cleanTextForFFmpeg(String text) {
    return text
        .replaceAll(RegExp(r'[^\w\s\n.,!?@#$%^&*()_+\-=\[\]{};:"\\|<>\/~`€£¥₹]'), '')
        .trim();
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
      final foodSummary = data?['foodSummary'] as String?;
      final workoutSummary = data?['workoutSummary'] as String?;
      final calories = data?['calories'] as int?;

      final text = generateMilestoneText(
        milestone,
        foodSummary: foodSummary,
        workoutSummary: workoutSummary,
        calories: calories,
      );

      overlays.add(formatForOverlay(cleanTextForFFmpeg(text)));
    }

    return overlays;
  }
}