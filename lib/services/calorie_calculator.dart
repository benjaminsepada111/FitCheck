// services/calorie_calculator.dart
import '../models/user_data.dart';

class CalorieCalculator {
  // Activity level multipliers for TDEE calculation (baseline before workouts)
  static const Map<String, double> activityMultipliers = {
    'lightly_active': 1.375, // Desk job, student, light daily activity
    'lightly active': 1.375, // Alternative format
    'active': 1.55, // On feet regularly (teacher, retail, parent)
    'very_active': 1.725, // Physically demanding work (nurse, construction)
    'very active': 1.725, // Alternative format
    'extra_active': 1.9, // Highly physical (athlete, fitness trainer)
    'extra active': 1.9, // Alternative format
    // Legacy support for backward compatibility
    'sedentary': 1.2,
    'light': 1.375,
    'moderate': 1.55,
    'not_active': 1.375,
  };

  // Default calorie adjustments for goals
  static const Map<String, int> defaultGoalAdjustments = {
    'maintain_weight': 0,
    'maintain weight': 0,
    'maintain': 0, // Legacy
    'lose_fat': -500, // 1 lb per week loss
    'lose fat': -500, // Alternative format
    'fat loss': -500, // Legacy
    'gain_muscle': 500, // Moderate surplus for muscle gain
    'gain muscle': 500, // Alternative format
    'muscle gain': 500, // Legacy
    'deficit': -500, // Legacy
    'surplus': 500, // Legacy
  };

  /// Calculate BMR using Mifflin-St Jeor Equation
  /// Men: BMR = 10 × weight(kg) + 6.25 × height(cm) - 5 × age + 5
  /// Women: BMR = 10 × weight(kg) + 6.25 × height(cm) - 5 × age - 161
  static double calculateBMR(UserData userData) {
    if (!isValidUserData(userData)) {
      throw ArgumentError('Invalid user data for BMR calculation');
    }

    final weight = userData.weight!.toDouble();
    final height = userData.height!.toDouble();
    final age = userData.age!.toDouble();
    final gender = userData.gender!.toLowerCase();

    double bmr = (10 * weight) + (6.25 * height) - (5 * age);

    if (gender == 'male') {
      bmr += 5;
    } else {
      bmr -= 161;
    }

    return bmr;
  }

  /// Calculate TDEE (Total Daily Energy Expenditure)
  /// TDEE = BMR × Activity Level Multiplier
  static double calculateTDEE(UserData userData) {
    final bmr = calculateBMR(userData);
    final activityLevel = userData.activityLevel!.toLowerCase();
    final activityMultiplier = activityMultipliers[activityLevel] ?? 1.2;
    return bmr * activityMultiplier;
  }

  /// Calculate daily calorie goal based on user's goal
  static int calculateDailyCalorieGoal(UserData userData) {
    if (!isValidUserData(userData)) {
      return 2000; // Default fallback
    }

    final tdee = calculateTDEE(userData);
    final goal = userData.goal!.toLowerCase();

    // Use custom adjustment if provided, otherwise use default
    final adjustment =
        userData.goalAdjustment?.toInt() ?? defaultGoalAdjustments[goal] ?? 0;

    final dailyGoal = (tdee + adjustment).round();

    // Ensure minimum safe calorie levels
    if (userData.gender!.toLowerCase() == 'female') {
      return dailyGoal < 1200 ? 1200 : dailyGoal;
    } else {
      return dailyGoal < 1500 ? 1500 : dailyGoal;
    }
  }

  /// Get detailed calorie breakdown for display
  static Map<String, dynamic> getCalorieBreakdown(UserData userData) {
    if (!isValidUserData(userData)) {
      return {
        'bmr': 0,
        'tdee': 0,
        'goalType': 'Unknown',
        'adjustment': 0,
        'dailyGoal': 2000,
      };
    }

    final bmr = calculateBMR(userData).round();
    final tdee = calculateTDEE(userData).round();
    final goal = userData.goal!.toLowerCase();
    final adjustment =
        userData.goalAdjustment?.toInt() ?? defaultGoalAdjustments[goal] ?? 0;
    final dailyGoal = calculateDailyCalorieGoal(userData);

    return {
      'bmr': bmr,
      'tdee': tdee,
      'goalType': userData.goal,
      'adjustment': adjustment,
      'dailyGoal': dailyGoal,
      'activityLevel': userData.activityLevel,
      'activityMultiplier':
          activityMultipliers[userData.activityLevel!.toLowerCase()] ?? 1.2,
    };
  }

  /// Calculate macronutrient distribution
  static Map<String, dynamic> calculateMacros(UserData userData) {
    final dailyCalories = calculateDailyCalorieGoal(userData);

    // Default macro distribution
    double proteinPercentage = 0.25; // 25%
    double fatPercentage = 0.30; // 30%
    double carbPercentage = 0.45; // 45%

    final goal = userData.goal!.toLowerCase();

    if (goal == 'muscle gain') {
      proteinPercentage = 0.30;
      fatPercentage = 0.25;
      carbPercentage = 0.45;
    } else if (goal == 'fat loss') {
      proteinPercentage = 0.35;
      fatPercentage = 0.25;
      carbPercentage = 0.40;
    }

    final proteinCalories = (dailyCalories * proteinPercentage).round();
    final fatCalories = (dailyCalories * fatPercentage).round();
    final carbCalories = (dailyCalories * carbPercentage).round();

    return {
      'protein': {
        'grams': (proteinCalories / 4).round(),
        'calories': proteinCalories,
        'percentage': (proteinPercentage * 100).round(),
      },
      'fat': {
        'grams': (fatCalories / 9).round(),
        'calories': fatCalories,
        'percentage': (fatPercentage * 100).round(),
      },
      'carbs': {
        'grams': (carbCalories / 4).round(),
        'calories': carbCalories,
        'percentage': (carbPercentage * 100).round(),
      },
      'totalCalories': dailyCalories,
    };
  }

  /// Validate if user data is sufficient for calculations
  static bool isValidUserData(UserData userData) {
    return userData.gender != null &&
        userData.age != null &&
        userData.age! > 0 &&
        userData.weight != null &&
        userData.weight! > 0 &&
        userData.height != null &&
        userData.height! > 0 &&
        userData.activityLevel != null &&
        userData.goal != null &&
        activityMultipliers.containsKey(userData.activityLevel!.toLowerCase());
  }

  /// Get recommended calorie range for goal
  static Map<String, int> getCalorieRange(UserData userData) {
    final baseGoal = calculateDailyCalorieGoal(userData);
    final goal = userData.goal!.toLowerCase();

    switch (goal) {
      case 'fat loss':
        return {
          'min': baseGoal - 100,
          'max': baseGoal + 100,
          'recommended': baseGoal,
        };
      case 'muscle gain':
        return {
          'min': baseGoal - 150,
          'max': baseGoal + 150,
          'recommended': baseGoal,
        };
      case 'maintain':
      default:
        return {
          'min': baseGoal - 200,
          'max': baseGoal + 200,
          'recommended': baseGoal,
        };
    }
  }

  /// Calculate weekly weight change prediction
  static double predictWeeklyWeightChange(UserData userData) {
    if (!isValidUserData(userData)) return 0.0;

    final goal = userData.goal!.toLowerCase();
    final adjustment =
        userData.goalAdjustment?.toInt() ?? defaultGoalAdjustments[goal] ?? 0;

    return (adjustment * 7) / 3500.0; // pounds per week
  }

  /// Calculate adaptive calorie adjustment based on weight progress
  /// Returns a map with: newCalorieGoal, adjustment, interpretation, reason
  static Map<String, dynamic> calculateAdaptiveAdjustment({
    required UserData userData,
    required int currentWeight,
    required int previousWeight,
    required int currentCalorieGoal,
    String? activityLevel, // Challenge-specific activity level (optional, uses userData.activityLevel if null)
    String? goal, // Challenge-specific goal (optional, uses userData.goal if null)
  }) {
    // Use challenge-specific values if provided, otherwise fall back to userData
    final effectiveActivityLevel = activityLevel ?? userData.activityLevel;
    final effectiveGoal = goal ?? userData.goal;

    if (effectiveGoal == null || userData.gender == null || effectiveActivityLevel == null) {
      // Return default values if user data is incomplete
      return {
        'newCalorieGoal': currentCalorieGoal,
        'adjustment': 0,
        'interpretation': 'unchanged',
        'reason': 'Insufficient user data for adjustment',
        'weightChange': (currentWeight - previousWeight).toDouble(),
      };
    }

    final goalLower = effectiveGoal.toLowerCase();
    final weightChange = (currentWeight - previousWeight).toDouble(); // kg

    String interpretation;
    String reason;
    int adjustment = 0;

    // Recalculate base calories with new weight and challenge-specific activity level
    final updatedUserData = userData.copyWith(
      weight: currentWeight,
      activityLevel: effectiveActivityLevel,
      goal: effectiveGoal,
    );
    final newBaseTDEE = calculateTDEE(updatedUserData);
    final goalAdjustment = userData.goalAdjustment?.toInt() ?? defaultGoalAdjustments[goalLower] ?? 0;
    int newCalorieGoal = (newBaseTDEE + goalAdjustment).round();

    // Apply safety minimums
    if (userData.gender!.toLowerCase() == 'female') {
      newCalorieGoal = newCalorieGoal < 1200 ? 1200 : newCalorieGoal;
    } else {
      newCalorieGoal = newCalorieGoal < 1500 ? 1500 : newCalorieGoal;
    }

    // Base adjustment on weight change
    final baseAdjustment = newCalorieGoal - currentCalorieGoal;

    // Goal-specific adaptive logic
    if (goalLower.contains('maintain')) {
      // MAINTAIN WEIGHT: Expect weight to stay roughly the same (±0.5kg tolerance)
      if (weightChange.abs() <= 0.5) {
        interpretation = 'maintained';
        reason = 'Weight stable within target range. Maintaining current calorie goal.';
        adjustment = 0;
        newCalorieGoal = currentCalorieGoal; // Keep current goal
      } else if (weightChange > 0.5) {
        interpretation = 'surplus';
        reason = 'Weight increased by ${weightChange.toStringAsFixed(1)}kg. Reducing calories by 100 to correct.';
        adjustment = -100;
        newCalorieGoal = currentCalorieGoal - 100;
      } else {
        interpretation = 'deficit';
        reason = 'Weight decreased by ${weightChange.abs().toStringAsFixed(1)}kg. Increasing calories by 100 to correct.';
        adjustment = 100;
        newCalorieGoal = currentCalorieGoal + 100;
      }
    } else if (goalLower.contains('lose') || goalLower.contains('fat')) {
      // FAT LOSS: Expect 0.5-1kg loss per week
      if (weightChange >= 0) {
        interpretation = 'no_progress';
        reason = 'Weight increased/unchanged. Reducing calories by 150 to increase deficit.';
        adjustment = -150;
        newCalorieGoal = currentCalorieGoal - 150;
      } else if (weightChange < -1.0) {
        interpretation = 'rapid_loss';
        reason = 'Weight loss too fast (${weightChange.abs().toStringAsFixed(1)}kg). Increasing calories by 100 to slow down.';
        adjustment = 100;
        newCalorieGoal = currentCalorieGoal + 100;
      } else if (weightChange >= -0.5) {
        interpretation = 'slow_loss';
        reason = 'Weight loss slow (${weightChange.abs().toStringAsFixed(1)}kg). Reducing calories by 100 to increase progress.';
        adjustment = -100;
        newCalorieGoal = currentCalorieGoal - 100;
      } else {
        interpretation = 'optimal_loss';
        reason = 'Weight loss on track (${weightChange.abs().toStringAsFixed(1)}kg). Applying base recalculation.';
        adjustment = baseAdjustment;
      }
    } else if (goalLower.contains('gain') || goalLower.contains('muscle')) {
      // MUSCLE GAIN: Expect 0.25-0.5kg gain per week
      if (weightChange <= 0) {
        interpretation = 'no_progress';
        reason = 'Weight decreased/unchanged. Increasing calories by 150 to create surplus.';
        adjustment = 150;
        newCalorieGoal = currentCalorieGoal + 150;
      } else if (weightChange > 0.5) {
        interpretation = 'rapid_gain';
        reason = 'Weight gain too fast (${weightChange.toStringAsFixed(1)}kg). Reducing calories by 100 to slow down.';
        adjustment = -100;
        newCalorieGoal = currentCalorieGoal - 100;
      } else if (weightChange < 0.25) {
        interpretation = 'slow_gain';
        reason = 'Weight gain slow (${weightChange.toStringAsFixed(1)}kg). Increasing calories by 100 to boost progress.';
        adjustment = 100;
        newCalorieGoal = currentCalorieGoal + 100;
      } else {
        interpretation = 'optimal_gain';
        reason = 'Weight gain on track (${weightChange.toStringAsFixed(1)}kg). Applying base recalculation.';
        adjustment = baseAdjustment;
      }
    } else {
      // Unknown goal - just recalculate based on new weight
      interpretation = 'recalculated';
      reason = 'Calorie goal recalculated based on new weight.';
      adjustment = baseAdjustment;
    }

    // Apply safety minimums again after adjustment
    if (userData.gender!.toLowerCase() == 'female') {
      newCalorieGoal = newCalorieGoal < 1200 ? 1200 : newCalorieGoal;
    } else {
      newCalorieGoal = newCalorieGoal < 1500 ? 1500 : newCalorieGoal;
    }

    return {
      'newCalorieGoal': newCalorieGoal,
      'adjustment': adjustment,
      'interpretation': interpretation,
      'reason': reason,
      'weightChange': weightChange,
    };
  }
}
