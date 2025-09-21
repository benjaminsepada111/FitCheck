// services/calorie_calculator.dart
import '../models/user_data.dart';

class CalorieCalculator {
  // Activity level multipliers for TDEE calculation
  static const Map<String, double> activityMultipliers = {
    'Sedentary': 1.2,     // Little or no exercise
    'Light': 1.375,       // Light exercise 1-3 days/week
    'Moderate': 1.55,     // Moderate exercise 3-5 days/week
    'Active': 1.725,      // Hard exercise 6-7 days/week
    'Very Active': 1.9,   // Hard daily exercise or physical job
  };

  // Default calorie adjustments for goals
  static const Map<String, int> defaultGoalAdjustments = {
    'Maintain': 0,
    'Fat Loss': -500,     // 1 lb per week loss
    'Muscle Gain': 500,   // Moderate surplus for muscle gain
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
    final isMale = userData.gender!.toLowerCase() == 'male';

    double bmr = (10 * weight) + (6.25 * height) - (5 * age);

    if (isMale) {
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
    final activityMultiplier = activityMultipliers[userData.activityLevel] ?? 1.2;
    return bmr * activityMultiplier;
  }

  /// Calculate daily calorie goal based on user's goal
  static int calculateDailyCalorieGoal(UserData userData) {
    if (!isValidUserData(userData)) {
      return 2000; // Default fallback
    }

    final tdee = calculateTDEE(userData);

    // Use custom adjustment if provided, otherwise use default
    final adjustment = userData.goalAdjustment?.toInt() ??
        defaultGoalAdjustments[userData.goal] ?? 0;

    final dailyGoal = (tdee + adjustment).round();

    // Ensure minimum safe calorie levels
    if (userData.gender!.toLowerCase() == 'female') {
      return dailyGoal < 1200 ? 1200 : dailyGoal;
    } else {
      return dailyGoal < 1500 ? 1500 : dailyGoal;
    }
  }

  /// Calculate daily water goal based on weight and activity
  /// General recommendation: 35ml per kg of body weight
  /// Additional 500-750ml for active individuals
  static int calculateDailyWaterGoal(UserData userData) {
    if (userData.weight == null) {
      return 8; // Default 8 glasses
    }

    final baseWater = userData.weight! * 35; // ml per day

    // Add extra for active individuals
    final isActive = userData.activityLevel == 'Active' ||
        userData.activityLevel == 'Very Active';
    final extraWater = isActive ? 625 : 0; // ml

    final totalWaterMl = baseWater + extraWater;

    // Convert to 8oz glasses (approximately 237ml per glass)
    final glasses = (totalWaterMl / 237).round();

    // Reasonable bounds: 6-12 glasses per day
    return glasses.clamp(6, 12);
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
    final adjustment = userData.goalAdjustment?.toInt() ??
        defaultGoalAdjustments[userData.goal] ?? 0;
    final dailyGoal = calculateDailyCalorieGoal(userData);

    return {
      'bmr': bmr,
      'tdee': tdee,
      'goalType': userData.goal,
      'adjustment': adjustment,
      'dailyGoal': dailyGoal,
      'activityLevel': userData.activityLevel,
      'activityMultiplier': activityMultipliers[userData.activityLevel] ?? 1.2,
    };
  }

  /// Calculate macronutrient distribution
  static Map<String, dynamic> calculateMacros(UserData userData) {
    final dailyCalories = calculateDailyCalorieGoal(userData);

    // Default macro distribution (can be customized based on goals)
    double proteinPercentage = 0.25; // 25%
    double fatPercentage = 0.30;     // 30%
    double carbPercentage = 0.45;    // 45%

    // Adjust for muscle gain goals
    if (userData.goal == 'Muscle Gain') {
      proteinPercentage = 0.30; // Higher protein for muscle building
      fatPercentage = 0.25;
      carbPercentage = 0.45;
    }

    // Adjust for fat loss goals
    if (userData.goal == 'Fat Loss') {
      proteinPercentage = 0.35; // Higher protein to preserve muscle
      fatPercentage = 0.25;
      carbPercentage = 0.40;
    }

    final proteinCalories = (dailyCalories * proteinPercentage).round();
    final fatCalories = (dailyCalories * fatPercentage).round();
    final carbCalories = (dailyCalories * carbPercentage).round();

    // Convert calories to grams (protein: 4 cal/g, fat: 9 cal/g, carbs: 4 cal/g)
    final proteinGrams = (proteinCalories / 4).round();
    final fatGrams = (fatCalories / 9).round();
    final carbGrams = (carbCalories / 4).round();

    return {
      'protein': {
        'grams': proteinGrams,
        'calories': proteinCalories,
        'percentage': (proteinPercentage * 100).round(),
      },
      'fat': {
        'grams': fatGrams,
        'calories': fatCalories,
        'percentage': (fatPercentage * 100).round(),
      },
      'carbs': {
        'grams': carbGrams,
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
        activityMultipliers.containsKey(userData.activityLevel);
  }

  /// Get recommended calorie range for goal
  static Map<String, int> getCalorieRange(UserData userData) {
    final baseGoal = calculateDailyCalorieGoal(userData);

    switch (userData.goal) {
      case 'Fat Loss':
        return {
          'min': baseGoal - 100,
          'max': baseGoal + 100,
          'recommended': baseGoal,
        };
      case 'Muscle Gain':
        return {
          'min': baseGoal - 150,
          'max': baseGoal + 150,
          'recommended': baseGoal,
        };
      case 'Maintain':
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

    final adjustment = userData.goalAdjustment?.toInt() ??
        defaultGoalAdjustments[userData.goal] ?? 0;

    // 1 pound = ~3500 calories
    // Weekly change = (daily deficit/surplus * 7) / 3500
    return (adjustment * 7) / 3500.0;
  }
}