// services/daily_calorie_service.dart
import 'package:flutter/foundation.dart';
import '../models/user_data.dart';
import 'calorie_calculator.dart';
import 'workout_log_service.dart';
import 'food_log_service.dart';

/// Service for managing dynamic daily calorie targets that adjust based on workouts
///
/// Architecture:
/// - Baseline Goal = BMR × 1.2 (sedentary) ± goal adjustment
/// - Workout Calories = Sum of MET-based calculations for all workouts
/// - Dynamic Daily Target = Baseline Goal + Workout Calories
/// - Net Calories = Calories Consumed - Dynamic Daily Target
class DailyCalorieService {
  /// Calculate the dynamic daily calorie target for a specific date
  /// This includes the baseline goal plus calories burned from workouts
  static Future<int> calculateDynamicDailyTarget({
    required UserData userData,
    required DateTime date,
    required String challengeId,
  }) async {
    // Get baseline calorie goal (sedentary + goal adjustment)
    final baselineGoal = CalorieCalculator.calculateBaselineCalorieGoal(userData);

    // Get calories burned from workouts on this date
    final workoutCalories = await WorkoutLogService.getDailyCaloriesBurned(
      date,
      challengeId: challengeId,
    );

    // Dynamic target = baseline + workout calories burned
    final dynamicTarget = baselineGoal + workoutCalories.round();

    debugPrint('📊 Dynamic Calorie Target for ${_formatDate(date)}:');
    debugPrint('   Baseline Goal: $baselineGoal cal');
    debugPrint('   Workout Calories Burned: ${workoutCalories.round()} cal');
    debugPrint('   Dynamic Daily Target: $dynamicTarget cal');

    return dynamicTarget;
  }

  /// Get comprehensive daily calorie summary
  /// Returns all calorie-related metrics for a specific date
  static Future<DailyCalorieSummary> getDailySummary({
    required UserData userData,
    required DateTime date,
    required String challengeId,
  }) async {
    // Calculate baseline goal
    final baselineGoal = CalorieCalculator.calculateBaselineCalorieGoal(userData);

    // Get calories consumed from food logs
    final caloriesConsumed = await FoodLogService.getDailyCalories(
      date,
      challengeId: challengeId,
    );

    // Get calories burned from workouts
    final caloriesBurned = await WorkoutLogService.getDailyCaloriesBurned(
      date,
      challengeId: challengeId,
    );

    // Calculate dynamic target
    final dynamicTarget = baselineGoal + caloriesBurned.round();

    // Calculate net calories (consumed - dynamic target)
    final netCalories = caloriesConsumed.round() - dynamicTarget;

    // Calculate remaining calories to meet target
    final remainingCalories = dynamicTarget - caloriesConsumed.round();

    debugPrint('📊 Daily Calorie Summary for ${_formatDate(date)}:');
    debugPrint('   Baseline Goal: $baselineGoal cal');
    debugPrint('   Calories Consumed: ${caloriesConsumed.round()} cal');
    debugPrint('   Calories Burned (Workouts): ${caloriesBurned.round()} cal');
    debugPrint('   Dynamic Target: $dynamicTarget cal');
    debugPrint('   Net Calories: $netCalories cal');
    debugPrint('   Remaining: $remainingCalories cal');

    return DailyCalorieSummary(
      date: date,
      baselineGoal: baselineGoal,
      caloriesConsumed: caloriesConsumed.round(),
      caloriesBurned: caloriesBurned.round(),
      dynamicTarget: dynamicTarget,
      netCalories: netCalories,
      remainingCalories: remainingCalories,
    );
  }

  /// Calculate net calorie balance for the day
  /// Positive value = calorie surplus, Negative value = calorie deficit
  static Future<int> getNetCalorieBalance({
    required UserData userData,
    required DateTime date,
    required String challengeId,
  }) async {
    final summary = await getDailySummary(
      userData: userData,
      date: date,
      challengeId: challengeId,
    );
    return summary.netCalories;
  }

  /// Get progress percentage toward dynamic daily target
  /// Returns value between 0.0 and 1.0+
  static Future<double> getCalorieProgress({
    required UserData userData,
    required DateTime date,
    required String challengeId,
  }) async {
    final summary = await getDailySummary(
      userData: userData,
      date: date,
      challengeId: challengeId,
    );

    if (summary.dynamicTarget == 0) return 0.0;

    return summary.caloriesConsumed / summary.dynamicTarget;
  }

  /// Check if user is within healthy calorie range for their goal
  static Future<CalorieStatus> getCalorieStatus({
    required UserData userData,
    required DateTime date,
    required String challengeId,
  }) async {
    final summary = await getDailySummary(
      userData: userData,
      date: date,
      challengeId: challengeId,
    );

    final goal = userData.goal?.toLowerCase() ?? 'maintain';

    // Define acceptable ranges based on goal
    int lowerBound;
    int upperBound;

    switch (goal) {
      case 'fat loss':
        // For fat loss, aim to be at or slightly below target
        lowerBound = summary.dynamicTarget - 200;
        upperBound = summary.dynamicTarget + 50;
        break;
      case 'muscle gain':
        // For muscle gain, aim to be at or slightly above target
        lowerBound = summary.dynamicTarget - 50;
        upperBound = summary.dynamicTarget + 200;
        break;
      case 'maintain':
      default:
        // For maintenance, allow ±200 calories
        lowerBound = summary.dynamicTarget - 200;
        upperBound = summary.dynamicTarget + 200;
        break;
    }

    if (summary.caloriesConsumed < lowerBound) {
      return CalorieStatus.underTarget;
    } else if (summary.caloriesConsumed > upperBound) {
      return CalorieStatus.overTarget;
    } else {
      return CalorieStatus.onTarget;
    }
  }

  /// Format date for logging
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Daily calorie summary data class
class DailyCalorieSummary {
  final DateTime date;
  final int baselineGoal;        // Sedentary baseline + goal adjustment
  final int caloriesConsumed;    // From food logs
  final int caloriesBurned;      // From workout logs
  final int dynamicTarget;       // Baseline + workout calories
  final int netCalories;         // Consumed - dynamic target
  final int remainingCalories;   // Dynamic target - consumed

  DailyCalorieSummary({
    required this.date,
    required this.baselineGoal,
    required this.caloriesConsumed,
    required this.caloriesBurned,
    required this.dynamicTarget,
    required this.netCalories,
    required this.remainingCalories,
  });

  /// True if user has consumed more than their dynamic target
  bool get isOverTarget => caloriesConsumed > dynamicTarget;

  /// True if user has consumed less than their dynamic target
  bool get isUnderTarget => caloriesConsumed < dynamicTarget;

  /// True if user is within 50 calories of their target
  bool get isOnTarget => (caloriesConsumed - dynamicTarget).abs() <= 50;

  /// Progress as a percentage (0.0 to 1.0+)
  double get progress => dynamicTarget == 0 ? 0.0 : caloriesConsumed / dynamicTarget;

  @override
  String toString() {
    return 'DailyCalorieSummary(date: $date, baseline: $baselineGoal, consumed: $caloriesConsumed, burned: $caloriesBurned, target: $dynamicTarget, net: $netCalories)';
  }
}

/// Status enum for calorie tracking
enum CalorieStatus {
  underTarget,
  onTarget,
  overTarget,
}
