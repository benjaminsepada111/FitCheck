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
  };

  // Default calorie adjustments for goals (legacy - now replaced by BMI-based adjustments)
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

  // BMI category thresholds
  static const double bmiUnderweightThreshold = 18.5;
  static const double bmiNormalThreshold = 24.9;

  // BMI-based calorie adjustments by category and goal type
  // Format: {category: {goal_type: adjustment}}
  static const Map<String, Map<String, int>> bmiBasedAdjustments = {
    'lean_underweight': {
      'deficit': -250, // Deficit for lean/underweight users
      'surplus': 300,  // Surplus for lean/underweight users
    },
    'normal': {
      'deficit': -500, // Deficit for normal weight users
      'surplus': 400,  // Surplus for normal weight users
    },
    'overweight_obese': {
      'deficit': -500, // Deficit for overweight/obese users
      'surplus': 300,  // Surplus for overweight/obese users
    },
  };

  /// Calculate BMI internally (never displayed to users)
  /// BMI = weight(kg) / (height(m))^2
  static double _calculateBMI(UserData userData) {
    if (userData.weight == null || userData.height == null ||
        userData.weight! <= 0 || userData.height! <= 0) {
      throw ArgumentError('Invalid user data for BMI calculation');
    }

    final weightKg = userData.weight!.toDouble();
    final heightM = userData.height!.toDouble() / 100.0; // Convert cm to m
    return weightKg / (heightM * heightM);
  }

  /// Determine BMI category internally (never displayed to users)
  /// Returns: 'lean_underweight', 'normal', or 'overweight_obese'
  static String _getBMICategory(UserData userData) {
    try {
      final bmi = _calculateBMI(userData);
      
      if (bmi < bmiUnderweightThreshold) {
        return 'lean_underweight';
      } else if (bmi <= bmiNormalThreshold) {
        return 'normal';
      } else {
        return 'overweight_obese';
      }
    } catch (e) {
      // Fallback to normal category if calculation fails
      return 'normal';
    }
  }

  /// Get BMI-based calorie adjustment for a given goal
  /// Returns the appropriate adjustment based on user's hidden BMI category
  static int _getBMIBasedAdjustment(UserData userData, String goal) {
    final goalLower = goal.toLowerCase();
    
    // For maintain goals, always return 0 (keep calories as is)
    if (goalLower.contains('maintain')) {
      return 0;
    }

    // Determine if goal is deficit or surplus
    final bool isDeficitGoal = goalLower.contains('lose') || 
                               goalLower.contains('fat') || 
                               goalLower.contains('deficit');
    final bool isSurplusGoal = goalLower.contains('gain') || 
                               goalLower.contains('muscle') || 
                               goalLower.contains('surplus');

    // Get BMI category
    final bmiCategory = _getBMICategory(userData);
    
    // Get appropriate adjustment based on category and goal type
    final categoryAdjustments = bmiBasedAdjustments[bmiCategory];
    if (categoryAdjustments == null) {
      // Fallback to normal category adjustments
      return isDeficitGoal 
          ? bmiBasedAdjustments['normal']!['deficit']!
          : (isSurplusGoal 
              ? bmiBasedAdjustments['normal']!['surplus']!
              : 0);
    }

    if (isDeficitGoal) {
      return categoryAdjustments['deficit'] ?? -500;
    } else if (isSurplusGoal) {
      return categoryAdjustments['surplus'] ?? 400;
    }

    // Default: no adjustment
    return 0;
  }

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
  /// Uses BMI-based personalized adjustments internally (BMI never displayed)
  static int calculateDailyCalorieGoal(UserData userData) {
    if (!isValidUserData(userData)) {
      return 2000; // Default fallback
    }

    final tdee = calculateTDEE(userData);
    final goal = userData.goal!;

    // Use custom adjustment if explicitly provided, otherwise use BMI-based adjustment
    int adjustment;
    if (userData.goalAdjustment != null) {
      // User has explicitly set a custom adjustment
      adjustment = userData.goalAdjustment!.toInt();
    } else {
      // Use BMI-based personalized adjustment (calculated internally, never shown)
      adjustment = _getBMIBasedAdjustment(userData, goal);
    }

    // Safety check: If TDEE is very low, scale deficit proportionally to avoid unsafe restriction
    // Threshold: TDEE < 1400 for females, TDEE < 1700 for males
    final genderLower = userData.gender!.toLowerCase();
    final double lowTDEEThreshold = genderLower == 'female' ? 1400.0 : 1700.0;
    
    if (tdee < lowTDEEThreshold && adjustment < 0) {
      // Scale deficit proportionally: max deficit = 20% of TDEE
      final maxSafeDeficit = (tdee * 0.20).abs();
      if (adjustment.abs() > maxSafeDeficit) {
        adjustment = (-maxSafeDeficit).round();
      }
    }

    final dailyGoal = (tdee + adjustment).round();

    // Enforce minimum daily calorie threshold
    final minimumCalories = genderLower == 'female' ? 1200 : 1500;
    return dailyGoal < minimumCalories ? minimumCalories : dailyGoal;
  }

  /// Get detailed calorie breakdown for display
  /// Note: BMI and weight category are never included in the breakdown
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
    final goal = userData.goal!;
    
    // Use custom adjustment if provided, otherwise use BMI-based adjustment
    final adjustment = userData.goalAdjustment?.toInt() ?? 
                      _getBMIBasedAdjustment(userData, goal);
    final dailyGoal = calculateDailyCalorieGoal(userData);

    return {
      'bmr': bmr,
      'tdee': tdee,
      'goalType': goal,
      'adjustment': adjustment,
      'dailyGoal': dailyGoal,
      'activityLevel': userData.activityLevel,
      'activityMultiplier':
          activityMultipliers[userData.activityLevel!.toLowerCase()] ?? 1.2,
      // Note: BMI and weight category are intentionally NOT included
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

    final goal = userData.goal!;
    // Use custom adjustment if provided, otherwise use BMI-based adjustment
    final adjustment = userData.goalAdjustment?.toInt() ?? 
                      _getBMIBasedAdjustment(userData, goal);

    return (adjustment * 7) / 3500.0; // pounds per week
  }

  /// Calculate adaptive calorie adjustment based on weight progress
  /// Implements weekly check-in calorie adjustment logic per engineering specifications
  /// Returns a map with: newCalorieGoal, adjustment, interpretation, reason
  static Map<String, dynamic> calculateAdaptiveAdjustment({
    required UserData userData,
    required double currentWeight,
    required double previousWeight,
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
    final weightChangeKg = (currentWeight - previousWeight).toDouble(); // kg
    
    // Weight Validation: Cap unrealistic weight changes (>2% per week is considered extreme)
    final weightChangePercent = (weightChangeKg / previousWeight) * 100;
    final bool isExtremeChange = weightChangePercent.abs() > 2.0; // More than 2% change per week
    
    // Note: Even if weight change is extreme, we'll still calculate adjustments
    // but cap them more conservatively. The user can verify and proceed if the weight is correct.

    // Define weight change states (0.3 kg threshold for "slight" vs "significant")
    final bool isStableWeight = weightChangeKg.abs() <= 0.3;
    final bool isWeightLoss = weightChangeKg < -0.3;
    final bool isWeightGain = weightChangeKg > 0.3;

    String interpretation = 'unchanged';
    String reason = 'No adjustment needed';
    int finalDailyGoal = currentCalorieGoal;

    // STEP 1: Recalculate BMR using updated weight, height, age, and sex (Mifflin-St Jeor)
    // STEP 2: Recalculate TDEE using updated activity multiplier
    // Store weight with decimal precision
    final updatedUserData = userData.copyWith(
      weight: currentWeight,
      activityLevel: effectiveActivityLevel,
      goal: effectiveGoal,
    );
    // BMR is calculated internally by calculateTDEE, no need to store separately
    final newTDEE = calculateTDEE(updatedUserData);

    // STEP 3: Calculate TheoreticalGoal = TDEE + GoalAdjustment
    // Use custom adjustment if explicitly provided, otherwise use BMI-based adjustment
    // Note: effectiveGoal is guaranteed to be non-null here due to early return check above
    int goalAdjustment;
    if (userData.goalAdjustment != null) {
      goalAdjustment = userData.goalAdjustment!.toInt();
    } else {
      // Use BMI-based personalized adjustment (calculated internally, never shown)
      goalAdjustment = _getBMIBasedAdjustment(updatedUserData, effectiveGoal);
    }
    
    // Safety check: If TDEE is very low, scale deficit proportionally
    final genderLower = userData.gender!.toLowerCase();
    final double lowTDEEThreshold = genderLower == 'female' ? 1400.0 : 1700.0;
    
    if (newTDEE < lowTDEEThreshold && goalAdjustment < 0) {
      // Scale deficit proportionally: max deficit = 20% of TDEE
      final maxSafeDeficit = (newTDEE * 0.20).abs();
      if (goalAdjustment.abs() > maxSafeDeficit) {
        goalAdjustment = (-maxSafeDeficit).round();
      }
    }
    
    final theoreticalGoal = (newTDEE + goalAdjustment).round();

    // STEP 4: Apply Safety Minimums (but don't finalize yet - follow goal-specific rules)
    final safetyMinimum = userData.gender!.toLowerCase() == 'female' ? 1200 : 1500;

    // STEP 5: Apply base goal-specific adjustment rules
    // Map goal names to standardized goal types
    final bool isLoseWeightGoal = goalLower.contains('lose') || goalLower.contains('fat') || goalLower.contains('deficit');
    final bool isMaintainWeightGoal = goalLower.contains('maintain');
    final bool isGainWeightGoal = goalLower.contains('gain') || goalLower.contains('muscle') || goalLower.contains('surplus');

    int baseAdjustment = 0; // Base adjustment from goal-specific rules

    if (isLoseWeightGoal) {
      // FOR "LOSE WEIGHT" GOAL (CALORIE DEFICIT GOAL)
      if (isWeightLoss) {
        // 1.1: WeightLoss occurred - User is progressing correctly
        // Keep calories the same. Do not lower further.
        baseAdjustment = 0;
        interpretation = 'optimal_loss';
        reason = 'Weight loss progressing correctly (${weightChangeKg.abs().toStringAsFixed(1)}kg). Keeping calories the same.';
      } else if (isStableWeight) {
        // 1.2: StableWeight - Progress is slow; apply small adjustment
        // Decrease calories by 50-100 kcal (using 100)
        baseAdjustment = -100;
        interpretation = 'slow_loss';
        reason = 'Weight stable (${weightChangeKg.abs().toStringAsFixed(1)}kg change). Reducing calories by 100 to increase progress.';
      } else if (isWeightGain) {
        // 1.3: WeightGain occurred - User is moving opposite of goal
        // Decrease calories by 100 kcal
        baseAdjustment = -100;
        interpretation = 'no_progress';
        reason = 'Weight increased by ${weightChangeKg.toStringAsFixed(1)}kg. Adjusting calorie goal to help you get back on track.';
      }
    } else if (isMaintainWeightGoal) {
      // FOR "MAINTAIN WEIGHT" GOAL
      if (isStableWeight) {
        // 2.1: StableWeight - User successfully maintained
        // Keep calories the same
        baseAdjustment = 0;
        interpretation = 'maintained';
        reason = 'Weight stable (${weightChangeKg.abs().toStringAsFixed(1)}kg change). Maintaining current calorie goal.';
      } else if (isWeightGain) {
        // 2.2: WeightGain occurred - Gaining weight means previous calories were too high
        // Do NOT increase calories even if TDEE increased.
        // Keep calories the same or reduce slightly (-50 to -100 kcal)
        baseAdjustment = -100; // Use -100 kcal (within -50 to -100 range)
        interpretation = 'surplus';
        reason = 'Weight increased by ${weightChangeKg.toStringAsFixed(1)}kg. Adjusting calorie goal to maintain your target weight.';
      } else if (isWeightLoss) {
        // 2.3: WeightLoss occurred - Losing weight unintentionally means calories were too low
        // Increase calories slightly (+50 to +100 kcal)
        // Use TheoreticalGoal but capped at +100 above CurrentDailyGoal
        final maxIncrease = currentCalorieGoal + 100;
        final targetGoal = (theoreticalGoal > currentCalorieGoal && theoreticalGoal <= maxIncrease) 
            ? theoreticalGoal 
            : maxIncrease;
        baseAdjustment = targetGoal - currentCalorieGoal;
        interpretation = 'deficit';
        reason = 'Weight decreased by ${weightChangeKg.abs().toStringAsFixed(1)}kg. Increasing calories to correct (capped at +100 above current).';
      }
    } else if (isGainWeightGoal) {
      // FOR "GAIN WEIGHT" GOAL (CALORIE SURPLUS GOAL)
      if (isWeightGain) {
        // 3.1: WeightGain occurred - User is progressing correctly
        // Keep calories the same. Do not increase further.
        baseAdjustment = 0;
        interpretation = 'optimal_gain';
        reason = 'Weight gain progressing correctly (${weightChangeKg.toStringAsFixed(1)}kg). Keeping calories the same.';
      } else if (isStableWeight) {
        // 3.2: StableWeight - User is not gaining at expected rate
        // Increase calories by +100 kcal
        baseAdjustment = 100;
        interpretation = 'slow_gain';
        reason = 'Weight stable (${weightChangeKg.abs().toStringAsFixed(1)}kg change). Increasing calories by 100 to boost progress.';
      } else if (isWeightLoss) {
        // 3.3: WeightLoss occurred - User moved opposite of goal
        // Increase calories by +100 kcal (capped)
        baseAdjustment = 100;
        interpretation = 'no_progress';
        reason = 'Weight decreased by ${weightChangeKg.abs().toStringAsFixed(1)}kg. Increasing calories by 100 to correct course.';
      }
    } else {
      // Unknown goal type - fallback to theoretical goal with safety minimums
      baseAdjustment = theoreticalGoal - currentCalorieGoal;
      interpretation = 'recalculated';
      reason = 'Calorie goal recalculated based on new weight and activity level.';
    }

    // STEP 6: Detect moderate weight changes (1-2% of previous weight per week)
    // Note: Extreme changes (>2%) are already handled above and return early
    final bool isModerateGain = weightChangePercent > 1.0 && weightChangePercent <= 2.0;
    final bool isModerateLoss = weightChangePercent < -1.0 && weightChangePercent >= -2.0;

    int moderateAdjustment = 0; // Additional adjustment for moderate changes
    String moderateReason = '';

    if (isModerateGain) {
      // ModerateGain: reduce daily goal slightly (-50 to -100 kcal) to prevent excessive gain
      moderateAdjustment = -50; // Use -50 kcal for moderate changes
      moderateReason = ' Moderate weight gain detected (${weightChangePercent.toStringAsFixed(1)}% of body weight).';
    } else if (isModerateLoss) {
      // ModerateLoss: increase daily goal slightly (+50 to +100 kcal) to prevent excessive loss
      moderateAdjustment = 50; // Use +50 kcal for moderate changes
      moderateReason = ' Moderate weight loss detected (${weightChangePercent.abs().toStringAsFixed(1)}% of body weight).';
    }

    // STEP 7: Combine base adjustments and moderate-change adjustments
    int totalAdjustment = baseAdjustment + moderateAdjustment;

    // Cap adjustments based on weight change severity
    if (isExtremeChange) {
      // For extreme changes (>2%), cap at ±50 kcal for safety (user can verify and proceed)
      if (totalAdjustment.abs() > 50) {
        totalAdjustment = totalAdjustment > 0 ? 50 : -50;
      }
      // Update reason to mention extreme change with conservative adjustment
      if (weightChangePercent > 0) {
        reason = 'Extreme weight gain detected (${weightChangePercent.toStringAsFixed(1)}% of body weight). Conservative adjustment applied.';
      } else {
        reason = 'Extreme weight loss detected (${weightChangePercent.abs().toStringAsFixed(1)}% of body weight). Conservative adjustment applied.';
      }
    } else {
      // For normal/moderate changes, cap at ±100 kcal per week
      if (totalAdjustment.abs() > 100) {
        totalAdjustment = totalAdjustment > 0 ? 100 : -100;
      }
      // Update reason if moderate change was detected
      if (moderateReason.isNotEmpty) {
        reason += moderateReason;
        if (isModerateGain) {
          reason += ' Reducing calories by additional 50 to prevent excessive gain.';
        } else {
          reason += ' Increasing calories by additional 50 to prevent excessive loss.';
        }
      }
    }

    // Apply total adjustment
    finalDailyGoal = currentCalorieGoal + totalAdjustment;

    // STEP 8: Apply safety minimums as final check
    finalDailyGoal = finalDailyGoal < safetyMinimum ? safetyMinimum : finalDailyGoal;

    return {
      'newCalorieGoal': finalDailyGoal,
      'adjustment': finalDailyGoal - currentCalorieGoal,
      'interpretation': interpretation,
      'reason': reason,
      'weightChange': weightChangeKg,
    };
  }

  /// Simplified calorie adjustment based on goal + trend
  /// Uses ±150 kcal/week fine-tuning as specified in requirements
  /// Returns a map with: newCalorieGoal, adjustment, interpretation, reason, weightTrend
  static Map<String, dynamic> calculateSimplifiedAdjustment({
    required String goal, // 'lose', 'maintain', 'gain'
    required String trend, // 'up', 'down', 'same'
    required int currentCalorieGoal,
    required double currentWeight,
    required double previousWeight,
    UserData? userData, // Optional, for safety minimums
  }) {
    // Normalize goal to lowercase
    final goalLower = goal.toLowerCase();
    final trendLower = trend.toLowerCase();
    
    // Determine goal type
    final bool isLoseGoal = goalLower.contains('lose') || goalLower.contains('fat') || goalLower.contains('deficit');
    final bool isMaintainGoal = goalLower.contains('maintain');
    final bool isGainGoal = goalLower.contains('gain') || goalLower.contains('muscle') || goalLower.contains('surplus');
    
    int adjustment = 0;
    String interpretation = 'unchanged';
    String reason = 'No adjustment needed';
    
    // Apply ±150 kcal adjustments based on goal + trend
    if (isLoseGoal) {
      // LOSE WEIGHT GOAL
      if (trendLower == 'down') {
        // Weight going down - good progress, keep same
        adjustment = 0;
        interpretation = 'optimal_loss';
        reason = 'Weight trending down. Keeping calories the same to maintain progress.';
      } else if (trendLower == 'same') {
        // Weight stable - need more deficit
        adjustment = -150;
        interpretation = 'slow_loss';
        reason = 'Weight stable. Reducing calories by 150 to increase progress.';
      } else if (trendLower == 'up') {
        // Weight going up - opposite of goal
        adjustment = -150;
        interpretation = 'no_progress';
        reason = 'Weight trending up. Reducing calories by 150 to get back on track.';
      }
    } else if (isMaintainGoal) {
      // MAINTAIN WEIGHT GOAL
      if (trendLower == 'same') {
        // Weight stable - perfect!
        adjustment = 0;
        interpretation = 'maintained';
        reason = 'Weight stable. Maintaining current calorie goal.';
      } else if (trendLower == 'up') {
        // Weight going up - reduce slightly
        adjustment = -150;
        interpretation = 'surplus';
        reason = 'Weight trending up. Reducing calories by 150 to maintain target weight.';
      } else if (trendLower == 'down') {
        // Weight going down - increase slightly
        adjustment = 150;
        interpretation = 'deficit';
        reason = 'Weight trending down. Increasing calories by 150 to maintain target weight.';
      }
    } else if (isGainGoal) {
      // GAIN WEIGHT GOAL
      if (trendLower == 'up') {
        // Weight going up - good progress, keep same
        adjustment = 0;
        interpretation = 'optimal_gain';
        reason = 'Weight trending up. Keeping calories the same to maintain progress.';
      } else if (trendLower == 'same') {
        // Weight stable - need more surplus
        adjustment = 150;
        interpretation = 'slow_gain';
        reason = 'Weight stable. Increasing calories by 150 to boost progress.';
      } else if (trendLower == 'down') {
        // Weight going down - opposite of goal
        adjustment = 150;
        interpretation = 'no_progress';
        reason = 'Weight trending down. Increasing calories by 150 to get back on track.';
      }
    }
    
    // Calculate new calorie goal
    int newCalorieGoal = currentCalorieGoal + adjustment;
    
    // Apply safety minimums if userData provided
    if (userData != null && userData.gender != null) {
      final safetyMinimum = userData.gender!.toLowerCase() == 'female' ? 1200 : 1500;
      if (newCalorieGoal < safetyMinimum) {
        newCalorieGoal = safetyMinimum;
        adjustment = newCalorieGoal - currentCalorieGoal;
        reason = '$reason (adjusted to meet minimum safety threshold)';
      }
    }
    
    return {
      'newCalorieGoal': newCalorieGoal,
      'adjustment': adjustment,
      'interpretation': interpretation,
      'reason': reason,
      'weightTrend': trendLower,
    };
  }

  /// Determine weight trend from weight comparison
  /// Returns 'up', 'down', or 'same' based on weight change
  /// Uses a 0.2 kg tolerance for minor fluctuations (water-weight noise)
  /// Changes of exactly 0.2 kg or less are treated as SAME
  static String determineWeightTrend({
    required double currentWeight,
    required double previousWeight,
    double tolerance = 0.2, // kg tolerance for "same" (0.2 kg to prevent water-weight noise)
  }) {
    // Calculate absolute difference with floating-point precision
    final weightChange = currentWeight - previousWeight;
    final absoluteDifference = weightChange.abs();
    
    // If |Δ weight| ≤ 0.2 kg → trend = SAME
    // Treat changes of exactly 0.2 kg as SAME to prevent reacting to water-weight noise
    if (absoluteDifference <= tolerance) {
      return 'same';
    } 
    // If |Δ weight| > 0.2 kg → trend = UP or DOWN
    else if (weightChange > tolerance) {
      return 'up';
    } else {
      return 'down';
    }
  }
}
